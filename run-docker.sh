#!/usr/bin/env bash

NAME=${USER}-editor
VERSION=$(date +"%Y-%m-%d")

# Attach to the tmux session "0", creating it if it doesn't exist.
# Uses exec rather than attach so bracketed paste works (no more :set paste).
attach() {
    exec docker exec -it "$NAME" tmux new-session -A -s 0
}

# Already running? Just attach (exec never returns, so nothing below runs).
if [ "$(docker container inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = "true" ]; then
    echo "Attaching to existing instance."
    attach
fi

echo "Creating new instance, no existing instance running."

docker run \
    --rm \
    -it \
    -d \
    --name "$NAME" \
    --env-file env \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --security-opt apparmor=unconfined \
    --security-opt systempaths=unconfined \
    -v "${PWD}":/host \
    --workdir "/sandbox/${USER}/" \
    "${NAME}:${VERSION}" \
    bash -lc '
        set -e

        git config --global user.name "Harrison Rodgers"
        git config --global user.email "hrod1137@uni.sydney.edu.au"

        # Install each time spawning a new container to get the latest possible version
        nix profile add nixpkgs#claude-code --refresh --impure

        exec sleep infinity
    ' >/dev/null

attach
