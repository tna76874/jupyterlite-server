#!/bin/bash
set -e

# --- 1. Load Configuration ---
if [ -f .env ]; then
  # Read .env line by line, ignore comments and empty lines, then export
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^#.*$ ]] && continue # Skip comments
    [[ -z "$line" ]] && continue      # Skip empty lines
    export "$line"
  done < .env
else
  echo "Error: .env file not found!"
  exit 1
fi

# Debugging: Verify variables are set (Optional)
echo "Passing to Docker: Python=$PYTHON_VERSION, Nginx=$NGINX_VERSION"

# --- 2. Determine Repository & Image Names ---
if [ -z "$GITHUB_REPOSITORY" ]; then
  # If running locally, extract the repository name from git config
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  # Fallback if no git remote is found
  : "${GITHUB_REPOSITORY:=jupyterlite-custom}"
fi

IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}"
COMMIT_HASH=$(git rev-parse --short HEAD || echo "local")

# Sanitize Python version for tagging (replace colons with dashes)
CLEAN_PYTHON=$(echo "$PYTHON_VERSION" | tr ':' '-')

echo "-------------------------------------------------------"
echo "Configuration Summary:"
echo "Image Name:      $IMAGE_NAME"
echo "JupyterLite:     $JUPYTERLITE_VERSION"
echo "Python Version:  $PYTHON_VERSION"
echo "Nginx Version:   $NGINX_VERSION"
echo "-------------------------------------------------------"

# ensure content folder
mkdir -p ./content

# --- 3. Docker Build ---
# Pass the build arguments defined in .env to the Dockerfile
docker build \
  --no-cache \
  --pull \
  --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
  --build-arg NGINX_VERSION="${NGINX_VERSION}" \
  --build-arg JUPYTERLITE_VERSION="${JUPYTERLITE_VERSION}" \
  -t "${IMAGE_NAME}:${COMMIT_HASH}" \
  .

# --- 4. Tagging & Push Function ---
tag_and_push() {
  local TAG=$1
  echo "=> Tagging: ${IMAGE_NAME}:${TAG}"
  docker tag "${IMAGE_NAME}:${COMMIT_HASH}" "${IMAGE_NAME}:${TAG}"
  
  # Only push to registry if running in a CI environment (like GitHub Actions)
  if [ "$CI" == "true" ]; then
    echo "=> Pushing: ${IMAGE_NAME}:${TAG} ..."
    docker push "${IMAGE_NAME}:${TAG}"
  fi
}

# --- 5. Generate Tags ---

# Standard tags
tag_and_push "latest"

# Detailed version tag: e.g., v0.7.4-python3.11-slim
VERSION_TAG="v${JUPYTERLITE_VERSION}-python${CLEAN_PYTHON}"
tag_and_push "${VERSION_TAG}"

# Short version tag: e.g., lite-0.7.4
tag_and_push "lite-${JUPYTERLITE_VERSION}"

# Final push of the unique commit hash (CI only)
if [ "$CI" == "true" ]; then
  echo "=> Pushing base hash tag: ${IMAGE_NAME}:${COMMIT_HASH}"
  docker push "${IMAGE_NAME}:${COMMIT_HASH}"
  echo "--- Build & Push for version ${VERSION_TAG} completed successfully ---"
else
  echo "--- Local Build Finished ---"
  echo "Created Tags:"
  echo " - ${IMAGE_NAME}:${COMMIT_HASH}"
  echo " - ${IMAGE_NAME}:latest"
  echo " - ${IMAGE_NAME}:${VERSION_TAG}"
fi