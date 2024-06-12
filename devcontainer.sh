#!/bin/bash

# File to store project configurations
PROJECTS_FILE="projects.conf"

# Set DEVCONTAINERS_DIR to your desired directory
DEVCONTAINERS_DIR="${HOME}/devcontainers"

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

# Check if a port is already in use using lsof
check_port_in_use() {
    local port=$1
    if lsof -i :$port &> /dev/null; then
        return 0  # Port is in use
    else
        return 1  # Port is not in use
    fi
}

# Prompt for port with availability check
prompt_for_port() {
    local prompt="$1"
    local default_port="$2"
    local port_variable="$3"
    local port=$default_port

    while true; do
        read_input "$prompt" "$port" port
        if [ "$port" == "o" ]; then
            eval $port_variable="'$default_port'"
            break
        elif check_port_in_use "$port"; then
            echo "Port $port is already in use. Please choose a different port or enter 'o' to override."
        else
            eval $port_variable="'$port'"
            break
        fi
    done
}

# Function to remove a project
remove_project() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    CODE_SERVER_CONTAINER_NAME="code-server-${PROJECT_NAME}"
    PROJECT_DIR="${DEVCONTAINERS_DIR}/${PROJECT_NAME}"

    # Debugging output
    log "Removing project: ${PROJECT_NAME}"
    log "Project directory: ${PROJECT_DIR}"
    log "Container name: ${DEFAULT_CONTAINER_NAME}"

    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        docker-compose -f ${PROJECT_DIR}/docker-compose.yml down || exit_on_error "Failed to stop Docker container for $PROJECT_NAME"
        rm -rf ${PROJECT_DIR}
        if [ -f "$PROJECTS_FILE" ]; then
            sed -i '' "/^$PROJECT_NAME|/d" $PROJECTS_FILE || exit_on_error "Failed to update $PROJECTS_FILE"
        fi
        log "Project $PROJECT_NAME removed."
    else
        log "Configuration not found at ${PROJECT_DIR}/docker-compose.yml"
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to setup a container
setup_container() {
    # Default values
    DEFAULT_GITHUB_REPO="https://github.com/ricklon/gpt4vision-streamlit"
    DEFAULT_GIT_USER_NAME="ricklon"
    DEFAULT_GIT_USER_EMAIL="rick.rickanderson@gmail.com"
    DEFAULT_DEVCONTAINERS_DIR="${HOME}/devcontainers"
    DEFAULT_SSH_PORT="2023"
    DEFAULT_CODE_SERVER_PORT="8444"
    DEFAULT_HTTP_PORT="8081"

    # Get user input with default values
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    CODE_SERVER_CONTAINER_NAME="code-server-${PROJECT_NAME}"
    read_input "Enter your GitHub repository URL" $DEFAULT_GITHUB_REPO GITHUB_REPO
    read_input "Enter your Git user name" $DEFAULT_GIT_USER_NAME GIT_USER_NAME
    read_input "Enter your Git user email" $DEFAULT_GIT_USER_EMAIL GIT_USER_EMAIL
    read_input "Enter the location for devcontainers" $DEFAULT_DEVCONTAINERS_DIR DEVCONTAINERS_DIR
    read_input "Do you want to provide a GitHub PAT? (y/n)" "n" USE_PAT

    if [ "$USE_PAT" == "y" ]; then
        read_input "Enter your GitHub personal access token" "" GITHUB_PAT
    fi

    prompt_for_port "Enter the SSH port to use (Available: 'o' to override)" $DEFAULT_SSH_PORT SSH_PORT
    prompt_for_port "Enter the code server port to use (Available: 'o' to override)" $DEFAULT_CODE_SERVER_PORT CODE_SERVER_PORT
    prompt_for_port "Enter the HTTP port to use (Available: 'o' to override)" $DEFAULT_HTTP_PORT HTTP_PORT

    # Validate GitHub repository URL
    if ! [[ "$GITHUB_REPO" =~ ^https://github.com/.* ]]; then
        exit_on_error "Invalid GitHub repository URL"
    fi

    # Remove existing container if it exists
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${DEFAULT_CONTAINER_NAME}\$"; then
        log "Removing existing container ${DEFAULT_CONTAINER_NAME}"
        docker-compose -f ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml down || exit_on_error "Failed to remove existing container"
    fi

    # Create or update docker-compose.yml
    mkdir -p ${DEVCONTAINERS_DIR}/${PROJECT_NAME}
    cat <<EOF > ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml
version: '3.8'

services:
  dev:
    build:
      context: .  # This should be relative to the location of docker-compose.yml
      dockerfile: Dockerfile.dev
    container_name: $DEFAULT_CONTAINER_NAME
    ports:
      - "${SSH_PORT}:22"
      - "${HTTP_PORT}:8080"
    environment:
      - GITHUB_REPO=$GITHUB_REPO
      - GIT_USER_NAME=$GIT_USER_NAME
      - GIT_USER_EMAIL=$GIT_USER_EMAIL
    volumes:
      - dev-home:/home/devuser

  code-server:
    image: codercom/code-server:latest
    container_name: $CODE_SERVER_CONTAINER_NAME
    ports:
      - "${CODE_SERVER_PORT}:8080"  # Map external port CODE_SERVER_PORT to internal port 8080
    environment:
      - PASSWORD=mysecurepassword
    volumes:
      - dev-home:/home/devuser
    command: --auth password --bind-addr 0.0.0.0:8080 /home/devuser/project
    networks:
      - dev-network

volumes:
  dev-home:

networks:
  dev-network:
EOF

    # Change to the script directory
    cd "$SCRIPT_DIR"

    # Copy the Dockerfile and other necessary files to the devcontainer directory
    cp Dockerfile.dev ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/Dockerfile.dev || exit_on_error "Failed to copy Dockerfile"
    cp dockers/id_devuser_rsa.pub ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/id_devuser_rsa.pub || exit_on_error "Failed to copy SSH public key"
    cp dockers/setup.sh ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/setup.sh || exit_on_error "Failed to copy setup.sh"
    cp dockers/build.sh ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/build.sh || exit_on_error "Failed to copy build.sh"

    # Build and start the Docker container with the --build flag to force rebuild
    while ! docker-compose -f ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml up --build -d; do
        log "Port conflict detected during startup. Reconfiguring ports..."
        prompt_for_port "Enter a new SSH port to use" $SSH_PORT SSH_PORT
        prompt_for_port "Enter a new code server port to use" $CODE_SERVER_PORT CODE_SERVER_PORT
        prompt_for_port "Enter a new HTTP port to use" $HTTP_PORT HTTP_PORT
        
        # Update docker-compose.yml with new ports
        cat <<EOF > ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml
version: '3.8'

services:
  dev:
    build:
      context: .  # This should be relative to the location of docker-compose.yml
      dockerfile: Dockerfile.dev
    container_name: $DEFAULT_CONTAINER_NAME
    ports:
      - "${SSH_PORT}:22"
      - "${HTTP_PORT}:8080"
    environment:
      - GITHUB_REPO=$GITHUB_REPO
      - GIT_USER_NAME=$GIT_USER_NAME
      - GIT_USER_EMAIL=$GIT_USER_EMAIL
    volumes:
      - dev-home:/home/devuser

  code-server:
    image: codercom/code-server:latest
    container_name: $CODE_SERVER_CONTAINER_NAME
    ports:
      - "${CODE_SERVER_PORT}:8080"  # Map external port CODE_SERVER_PORT to internal port 8080
    environment:
      - PASSWORD=mysecurepassword
    volumes:
      - dev-home:/home/devuser
    command: --auth password --bind-addr 0.0.0.0:8080 /home/devuser/project
    networks:
      - dev-network

volumes:
  dev-home:

networks:
  dev-network:
EOF
    done

    # Wait for the container to be ready
    sleep 10

    # Check if the container is running
    if [ "$(docker inspect -f '{{.State.Running}}' $DEFAULT_CONTAINER_NAME)" != "true" ]; then
        docker logs $DEFAULT_CONTAINER_NAME
        exit_on_error "The Docker container is not running. Check the logs above for details."
    fi

    # Run the clone script inside the container using the PAT if provided
    if [ "$USE_PAT" == "y" ]; then
        CLONE_CMD="git clone https://$GITHUB_PAT@github.com/${GITHUB_REPO#https://github.com/} project"
    else
        CLONE_CMD="git clone $GITHUB_REPO project"
    fi

    docker exec -it $DEFAULT_CONTAINER_NAME bash -c "
      cd /home/devuser &&
      $CLONE_CMD &&
      chown -R devuser:devuser project
    " || exit_on_error "Failed to clone GitHub repository inside the container"

    # Save project details
    echo "$PROJECT_NAME|$DEFAULT_CONTAINER_NAME|$GITHUB_REPO|$GIT_USER_NAME|$GIT_USER_EMAIL|$DEVCONTAINERS_DIR|$SSH_PORT|$CODE_SERVER_PORT|$HTTP_PORT" >> $PROJECTS_FILE

    log "Setup complete for project $PROJECT_NAME. You can now access the container via SSH on port $SSH_PORT, the code server on port $CODE_SERVER_PORT, or the HTTP server on port $HTTP_PORT."
}

# Function to start a container
start_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    CODE_SERVER_CONTAINER_NAME="code-server-${PROJECT_NAME}"
    if [ -f "${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml" ]; then
        docker-compose -f ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml up -d || exit_on_error "Failed to start Docker container for $PROJECT_NAME"
        log "Container started for project $PROJECT_NAME."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to stop a container
stop_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    CODE_SERVER_CONTAINER_NAME="code-server-${PROJECT_NAME}"
    if [ -f "${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml" ]; then
        docker-compose -f ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml down || exit_on_error "Failed to stop Docker container for $PROJECT_NAME"
        log "Container stopped for project $PROJECT_NAME."
    else
        exit_on_error "No configuration found for project $PROJECT_NAME."
    fi
}

# Function to rebuild a container
rebuild_container() {
    read_input "Enter your project name" "project1" PROJECT_NAME
    DEFAULT_CONTAINER_NAME="${PROJECT_NAME}_container"
    CODE_SERVER_CONTAINER_NAME="code-server-${PROJECT_NAME}"
    if [ -f "${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml" ]; then
        docker-compose -f ${DEVCONTAINERS_DIR}/${PROJECT_NAME}/docker-compose.yml up --build -d || exit_on_error "Failed to rebuild Docker container for $PROJECT_NAME"
        log "Container rebuilt for project $PROJECT_NAME."
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
    while IFS='|' read -r project_name container_name github_repo git_user_name git_user_email devcontainers_dir ssh_port code_server_port http_port; do
        echo "Project: $project_name"
        echo "  Container: $container_name"
        echo "  Repository: $github_repo"
        echo "  Git User: $git_user_name"
        echo "  Git Email: $git_user_email"
        echo "  Devcontainer Dir: $devcontainers_dir"
        echo "  SSH Port: $ssh_port"
        echo "  Code Server Port: $code_server_port"
        echo "  HTTP Port: $http_port"
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
