#!/bin/sh
set -e

# Define paths
HOST_KEYS_DIR="/config/ssh_host_keys"
ETC_SSH_DIR="/etc/ssh"
AUTHORIZED_KEYS_SRC="/config/authorized_keys"
AUTHORIZED_KEYS_DST="/home/bastion/.ssh/authorized_keys"

echo "Starting SSH Bastion..."

# Ensure config directory exists
if [ ! -d "/config" ]; then
    echo "ERROR: /config volume is not mounted!"
    exit 1
fi

# Create host keys directory if it doesn't exist
if [ ! -d "$HOST_KEYS_DIR" ]; then
    echo "Creating host keys directory..."
    mkdir -p "$HOST_KEYS_DIR"
fi

# Generate host keys if they don't exist
if [ ! -f "$HOST_KEYS_DIR/ssh_host_rsa_key" ]; then
    echo "Generating new SSH host keys..."
    ssh-keygen -A
    # Move generated keys to persistence directory
    mv /etc/ssh/ssh_host_* "$HOST_KEYS_DIR/"
fi

# Symlink host keys from persistence directory to /etc/ssh
echo "Linking host keys..."
ln -sf "$HOST_KEYS_DIR"/ssh_host_* "$ETC_SSH_DIR/"

# Create .ssh directory for bastion user
mkdir -p /home/bastion/.ssh
chmod 700 /home/bastion/.ssh
chown bastion:bastion /home/bastion/.ssh

# Start the watcher in the background to handle live updates
echo "Starting key watcher..."
/watcher.sh &

# Setup URL Sync if configured
if [ -n "$KEYS_URL" ]; then
    echo "Configuring URL Sync..."
    # Default to every hour if not set
    INTERVAL="${SYNC_INTERVAL:-0 * * * *}"
    echo "$INTERVAL /url-sync.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root
    
    # Run once immediately
    /url-sync.sh
    
    # Start crond in background
    crond -b -L /var/log/cron.log
elif [ -f "$AUTHORIZED_KEYS_SRC" ]; then
    # Fallback: Copy existing keys if no sync is configured
    echo "Setting up authorized_keys from local file..."
    cp "$AUTHORIZED_KEYS_SRC" "$AUTHORIZED_KEYS_DST"
    chmod 600 "$AUTHORIZED_KEYS_DST"
    chown bastion:bastion "$AUTHORIZED_KEYS_DST"
else
    echo "WARNING: No authorized_keys found at $AUTHORIZED_KEYS_SRC and KEYS_URL is not set."
    echo "You won't be able to log in unless you add keys to /config/authorized_keys!"
fi

# Fix permissions for host keys (must be owned by root and 600)
chown root:root "$HOST_KEYS_DIR"/ssh_host_*
chmod 600 "$HOST_KEYS_DIR"/ssh_host_*

echo "Starting sshd..."
exec /usr/sbin/sshd -D -e
