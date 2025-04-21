#!/bin/bash

# Script to work with Immutablue devcontainer from the command line
# Usage: ./.devcontainer/devcontainer.sh [build|start|exec|stop|clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVCONTAINER_DIR="$SCRIPT_DIR"
CONTAINER_NAME="immutablue-dev"

build() {
    echo "Building devcontainer..."
    podman build -f "$DEVCONTAINER_DIR/Containerfile" -t $CONTAINER_NAME $DEVCONTAINER_DIR
}

start() {
    echo "Starting devcontainer..."
    if [ "$(podman ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "Container is already running"
    else
        if [ "$(podman ps -aq -f name=$CONTAINER_NAME)" ]; then
            podman start $CONTAINER_NAME
        else
            podman run -it -d \
                --name $CONTAINER_NAME \
                --userns=keep-id \
                --privileged \
                --security-opt=seccomp=unconfined \
                --security-opt=label=disable \
                --cap-add=SYS_ADMIN \
                --cap-add=NET_ADMIN \
                -v "$PROJECT_ROOT:/workspaces/immutablue:cached" \
                -v "/run/user/1000/podman/podman.sock:/run/podman/podman.sock" \
                -v "${XDG_RUNTIME_DIR:-/tmp}/containers:${XDG_RUNTIME_DIR:-/tmp}/containers" \
                -p 1313:1313 \
                -e IMMUTABLUE_DEVELOPMENT=true \
                -e BUILDAH_ISOLATION=chroot \
                -e STORAGE_DRIVER=overlay2 \
                -e _BUILDAH_STARTED_IN_USERNS="" \
                $CONTAINER_NAME \
                sleep infinity
            fix_permissions
        fi
    fi
}

exec_container() {
    echo "Executing command in devcontainer..."
    if [ $# -eq 0 ]; then
        podman exec -it $CONTAINER_NAME bash
    else
        podman exec -it $CONTAINER_NAME "$@"
    fi
}

fix_permissions() {
    echo "Fixing container permissions..."
    podman exec --user root -it $CONTAINER_NAME /workspaces/immutablue/.devcontainer/fix-permissions.sh
}

stop() {
    echo "Stopping devcontainer..."
    if [ "$(podman ps -q -f name=$CONTAINER_NAME)" ]; then
        podman stop $CONTAINER_NAME
    else
        echo "Container is not running"
    fi
}

clean() {
    echo "Cleaning up devcontainer..."
    stop
    if [ "$(podman ps -aq -f name=$CONTAINER_NAME)" ]; then
        podman rm $CONTAINER_NAME
    fi
    if [ "$(podman images -q $CONTAINER_NAME)" ]; then
        podman rmi $CONTAINER_NAME
    fi
}

case "$1" in
    build)
        build
        ;;
    start)
        build
        start
        ;;
    exec)
        shift
        exec_container "$@"
        ;;
    fix)
        fix_permissions
        ;;
    stop)
        stop
        ;;
    clean)
        clean
        ;;
    *)
        echo "Usage: $0 [build|start|exec|fix|stop|clean]"
        echo "  build: Build the devcontainer image"
        echo "  start: Build and start the devcontainer"
        echo "  exec [command]: Execute a command in the devcontainer (default: bash)"
        echo "  fix: Fix container permissions for building nested containers"
        echo "  stop: Stop the devcontainer"
        echo "  clean: Stop and remove the devcontainer"
        exit 1
        ;;
esac
