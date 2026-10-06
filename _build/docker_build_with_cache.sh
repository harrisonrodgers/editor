#!/usr/bin/env sh

docker build \
    --pull \
    -t ${USER}-editor:`date +"%Y-%m-%d"` \
    .
