#!/usr/bin/env sh

docker build \
    --pull \
    --no-cache \
    -t ${USER}-editor:`date +"%Y-%m-%d"` \
    .
