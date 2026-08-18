## Device Flashing (ESPHome / TRMNL / e-ink)
- TRMNL OTA works as of 2026-08-18. It previously failed with "OTA partition is too small" because
  `custom_partitions.csv` had an undersized `ota_1` (896K) while firmware had grown to ~999K; the
  slots are now two equal 1984K OTA partitions. If that error ever returns, compare firmware size
  against the slot sizes rather than assuming the device needs a USB flash.
- A partition-table change can only be applied over USB, and editing `custom_partitions.csv` does
  not invalidate the build cache — run `esphome clean` first, or `firmware.factory.bin` keeps the
  old app offset and produces an unbootable device.
- `esphome upload` over serial can fail with "Detected overlap at address: 0x15000"; flash the
  merged `firmware.factory.bin` alone at `0x0` with esptool instead.
- The TRMNL only enumerates `/dev/cu.usbmodem*` briefly after a reset press — poll for the port in
  a loop that flashes the instant it appears, rather than trying to catch it by hand.
- For the X3, use the 4-pin data cable, not the pogo charge-only cable. If the device doesn't enumerate, re-seat and re-check `ls /dev/cu.*` before debugging esptool.
