# Mike's ESPHome configs

ESPHome configurations for ESP32/ESP8266 microcontrollers integrated with [Home Assistant](https://www.home-assistant.io/).

## Active configs

| File | Device | Description |
|------|--------|-------------|
| `desk-controller.yaml` | M5Stack NanoC6 / ESP32-C6 (`desk-c125`) | Standing desk raise/lower control with occupancy interlock and RGB status LED |
| `doors-controller.yaml` | ESP8266 NodeMCU v2 (`espgarage`) | Garage door relay + gate lock actuators + buzzer + contact sensor |
| `espresso-water.yaml` | DFRobot Beetle ESP32-C3 (`espresso`) | Battery-powered non-contact reservoir low-water sensor, deep sleep — see [`espresso-water.md`](espresso-water.md) |
| `presence-sensor.yaml` | M5Stack NanoC6 / ESP32-C6 (`espkitchen`) | LD2450 mmWave radar presence detection + Red Light/Green Light game |
| `trmnl.yaml` | ESP32-S3 (`trmnl`) | TRMNL epaper display frontend for Home Assistant data; deep sleep, custom partition table |

## Notes

- `secrets.yaml` is gitignored — each config pulls Wi-Fi and API credentials from it.
- `custom_partitions.csv` is the partition table for `trmnl.yaml` (two equal 1984K OTA slots).
  Editing it does **not** invalidate the ESPHome build cache, so run `esphome clean` afterward,
  and note that a partition-table change can only be applied over USB, never OTA.

## Archived configs

Older configs are preserved in `archive/` for reference.
