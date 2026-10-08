#!/usr/bin/env bash

NAME=${USER}-editor
VERSION=`date +"%Y-%m-%d"`

# Attach to the tmux session "0", creating it if it doesn't exist.
# Uses exec rather than attach so bracketed paste works (no more :set paste).
attach() {
    exec container exec -it "$NAME" tmux new-session -A -s 0
}

# Already running? Just attach (exec never returns, so nothing below runs).
if container ls --quiet 2>/dev/null | grep -qx -- "$NAME"; then
    echo "Attaching to existing instance."
    attach
fi

echo "Creating new instance, no existing instance running."

container run \
    --rm \
    -it \
    -d \
    --name "$NAME" \
    --env-file env \
    --cap-add CAP_SYS_PTRACE \
    -v $PWD:/host \
    ${NAME}:${VERSION} \
    bash -lc '
        set -e

        git config --global user.name "Harrison Rodgers"
        git config --global user.email "hrod1137@uni.sydney.edu.au"

        # Install each time spawning a new container to get the latest possible version
        nix profile add nixpkgs#claude-code --refresh --impure

        exec sleep infinity
    ' > /dev/null

attach
