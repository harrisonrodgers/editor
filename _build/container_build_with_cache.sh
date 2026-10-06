#!/usr/bin/env sh

container build \
    --cpus 8 \
    --memory 16g \
    --pull \
    -t ${USER}-editor:`date +"%Y-%m-%d"` \
    .

echo "Running: 'container image ls'"
container image ls

echo "Running: 'container ls -a'"
container ls -a

#   --progress plain \
