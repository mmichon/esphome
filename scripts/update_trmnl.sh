#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse command line arguments
SEND_EMAIL=true
YAML_FILE="trmnl.yaml"
HOS_OVERRIDE_ARG=""
DEVICE_HOST="trmnl.local"

# Parse arguments, handling --noemail flag and positional args
POSITIONAL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --noemail)
      SEND_EMAIL=false
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done

# Set positional arguments (preserve original behavior)
if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
  YAML_FILE="${POSITIONAL_ARGS[0]}"
fi
if [ ${#POSITIONAL_ARGS[@]} -gt 1 ]; then
  HOS_OVERRIDE_ARG="${POSITIONAL_ARGS[1]}"
  DEVICE_HOST="$HOS_OVERRIDE_ARG"
fi

# Create local build directory to avoid slow Samba share I/O
LOCAL_BUILD_DIR="$HOME/tmp/esphome-builds/trmnl"
mkdir -p "$LOCAL_BUILD_DIR"

# Extract just the filename from YAML_FILE (in case it includes a path)
YAML_BASENAME="$(basename "$YAML_FILE")"
LOCAL_YAML_FILE="$LOCAL_BUILD_DIR/$YAML_BASENAME"

echo "==> Copying files to local build directory ($LOCAL_BUILD_DIR)"

# Copy YAML file only if it has changed (using checksum comparison)
if ! cmp -s "$ROOT_DIR/$YAML_FILE" "$LOCAL_YAML_FILE" 2>/dev/null; then
  echo "  -> Copying $YAML_FILE (file changed)"
  cp "$ROOT_DIR/$YAML_FILE" "$LOCAL_YAML_FILE"
else
  echo "  -> Skipping $YAML_FILE (unchanged)"
fi

# Copy secrets.yaml if it exists (ESPHome looks for it in the same directory)
SECRETS_SOURCE=""
if [ -f "$ROOT_DIR/secrets.yaml" ]; then
  SECRETS_SOURCE="$ROOT_DIR/secrets.yaml"
elif [ -f "$(dirname "$ROOT_DIR")/secrets.yaml" ]; then
  # Also check parent directory
  SECRETS_SOURCE="$(dirname "$ROOT_DIR")/secrets.yaml"
fi

if [ -n "$SECRETS_SOURCE" ]; then
  LOCAL_SECRETS="$LOCAL_BUILD_DIR/secrets.yaml"
  if ! cmp -s "$SECRETS_SOURCE" "$LOCAL_SECRETS" 2>/dev/null; then
    echo "  -> Copying secrets.yaml (file changed)"
    cp "$SECRETS_SOURCE" "$LOCAL_SECRETS"
  else
    echo "  -> Skipping secrets.yaml (unchanged)"
  fi
fi

# Copy fonts directory if it exists (ESPHome looks for fonts relative to project directory)
if [ -d "$ROOT_DIR/fonts" ]; then
  echo "  -> Copying fonts directory"
  mkdir -p "$LOCAL_BUILD_DIR/fonts"
  cp -r "$ROOT_DIR/fonts/"* "$LOCAL_BUILD_DIR/fonts/" 2>/dev/null || true
fi

# Copy icons directory if it exists (ESPHome looks for icons relative to project directory)
# Try Samba share first, then fall back to Proxmox host if needed
if [ -d "$ROOT_DIR/icons" ]; then
  echo "  -> Copying icons directory"
  mkdir -p "$LOCAL_BUILD_DIR/icons"
  cp -r "$ROOT_DIR/icons/"* "$LOCAL_BUILD_DIR/icons/" 2>/dev/null || true
elif ssh -o ConnectTimeout=2 -o BatchMode=yes root@nuc.local "test -d /mnt/pve/config/esphome/icons" 2>/dev/null; then
  echo "  -> Copying icons directory from Proxmox host"
  mkdir -p "$LOCAL_BUILD_DIR/icons"
  ssh root@nuc.local "cd /mnt/pve/config/esphome/icons && tar czf - *.png" 2>/dev/null | tar xzf - -C "$LOCAL_BUILD_DIR/icons/" 2>/dev/null || true
fi

# Copy partition table CSV if it exists (ESPHome looks for it relative to project directory)
if [ -f "$ROOT_DIR/custom_partitions.csv" ]; then
  LOCAL_PARTITIONS="$LOCAL_BUILD_DIR/custom_partitions.csv"
  if ! cmp -s "$ROOT_DIR/custom_partitions.csv" "$LOCAL_PARTITIONS" 2>/dev/null; then
    echo "  -> Copying custom_partitions.csv (file changed)"
    cp "$ROOT_DIR/custom_partitions.csv" "$LOCAL_PARTITIONS"
  else
    echo "  -> Skipping custom_partitions.csv (unchanged)"
  fi
fi

# Function to send email notification
send_email() {
  local status="$1"
  local output="$2"
  local subject="ESPHome Build: $status - $YAML_FILE"
  local body="ESPHome build script has finished.

Status: $status
YAML File: $YAML_FILE
Device: $DEVICE_HOST
Build Directory: $LOCAL_BUILD_DIR

Output:
$output"

  echo "$body" | mail -s "$subject" mmichon@gmail.com 2>/dev/null || true
}

# Function to show iTerm2 popup notification
show_iterm2_notification() {
  local status="$1"
  local message="ESPHome build finished: $status"

  # Try iTerm2-specific notification first
  if [[ "$TERM_PROGRAM" == "iTerm.app" ]] || [[ -n "${ITERM_SESSION_ID:-}" ]]; then
    # Use iTerm2's growl notification
    printf "\033]9;%s\033\\" "$message" 2>/dev/null || true
  fi

  # Also use macOS notification center (works in iTerm2)
  osascript -e "display notification \"$message\" with title \"ESPHome Build\" sound name \"Glass\"" 2>/dev/null || true
}

# Temporary file for capturing output
OUTPUT_FILE="/tmp/esphome_build_output_$$.txt"
STATUS_FILE="/tmp/esphome_build_status_$$.txt"
trap "rm -f '$OUTPUT_FILE' '$STATUS_FILE'" EXIT

# Run build process and capture output
(
  echo "==> Compiling $YAML_FILE (using local build directory)"
  # ESPHome automatically uses the directory containing the YAML file as the project directory
  esphome compile "$LOCAL_YAML_FILE" 2>&1
  COMPILE_STATUS=$?
  echo "$COMPILE_STATUS" > "$STATUS_FILE"

  if [ $COMPILE_STATUS -eq 0 ]; then
    echo "==> Waiting for $DEVICE_HOST to respond to ping"
    until ping -c 1 -W 1000 "$DEVICE_HOST" >/dev/null 2>&1; do
      printf '.'
      sleep 2
    done
    echo ""
    echo "==> $DEVICE_HOST is reachable"

    echo "==> Uploading and monitoring via esphome run"
    # ESPHome automatically uses the directory containing the YAML file as the project directory
    esphome run "$LOCAL_YAML_FILE" --device "$DEVICE_HOST" 2>&1
    RUN_STATUS=$?
    echo "$RUN_STATUS" > "$STATUS_FILE"
  fi
) | tee "$OUTPUT_FILE"

EXIT_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "1")
SCRIPT_OUTPUT="$(cat "$OUTPUT_FILE" 2>/dev/null || echo "Output capture failed")"

# Determine status
if [ $EXIT_STATUS -eq 0 ]; then
  STATUS="SUCCESS"
else
  STATUS="FAILED"
fi

# Show iTerm2 notification
show_iterm2_notification "$STATUS"

# Send email if enabled
if [ "$SEND_EMAIL" = true ]; then
  send_email "$STATUS" "$SCRIPT_OUTPUT"
fi

exit $EXIT_STATUS
