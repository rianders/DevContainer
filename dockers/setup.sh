#!/bin/bash

# Generate SSH keys if not present
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Configure SSH
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# Set up Git configuration
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# Install and configure Visual Studio Code server
curl -fsSL https://code-server.dev/install.sh | sh

# Start code-server
code-server --bind-addr 0.0.0.0:8080
