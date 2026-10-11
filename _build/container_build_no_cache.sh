#!/usr/bin/env sh

# container build does not support a Dockerfile over 16,000 bytes
bytes=$(wc -c < Dockerfile)
if [ "$bytes" -gt 16000 ]; then
    echo "ERROR: Dockerfile is ${bytes} bytes, over the 16,000 byte limit of container build. Aborting." >&2
    exit 1
fi

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
