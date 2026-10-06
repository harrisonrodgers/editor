#!/usr/bin/env sh

container build \
    --cpus 8 \
    --memory 16g \
    --pull \
    --no-cache \
    -t ${USER}-editor:`date +"%Y-%m-%d"` \
    .

echo "Running: 'container image ls'"
container image ls

echo "Killing builder (no need to keep, not desiring cache)."
container builder delete --force

echo "Running: 'container ls -a'"
container ls -a

#   --progress plain \
