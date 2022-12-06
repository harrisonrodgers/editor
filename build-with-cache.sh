#!/usr/bin/env sh

docker build \
    --pull \
    -t editor:`date +"%Y-%m-%d"` \
    .
