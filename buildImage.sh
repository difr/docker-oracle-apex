#!/bin/bash


IMAGE_NAME="difr/oracle-apex:1.1"

echo "Building Image '$IMAGE_NAME'..."
echo ""

BUILD_START=$(date '+%s')
DOCKER_BUILDKIT=1 docker build --force-rm=true --no-cache=true -t $IMAGE_NAME -f Dockerfile . || {
  echo ""
  echo "[ERROR]: Docker Image '$IMAGE_NAME' was NOT successfully created."
  echo "Check the output and correct any reported problems with the docker build operation."
  exit 1
}
BUILD_END=$(date '+%s')
BUILD_ELAPSED=`expr $BUILD_END - $BUILD_START`

echo ""
echo "Removing all unused build cache..."
docker builder prune -af
echo "Removing dangling images..."
docker image prune -f
echo "Docker disk usage:"
docker system df

echo ""
echo "Image '$IMAGE_NAME' was successfully created."
echo "Build completed in $BUILD_ELAPSED seconds."
