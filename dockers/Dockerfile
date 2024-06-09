# Use an official Python image as a base image
FROM python:3.11-slim

# Install necessary packages
RUN apt-get update && \
    apt-get install -y git openssh-server sudo vim curl && \
    apt-get clean

# Set up a non-root user
RUN useradd -ms /bin/bash devuser && echo "devuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create necessary directories with correct permissions
RUN mkdir -p /run/sshd && \
    chown -R root:root /run/sshd

# Ensure ssh directory exists and copy the authorized keys
RUN mkdir -p /home/devuser/.ssh && chmod 700 /home/devuser/.ssh
COPY id_devuser_rsa.pub /home/devuser/.ssh/authorized_keys
RUN chmod 600 /home/devuser/.ssh/authorized_keys
RUN chown -R devuser:devuser /home/devuser/.ssh

# Update sshd_config to use key-based authentication
RUN echo "PermitRootLogin no" >> /etc/ssh/sshd_config
RUN echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
RUN echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
RUN echo "UsePAM yes" >> /etc/ssh/sshd_config
RUN echo "AllowUsers devuser" >> /etc/ssh/sshd_config
RUN echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
RUN echo "AuthorizedKeysFile .ssh/authorized_keys" >> /etc/ssh/sshd_config
RUN echo "LogLevel DEBUG" >> /etc/ssh/sshd_config

# Copy the setup and build scripts as root, then change permissions
COPY setup.sh /home/devuser/setup.sh
COPY build.sh /home/devuser/build.sh
RUN chmod +x /home/devuser/setup.sh /home/devuser/build.sh

# Switch to non-root user for application setup
USER devuser
WORKDIR /home/devuser

# Install Visual Studio Code server (or handle download issues manually if needed)
RUN curl -fsSL https://code-server.dev/install.sh | sh || echo "code-server download failed, handle manually"

# Set a custom password for code-server
RUN mkdir -p /home/devuser/.config/code-server && \
    echo "bind-addr: 0.0.0.0:8080" > /home/devuser/.config/code-server/config.yaml && \
    echo "auth: password" >> /home/devuser/.config/code-server/config.yaml && \
    echo "password: mysecurepassword" >> /home/devuser/.config/code-server/config.yaml && \
    echo "cert: false" >> /home/devuser/.config/code-server/config.yaml

RUN rm -rf /home/devuser/project/

# Switch back to root to start services
USER root

EXPOSE 22 8080
CMD ["bash", "-c", "service ssh start && su devuser -c '/home/devuser/setup.sh && code-server --bind-addr 0.0.0.0:8080'"]
