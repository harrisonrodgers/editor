#!/usr/bin/env sh

container build \
    --cpus 8 \
    --memory 16g \
    --pull \
    -t ${USER}-editor:`date +"%Y-%m-%d"` \
    .

#   --progress plain \
