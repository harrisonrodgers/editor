#!/usr/bin/env sh

docker build \
    --pull \
    --no-cache \
    -t editor:`date +"%Y-%m-%d"` \
    .
