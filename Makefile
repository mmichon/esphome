# Build and upload a config when it changes.
# Usage:
#   make upload CONFIG=presence-sensor.yaml DEVICE=espkitchen.local
#   make watch  CONFIG=presence-sensor.yaml DEVICE=espkitchen.local  (requires fswatch)

CONFIG := presence-sensor.yaml
DEVICE := espkitchen.local

.PHONY: upload watch

upload:
	esphome run $(CONFIG) --device $(DEVICE)

watch:
	fswatch -o $(CONFIG) | xargs -n1 -I{} esphome run $(CONFIG) --device $(DEVICE)
