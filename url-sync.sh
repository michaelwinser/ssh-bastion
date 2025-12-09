#!/bin/sh
# URL Sync Script
# Syncs keys from a URL to /config/authorized_keys

URL="${KEYS_URL}"
TARGET_FILE="/config/authorized_keys"

if [ -z "$URL" ]; then
    echo "[URL-Sync] KEYS_URL not set. Exiting."
    exit 0
fi

echo "[URL-Sync] Fetching keys from $URL..."

# Use curl to fetch the keys
# -s: Silent
# -f: Fail silently on server errors (so we don't overwrite with error page)
# -S: Show error if it fails
if curl -s -f -S "$URL" -o "$TARGET_FILE.tmp"; then
    mv "$TARGET_FILE.tmp" "$TARGET_FILE"
    chmod 644 "$TARGET_FILE"
    echo "[URL-Sync] Keys updated successfully in $TARGET_FILE."
    
    # Copy to bastion user's .ssh directory
    BASTION_KEYS="/home/bastion/.ssh/authorized_keys"
    cp "$TARGET_FILE" "$BASTION_KEYS"
    chown bastion:bastion "$BASTION_KEYS"
    chmod 600 "$BASTION_KEYS"
    echo "[URL-Sync] Keys synced to $BASTION_KEYS"
else
    echo "[URL-Sync] Failed to fetch keys from $URL"
    rm -f "$TARGET_FILE.tmp"
fi
