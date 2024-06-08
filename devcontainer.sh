#!/bin/bash

# Function to read user input with a default value
read_input() {
    local prompt="$1"
    local default="$2"
    local input_variable="$3"
    read -p "$prompt [$default]: " input
    input="${input:-$default}"
    eval $input_variable="'$input'"
}

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Exit on error function
exit_on_error() {
    log "Error: $1"
    exit 1
}

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    exit_on_error "Docker is not installed. Please install Docker and try again."
fi

if ! docker info &> /dev/null; then
    exit_on_error "Docker is not running. Please start Docker and try again."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    exit_on_error "Docker Compose is not installed. Please install Docker Compose and try again."
fi

# Function to setup the container
setup_container() {
    # Default values
    DEFAULT_GITHUB_REPO="https://github.com/ricklon/gpt4vision-streamlit"
    DEFAULT_GIT_USER_NAME="ricklon"
    DEFAULT_GIT_USER_EMAIL="rick.rickanderson@gmail.com"

    # Get user input with default values
    read_input "Enter your GitHub repository URL" $DEFAULT_GITHUB_REPO GITHUB_REPO
    read_input "Enter your Git user name" $DEFAULT_GIT_USER_NAME GIT_USER_NAME
    read_input "Enter your Git user email" $DEFAULT_GIT_USER_EMAIL GIT_USER_EMAIL

    # Generate SSH keys if not present
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" || exit_on_error "Failed to generate SSH keys"
    fi

    # Configure SSH
    eval "$(ssh-agent -s)" || exit_on_error "Failed to start ssh-agent"
    ssh-add ~/.ssh/id_rsa || exit_on_error "Failed to add SSH key to the agent"

    # Set up Git configuration
    git config --global user.name "$GIT_USER_NAME" || exit_on_error "Failed to set Git user name"
    git config --global user.email "$GIT_USER_EMAIL" || exit_on_error "Failed to set Git user email"

    # Create or update docker-compose.yml
    cat <<EOF > docker/docker-compose.yml
version: '3.8'

services:
  dev:
    build: .
    container_name: dev_container
    volumes:
      - ~/.ssh:/home/devuser/.ssh
    ports:
      - "2222:22"
      - "8080:8080"
    environment:
      - GITHUB_REPO=$GITHUB_REPO
      - GIT_USER_NAME=$GIT_USER_NAME
      - GIT_USER_EMAIL=$GIT_USER_EMAIL
    command: /bin/bash -c "service ssh start && su devuser -c 'code-server --bind-addr 0.0.0.0:8080'"
EOF

    # Build and start the Docker container with the --build flag to force rebuild
    docker-compose -f docker/docker-compose.yml up --build -d || exit_on_error "Failed to build and start Docker container"

    # Wait for the container to be ready
    sleep 10

    # Check if the container is running
    if [ "$(docker inspect -f '{{.State.Running}}' dev_container)" != "true" ]; then
        docker logs dev_container
        exit_on_error "The Docker container is not running. Check the logs above for details."
    fi

    # Run the clone script inside the container
    docker exec -it dev_container bash -c "
      cd /home/devuser &&
      git clone $GITHUB_REPO project &&
      chown -R devuser:devuser project
    " || exit_on_error "Failed to clone GitHub repository inside the container"

    log "Setup complete. You can now access the container via SSH or Visual Studio Code."
}

# Function to start the container
start_container() {
    docker-compose -f docker/docker-compose.yml up -d || exit_on_error "Failed to start Docker container"
    log "Container started."
}

# Function to stop the container
stop_container() {
    docker-compose -f docker/docker-compose.yml down || exit_on_error "Failed to stop Docker container"
    log "Container stopped."
}

# Function to rebuild the container
rebuild_container() {
    docker-compose -f docker/docker-compose.yml up --build -d || exit_on_error "Failed to rebuild Docker container"
    log "Container rebuilt."
}

# Parse command line arguments
case "$1" in
    setup)
        setup_container
        ;;
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    rebuild)
        rebuild_container
        ;;
    *)
        echo "Usage: $0 {setup|start|stop|rebuild}"
        exit 1
esac
