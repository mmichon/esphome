#!/bin/bash
# Script to add input_text.trmnl_banner helper to Home Assistant config
# Usage: ./add_trmnl_banner.sh

CONFIG_DIR="/Volumes/config"
INPUT_TEXT_FILE="$CONFIG_DIR/input_text_trmnl_banner.yaml"
CONFIG_YAML="$CONFIG_DIR/configuration.yaml"

# Check if config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: $CONFIG_DIR not found."
    echo ""
    echo "Please mount the Home Assistant config directory first:"
    echo "  mkdir -p /Volumes/config"
    echo "  mount -t smbfs //mmichon@hass/config /Volumes/config"
    echo ""
    echo "Or manually copy input_text_trmnl_banner.yaml to your Home Assistant config directory"
    exit 1
fi

# Create the input_text file
cat > "$INPUT_TEXT_FILE" << 'YAML'
trmnl_banner:
  name: TRMNL Banner
  initial: ""
  mode: text
  icon: mdi:message-text
YAML

echo "✓ Created $INPUT_TEXT_FILE"

# Check if configuration.yaml exists
if [ ! -f "$CONFIG_YAML" ]; then
    echo "Warning: $CONFIG_YAML not found"
    exit 1
fi

# Check if input_text is already configured
if grep -q "^input_text:" "$CONFIG_YAML" 2>/dev/null; then
    # Check if our file is already included
    if grep -q "input_text_trmnl_banner.yaml" "$CONFIG_YAML" 2>/dev/null; then
        echo "✓ input_text_trmnl_banner.yaml is already included in configuration.yaml"
    else
        echo ""
        echo "⚠ Please add this line to your configuration.yaml under the input_text: section:"
        echo ""
        echo "  input_text: !include input_text_trmnl_banner.yaml"
        echo ""
        echo "Or if you're using a list format, add:"
        echo "  - !include input_text_trmnl_banner.yaml"
    fi
else
    echo ""
    echo "⚠ Please add this to your configuration.yaml:"
    echo ""
    echo "input_text: !include input_text_trmnl_banner.yaml"
fi

echo ""
echo "After updating configuration.yaml, restart Home Assistant for the changes to take effect."
