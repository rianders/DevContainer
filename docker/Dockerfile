# Use an official Python image as a base image
FROM python:3.11-slim

# Install necessary packages
RUN apt-get update && \
    apt-get install -y git openssh-server sudo vim curl && \
    apt-get clean

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt update && \
    sudo apt install gh

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
RUN ln -s /root/.local/bin/poetry /usr/local/bin/poetry


# Set up a non-root user
RUN useradd -ms /bin/bash devuser && echo "devuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create necessary directories with correct permissions
RUN mkdir -p /run/sshd && \
    chown -R root:root /run/sshd

# Switch to non-root user for application setup
USER devuser
WORKDIR /home/devuser

# Install Visual Studio Code server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Set a custom password for code-server
RUN mkdir -p /home/devuser/.config/code-server && \
    echo "bind-addr: 0.0.0.0:8080" > /home/devuser/.config/code-server/config.yaml && \
    echo "auth: password" >> /home/devuser/.config/code-server/config.yaml && \
    echo "password: mysecurepassword" >> /home/devuser/.config/code-server/config.yaml && \
    echo "cert: false" >> /home/devuser/.config/code-server/config.yaml

# Copy the setup script
COPY --chown=devuser:devuser setup.sh /home/devuser/setup.sh
RUN chmod +x /home/devuser/setup.sh

# Copy and run the build script
COPY --chown=devuser:devuser build.sh /home/devuser/build.sh
RUN chmod +x /home/devuser/build.sh && /home/devuser/build.sh

RUN rm -rf /home/devuser/project/

# Switch back to root to start services
USER root

EXPOSE 22 8080
CMD ["bash", "-c", "service ssh start && su devuser -c 'code-server --bind-addr 0.0.0.0:8080'"]
