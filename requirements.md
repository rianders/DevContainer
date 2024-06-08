
# Requirements

## Prerequisites

- Docker: [Install Docker](https://docs.docker.com/get-docker/)
- Docker Compose: [Install Docker Compose](https://docs.docker.com/compose/install/)

## Python Dependencies

- A `requirements.txt` file for `pip`:
  ```plaintext
  package1==1.0.0
  package2==2.0.0
  ```

- Or a `pyproject.toml` and `poetry.lock` file for `Poetry`:
  ```toml
  [tool.poetry]
  name = "your_project"
  version = "0.1.0"
  description = ""
  authors = ["Your Name <your.email@example.com>"]

  [tool.poetry.dependencies]
  python = "^3.11"
  package1 = "^1.0.0"
  package2 = "^2.0.0"
  ```

## Environment Variables

- `GITHUB_REPO`: URL of your GitHub repository to clone.
- `GIT_USER_NAME`: Your Git user name.
- `GIT_USER_EMAIL`: Your Git user email.
