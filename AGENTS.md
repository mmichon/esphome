# Project Instructions

## ESPHome / Development

After editing ESPHome YAML config (e.g. m5nanoc6-ld2450.yaml), always build and upload to the device:

```bash
esphome run m5nanoc6-ld2450.yaml --device espkitchen.local
```

Or from the project root: `make upload`

Do not skip the upload step when the user asks for config changes.

## Icon Glyphs (ESPHome)

- Use Google Material Icons with `\U0000XXXX` codepoint format
- Use MaterialIcons-Regular.ttf, not MDI webfont

## Infrastructure

Proxmox VE is running on root@nuc.local (sshable).
On that host, there are VMs and LXCs running Pihole, Home Assistant, Zigbee2MQTT, Infinitive Bryant furnace interface, Plex, Nut, and Scrypted. You can ssh into most of those directly as well.
