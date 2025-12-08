# Minimal SSH Bastion (Alpine Based)

This is a lightweight, secure SSH bastion (jump host) Docker image based on Alpine Linux. It is designed to be deployed on TrueNAS Scale or any Docker environment.

## Features

-   **Minimal Footprint**: Based on Alpine Linux (~15MB final image size).
-   **Secure**:
    -   Non-root user `bastion` for connections.
    -   Shell access disabled (`/bin/false`).
    -   Password authentication disabled.
    -   Root login disabled.
-   **Persistent Identity**: Host keys are generated on first run and stored in a persistent volume, ensuring the server identity doesn't change across container updates.

## Usage

### 1. Prerequisites

You need a directory on your host to store configuration (host keys and authorized keys).

```bash
mkdir -p config
```

### 2. Add Authorized Keys

Create an `authorized_keys` file in your config directory containing the public keys of users who should have access.

```bash
# Example: Add your current public key
cat ~/.ssh/id_rsa.pub > config/authorized_keys
```

### 3. Build and Run

**Production (Pull from GHCR):**
```bash
docker-compose up -d
```

**Local Development (Build from source):**
```bash
docker-compose -f docker-compose.dev.yml up -d --build
```

### 4. Connecting

To use this bastion to jump to another server (e.g., `192.168.1.100`):

```bash
ssh -J bastion@<bastion-ip>:2222 user@192.168.1.100
```

*Note: Replace `<bastion-ip>` with the IP address of your Docker host (or TrueNAS server).*

### 5. Using ~/.ssh/config (Recommended)

To simplify connections, especially with custom ports, add the following to your `~/.ssh/config`:

```ssh
Host my-bastion
    HostName <bastion-ip>
    User bastion
    Port 2222

Host internal-server
    HostName 192.168.1.100
    User user
    ProxyJump my-bastion
```

Then you can simply run:
```bash
ssh internal-server
```

### 6. Key Management

#### Live Updates
The container monitors `/config/authorized_keys` for changes. If you update this file on the host (e.g., via TrueNAS editor or script), the changes are immediately applied to the bastion user without restarting the container.

#### URL Synchronization
You can automatically sync keys from a public URL (e.g., GitHub raw file, internal web server).

**Environment Variables:**
-   `KEYS_URL`: URL to fetch `authorized_keys` from (Required to enable sync).
-   `SYNC_INTERVAL`: Cron schedule (Default: `0 * * * *` - every hour).

**Example Docker Compose:**
```yaml
    environment:
      - KEYS_URL=https://github.com/myuser.keys
      - SYNC_INTERVAL=*/15 * * * *
```

## TrueNAS Scale Deployment

1.  **Create a Dataset**: Create a dataset for the bastion configuration (e.g., `/mnt/pool/apps/bastion-config`).
2.  **Add Authorized Keys**: Place your `authorized_keys` file inside that dataset.
3.  **Launch Docker Image**:
    -   **Image**: `ghcr.io/michaelwinser/ssh-bastion:latest`
        *(Note: Ensure your TrueNAS has access to pull from GHCR. If the repo is private, you may need to configure registry credentials).*
    -   **Networking**: Map container port `2222` to a host port (e.g., `2222`).
    -   **Storage**: Add a Host Path volume.
        -   **Host Path**: `/mnt/pool/apps/bastion-config`
        -   **Mount Path**: `/config`
    -   **Environment**: Set `TZ` if needed.

## Security Notes

-   The `bastion` user has `/bin/false` as a shell. This means you cannot get an interactive shell on the bastion itself (e.g., `ssh bastion@host` will close immediately). This is by design. You can only use it for port forwarding (`-L`, `-R`, `-D`) or jumping (`-J`).
-   Host keys are generated automatically on the first run and stored in `/config/ssh_host_keys`.
