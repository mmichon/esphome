# Espresso Machine Low-Water Sensor

Battery-powered, non-contact water-level sensor on the espresso machine's
reservoir. Detects when the tank is low (sensor mounted on the *outside* of the
plastic tank) and sends a single push notification via Home Assistant.

Configs: [`espresso-water.yaml`](espresso-water.yaml) (production) and
[`espresso-water-test.yaml`](espresso-water-test.yaml) (always-on debug build).

---

## Hardware / BOM

| Part | Notes |
|------|-------|
| **XKC-Y23A-NPN** capacitive non-contact level sensor (~$7) | 3.3–5 V, open-collector NPN, 3 wires. Detects water *through* the plastic tank wall (≤ ~15 mm). Stuck to the outside of the tank at the "refill" line. |
| **DFRobot Beetle ESP32-C3** (ESP32-C3-MINI-1, 4 MB) | Onboard **TP4057** LiPo charger (400 mA) + **BAT/GND** pads, USB-C, no power LED (good for deep sleep). |
| **1000 mAh LiPo** | On the BAT/GND pads; charges over the Beetle's USB-C. |

### Why this sensor / board

- **XKC-Y23A-NPN, not XKC-Y25-V:** the Y25-V needs 5–24 V, which a 3.3–4.2 V LiPo
  can't provide without a boost converter. The Y23A runs at 3.3 V → powered
  directly from a GPIO, no boost, no level shifting (NPN output is read against a
  3.3 V pull-up so it's GPIO-safe regardless of VCC).
- **Beetle ESP32-C3:** has onboard LiPo charging + battery pads, unlike a bare
  module or a DevKit (whose AMS1117 + LEDs would wreck deep-sleep current).

## Wiring (XKC-Y23A-NPN → Beetle ESP32-C3)

Beetle pads are labeled by GPIO number.

```
brown (VCC) -> pad 6 / GPIO6   (3.3 V power + switch — HIGH only while awake)
blue  (GND) -> GND
black (OUT) -> pad 7 / GPIO7   (digital input, internal pull-up)
LiPo cell   -> BAT / GND pads   (onboard TP4057 charges over USB-C)
```

- **GPIO6 both powers and gates the sensor** — driven HIGH on boot, de-energized
  in deep sleep, so the sensor's ~5 mA only flows during the ~8 s wake window.
- Avoid pad **2** (strapping/ADC), **8/9** (strapping), **20/21** (UART0),
  **18/19** (USB).
- **Polarity:** `ON = water low`. The NPN pulls OUT low when water is present
  (→ `off`); the pull-up holds it high when dry (→ `on`). No `invert:` needed.

## Firmware behavior

**Wakes twice a day at 06:45 and 12:30 local (Pacific)** — just before the
morning and afternoon coffee. On each wake it powers the sensor, connects to HA,
reports `binary_sensor`, and the instant HA has the reading
(`api: on_client_connected`) it:

1. waits for `time: homeassistant` to sync,
2. computes the seconds until the next 06:45 / 12:30,
3. `set_sleep_duration` + `deep_sleep.enter`.

`run_duration: 60s` / `sleep_duration: 1h` in the `deep_sleep:` block are **only
fallbacks** used if HA never connects (so it can't get stuck awake draining the
battery).

`espresso-water-test.yaml` is the same hardware config but **always-on** (no deep
sleep) with `web_server` + a WiFi-signal sensor — flash it over USB for easy
debugging or first-time HA adoption, then flash the production build back.

## Battery life

~8 s awake per wake → the wakes are negligible (~0.4 mAh/day). Life is limited by
**board standby current** (~tens of µA, unmeasured) and **LiPo self-discharge**.

**Best estimate on a 1000 mAh cell: ~1 year (roughly 8–14 months).** Recharge via
USB-C about once a year. (To pin it down, measure deep-sleep current with an
inline meter on the battery — that's the wild card.)

## Home Assistant

- **Adopted** via the ESPHome integration — host `espresso.local` / `10.0.0.48`,
  port `6053`, encryption key = `!secret api_encryption_key` (shared by all
  ESPHome devices here).
- **Entity:** `binary_sensor.espresso_water_espresso_water_low`
  (`off` = water present, `on` = low). ⚠️ The id doubles up because the device is
  named "Espresso Water" and the entity "Espresso Water Low" — don't reference
  `binary_sensor.espresso_water_low` (it 404s).
- **Low-water automation:** `automation.espresso_machine_water_low` in
  `automations.yaml` — notify-once via `notify.all_mike_devices`, guarded by
  `input_boolean.espresso_low_notified` (defined in `configuration.yaml`).
  Triggers on `to: 'on'` (notify + set guard) and `to: 'off'` (clear guard) — NOT
  edge `from: 'off'`, so it survives the deep-sleep device going `unavailable`
  between wakes and never double-notifies.
- **Offline / dead-battery automation:** `automation.espresso_sensor_offline_battery_dead`
  — hourly `time_pattern` check; if the sensor's `last_reported` is >30 h old it
  notifies once that the battery is likely dead (recharge over USB-C), then
  re-arms when it checks back in. Guarded by `input_boolean.espresso_offline_notified`.
  Keys off `last_reported` (updates every wake even when the level is unchanged),
  NOT `last_changed`. Note: it can't distinguish a dead battery from a WiFi/HA/
  device outage, and it's a *post-mortem* alert — there is **no early low-battery
  warning** because no battery-voltage ADC is wired (see the commented `adc` stub
  in the YAML; needs a divider on the BAT pad).

## Build & flash

- **Build from local fs**, not the SMB mount: copy the YAML + `secrets.yaml` to
  `~/esphome-build/` and run `esphome` there (avoids slow/locked SMB I/O).
  ```
  cp espresso-water.yaml secrets.yaml ~/esphome-build/
  esphome run ~/esphome-build/espresso-water.yaml --device /dev/cu.usbmodemXXXX --no-logs
  ```
- **USB is the reliable reflash path** — esptool forces download mode, so deep
  sleep doesn't matter. **Hold BOOT while plugging in** since the device is
  asleep almost all the time.
- **OTA only works during a wake window**, which is ~8 s on the production build —
  impractical. Use USB.

## Troubleshooting

- **False "low water" + "online but unreachable" (pings, but API/web dead):**
  the battery is sagging. When the LiPo is low/uncharged the 3V3 rail droops →
  the GPIO6-powered sensor under-volts (it sits right at its 3.3 V floor) and
  reads a false low, *and* WiFi bring-up browns out. **Fix: charge the cell.**
- **Durable fix if it recurs as the battery discharges:** power the sensor from
  the **BAT pad via a high-side P-MOSFET gated by GPIO6** (full voltage + still
  gated), and add a **220–470 µF** cap across 3V3 for WiFi-brownout headroom.
- **Optional battery monitoring:** a divider from BAT to an ADC pin (e.g. GPIO2)
  + an `adc` sensor would give a recharge warning (commented stub in the YAML).
