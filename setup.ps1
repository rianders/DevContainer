
# Function to read user input
function Read-Input {
    param (
        [string]$Prompt,
        [ref]$Input
    )
    $Input.Value = Read-Host $Prompt
}

# Get user input
Read-Input "Enter your GitHub repository URL: " ([ref]$GITHUB_REPO)
Read-Input "Enter your Git user name: " ([ref]$GIT_USER_NAME)
Read-Input "Enter your Git user email: " ([ref]$GIT_USER_EMAIL)

# Create or update docker-compose.yml
@"
version: '3.8'

services:
  dev:
    build: .
    container_name: dev_container
    volumes:
      - .:/home/devuser/project
      - $env:USERPROFILE\.ssh:/home/devuser/.ssh
    ports:
      - "2222:22"
      - "8080:8080"
    environment:
      - GITHUB_REPO=$($GITHUB_REPO.Value)
      - GIT_USER_NAME=$($GIT_USER_NAME.Value)
      - GIT_USER_EMAIL=$($GIT_USER_EMAIL.Value)
    command: /usr/sbin/sshd -D
"@ | Out-File -FilePath docker\docker-compose.yml -Encoding utf8

# Build and start the Docker container
docker-compose -f docker\docker-compose.yml up --build -d

# Wait for the container to be ready
Start-Sleep -Seconds 10

# Run the clone script inside the container
docker exec -it dev_container bash -c "
  cd /home/devuser &&
  git clone $($GITHUB_REPO.Value) project &&
  chown -R devuser:devuser project
"

Write-Host "Setup complete. You can now access the container via SSH or Visual Studio Code."
