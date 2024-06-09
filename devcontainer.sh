#!/bin/bash

PROJECTS_FILE="projects.conf"

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
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    read_input "Enter your GitHub repository URL" $DEFAULT_GITHUB_REPO GITHUB_REPO
    read_input "Enter your Git user name" $DEFAULT_GIT_USER_NAME GIT_USER_NAME
    read_input "Enter your Git user email" $DEFAULT_GIT_USER_EMAIL GIT_USER_EMAIL

    # Prompt for unique ports
    read_input "Enter SSH port" "2222" SSH_PORT
    read_input "Enter HTTPS port" "8443" HTTPS_PORT

    # Validate GitHub repository URL
    if ! [[ "$GITHUB_REPO" =~ ^https://github.com/.* ]]; then
        exit_on_error "Invalid GitHub repository URL"
    fi

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
    mkdir -p dockers/$PROJECT_NAME
    cat <<EOF > dockers/$PROJECT_NAME/docker-compose.yml
version: '3.8'

services:
  dev:
    build:
      context: ../../dockers
      dockerfile: Dockerfile
    container_name: $DEFAULT_CONTAINER_NAME
    volumes:
      - ~/.ssh:/home/devuser/.ssh
      - ../../certs:/etc/ssl/private
    ports:
      - "$SSH_PORT:22"
      - "$HTTPS_PORT:8443"
    environment:
      - GITHUB_REPO=$GITHUB_REPO
      - GIT_USER_NAME=$GIT_USER_NAME
      - GIT_USER_EMAIL=$GIT_USER_EMAIL
    command: /bin/bash -c "service ssh start && su devuser -c '/home/devuser/setup.sh && code-server --cert=/etc/ssl/private/selfsigned.crt --cert-key=/etc/ssl/private/selfsigned.key --bind-addr 0.0.0.0:8443'"
EOF

    # Build and start the Docker container with the --build flag to force rebuild
    docker-compose -f dockers/$PROJECT_NAME/docker-compose.yml up --build -d || exit_on_error "Failed to build and start Docker container"

    # Wait for the container to be ready
    sleep 10

    # Check if the container is running
    if [ "$(docker inspect -f '{{.State.Running}}' $DEFAULT_CONTAINER_NAME)" != "true" ]; then
        docker logs $DEFAULT_CONTAINER_NAME
        exit_on_error "The Docker container is not running. Check the logs above for details."
    fi

    # Run the clone script inside the container
    docker exec -it $DEFAULT_CONTAINER_NAME bash -c "
      cd /home/devuser &&
      git clone $GITHUB_REPO project &&
      chown -R devuser:devuser project
    " || exit_on_error "Failed to clone GitHub repository inside the container"

    # Save project details
    echo "$PROJECT_NAME|$DEFAULT_CONTAINER_NAME|$GITHUB_REPO|$GIT_USER_NAME|$GIT_USER_EMAIL|$SSH_PORT|$HTTPS_PORT" >> $PROJECTS_FILE

    log "Setup complete for project $PROJECT_NAME. You can now access the container via SSH or Visual Studio Code."
}

# Function to start a container
start_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    if [ -f "dockers/$PROJECT_NAME/docker-compose.yml" ]; then
        docker-compose -f dockers/$PROJECT_NAME/docker-compose.yml up -d || exit_on_error "Failed to start Docker container for $PROJECT_NAME"
        log "Container started for project $PROJECT_NAME."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to stop a container
stop_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    if [ -f "dockers/$PROJECT_NAME/docker-compose.yml" ]; then
        docker-compose -f dockers/$PROJECT_NAME/docker-compose.yml down || exit_on_error "Failed to stop Docker container for $PROJECT_NAME"
        log "Container stopped for project $PROJECT_NAME."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to rebuild a container
rebuild_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    if [ -f "dockers/$PROJECT_NAME/docker-compose.yml" ]; then
        docker-compose -f dockers/$PROJECT_NAME/docker-compose.yml up --build -d || exit_on_error "Failed to rebuild Docker container for $PROJECT_NAME"
        log "Container rebuilt for project $PROJECT_NAME."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to remove a project
remove_project() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    if [ -f "dockers/$PROJECT_NAME/docker-compose.yml" ]; then
        docker-compose -f dockers/$PROJECT_NAME/docker-compose.yml down || exit_on_error "Failed to stop Docker container for $PROJECT_NAME"
        rm -rf dockers/$PROJECT_NAME
        sed -i "/^$PROJECT_NAME|/d" $PROJECTS_FILE
        log "Project $PROJECT_NAME removed."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to list all projects
list_projects() {
    if [ ! -f "$PROJECTS_FILE" ]; then
        echo "No projects found."
        return
    fi

    echo "Projects:"
    while IFS='|' read -r project_name container_name github_repo git_user_name git_user_email ssh_port https_port; do
        echo "Project: $project_name"
        echo "  Container: $container_name"
        echo "  Repository: $github_repo"
        echo "  Git User: $git_user_name"
        echo "  Git Email: $git_user_email"
        echo "  SSH Port: $ssh_port"
        echo "  HTTPS Port: $https_port"
        echo
    done < "$PROJECTS_FILE"
}

# Function to show container status
container_status() {
    docker ps -a || exit_on_error "Failed to get Docker container status"
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
    remove)
        remove_project
        ;;
    list)
        list_projects
        ;;
    status)
        container_status
        ;;
    *)
        echo "Usage: $0 {setup|start|stop|rebuild|remove|list|status}"
        exit 1
esac
