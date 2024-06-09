#!/bin/bash

# Copy VS Code settings if they exist
if [ -d ".vscode" ]; then
    cp -r .vscode /home/devuser/.vscode
else
    echo "No .vscode directory found, skipping."
fi

rm -rf /home/devuser/project/

# # Copy Python dependency files if they exist
# if [ -f "requirements.txt" ]; then
#     cp requirements.txt /home/devuser/project/
# fi

# if [ -f "pyproject.toml" ]; then
#     cp pyproject.toml /home/devuser/project/
# fi

# if [ -f "poetry.lock" ]; then
#     cp poetry.lock /home/devuser/project/
# fi
