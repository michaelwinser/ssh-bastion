FROM alpine:latest

# Install OpenSSH
RUN apk add --no-cache openssh-server openssh-keygen shadow

# Create a non-root user 'bastion'
# -D: Don't assign a password
# -s /bin/false: No shell access (only port forwarding)
RUN adduser -D -s /bin/false -u 1000 bastion \
    && passwd -u bastion

# Create necessary directories
RUN mkdir -p /config /home/bastion/.ssh \
    && chown bastion:bastion /home/bastion/.ssh \
    && chmod 700 /home/bastion/.ssh

# Copy configuration
COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Expose the custom SSH port
EXPOSE 2222

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
