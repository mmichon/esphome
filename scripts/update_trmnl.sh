#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="$ROOT_DIR/trmnl.yml"
DEVICE_HOST="trmnl.local"

echo "==> Compiling $CONFIG_PATH"
esphome compile "$CONFIG_PATH"

echo "==> Waiting for $DEVICE_HOST to respond to ping"
until ping -c 1 -W 1000 "$DEVICE_HOST" >/dev/null 2>&1; do
  printf '.'
  sleep 2
done
echo ""
echo "==> $DEVICE_HOST is reachable"

echo "==> Uploading and monitoring via esphome run"
esphome run "$CONFIG_PATH" --device "$DEVICE_HOST"

