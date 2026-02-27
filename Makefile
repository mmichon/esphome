# Build and upload LD2450 (espkitchen) when config changes.
# Usage:
#   make upload   - build and upload once
#   make watch    - watch m5nanoc6-ld2450.yaml and upload on change (requires fswatch)

CONFIG := m5nanoc6-ld2450.yaml
DEVICE := espkitchen.local

.PHONY: upload watch

upload:
	esphome run $(CONFIG) --device $(DEVICE)

watch:
	fswatch -o $(CONFIG) | xargs -n1 -I{} esphome run $(CONFIG) --device $(DEVICE)
