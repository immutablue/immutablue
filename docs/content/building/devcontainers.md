---
title: "Development Containers"
weight: 12
---

# Development Containers for Immutablue

This guide explains how to use the Development Container (DevContainer) setup for contributing to Immutablue.

## What are DevContainers?

Development Containers (DevContainers) provide a consistent, isolated development environment for contributors. Using DevContainers ensures that:

1. All contributors have the same dependencies and tools available
2. The development environment closely mirrors the build environment
3. No need to install development dependencies on your host system
4. Works consistently across different operating systems (Linux, macOS, Windows)

## Prerequisites

To use the DevContainer configuration, you'll need:

1. [Visual Studio Code](https://code.visualstudio.com/) or another IDE with DevContainer support
2. [Podman](https://podman.io/getting-started/installation) (preferred) or [Docker](https://www.docker.com/products/docker-desktop/)
3. The [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for VS Code

## Getting Started

### Option 1: Using Visual Studio Code

1. Clone the Immutablue repository:
   ```bash
   git clone https://gitlab.com/immutablue/immutablue.git
   cd immutablue
   ```

2. Open the project in VS Code:
   ```bash
   code .
   ```

3. VS Code will detect the DevContainer configuration and prompt you to "Reopen in Container". Click on this prompt, or:
   - Press F1 (or Ctrl+Shift+P) to open the command palette
   - Type "Dev Containers: Reopen in Container" and select it

4. VS Code will build the container and open the project inside it. This may take a few minutes the first time.

### Option 2: Using the Command Line Script

Immutablue provides a convenient command-line script for working with the development container without VS Code:

1. Clone the Immutablue repository:
   ```bash
   git clone https://gitlab.com/immutablue/immutablue.git
   cd immutablue
   ```

2. Make the script executable (if needed):
   ```bash
   chmod +x ./.devcontainer/devcontainer.sh
   ```

3. Build and start the container:
   ```bash
   ./.devcontainer/devcontainer.sh start
   ```

4. Enter the container shell:
   ```bash
   ./.devcontainer/devcontainer.sh exec
   ```

5. When finished, stop the container:
   ```bash
   ./.devcontainer/devcontainer.sh stop
   ```

The script provides additional commands:
- `build`: Build the container image
- `clean`: Remove the container and its image

### Working in the DevContainer

Once inside the DevContainer, you'll have access to:

- All required development tools like git, podman, buildah, etc.
- The Hugo server for documentation development
- A consistent bash environment with all dependencies

## DevContainer Features

The Immutablue DevContainer includes:

- Fedora 42 base image to match the target system
- Common development tools (git, make, etc.)
- Container tools (podman, buildah, skopeo) with nested container support
- Hugo for documentation development
- VS Code extensions for Hugo and Docker
- Preconfigured environment variables

### Nested Container Support

The devcontainer is configured with all necessary privileges and mounts to build and run containers inside the development container. This means you can:

- Build container images with `podman build` or `buildah bud`
- Run containers with `podman run`
- Push and pull images with `podman push/pull` or `skopeo`
- Test container builds locally before committing changes

This feature is essential for working on Immutablue's containerized components.

You can verify the container capabilities with these simple tests:

```bash
# Test podman
podman version

# Test building a simple container
echo 'FROM fedora:42' > /tmp/test.containerfile
echo 'RUN echo "Hello from nested container"' >> /tmp/test.containerfile
podman build -t test-image -f /tmp/test.containerfile

# Test running a container
podman run --rm test-image echo "Container running successfully"

# Clean up
podman rmi test-image
```

### Troubleshooting Container Building

If you encounter permission errors when building containers inside the devcontainer, such as:

```
WARN[0000] running newgidmap: exit status 1: newgidmap: write to gid_map failed: Operation not permitted
WARN[0000] /usr/bin/newgidmap should be setgid or have filecaps setgid
WARN[0000] Falling back to single mapping
WARN[0000] Error running newuidmap: exit status 1: newuidmap: write to uid_map failed: Operation not permitted
Error: mkdir /home/.local: permission denied
```

You can fix these issues by running the permission fix command:

```bash
# If using VS Code, open a terminal in the container and run:
sudo /workspaces/immutablue/.devcontainer/fix-permissions.sh

# If using the command line script:
./.devcontainer/devcontainer.sh fix
```

This script will:
1. Fix the permissions for the storage directories
2. Ensure the runtime directory exists and has proper permissions
3. Set the proper permissions for UID/GID mapping tools

## Building and Testing

Inside the DevContainer, you can:

### Build the Immutablue container

```bash
make build
```

### Run the tests

```bash
cd tests
./run_tests.sh
```

### Preview the documentation

```bash
cd docs
hugo server -D
```

The documentation will be available at http://localhost:1313/

## Customizing the DevContainer

If you need to customize the DevContainer for your specific needs:

1. Modify `.devcontainer/devcontainer.json` to add extensions or change settings
2. Modify `.devcontainer/Containerfile` to install additional packages or tools
3. Modify `.devcontainer/podman-compose.yml` if you need additional services or configuration
4. Restart the DevContainer using the VS Code command palette

## Troubleshooting

### Container Won't Build

If the container fails to build, try cleaning up:

```bash
# For Podman
podman system prune -a

# For Docker
docker system prune -a
```

Then rebuild the container through VS Code.

### Port Conflicts

If you encounter port conflicts (e.g., port 1313 for Hugo), modify the `forwardPorts` setting in `devcontainer.json`.

### User Account

The devcontainer runs with a user named `immutablue` that has sudo privileges. This is deliberately chosen to match the project name and provide a consistent identity for development work. The user is configured with UID 1000, which typically matches the first user on most Linux systems, ensuring proper file permissions between the host and container.

### File Permission Issues

If you encounter file permission issues between your host system and the container, you may need to modify the `USER_UID` and `USER_GID` in the Containerfile to match your host user's IDs. You can find your IDs with:

```bash
echo "UID: $(id -u), GID: $(id -g)"
```

## Advanced Usage

### Using Podman Compose Directly

For more advanced container orchestration, you can use the provided `podman-compose.yml` file directly:

1. Install podman-compose if you don't already have it:
   ```bash
   pip install podman-compose
   ```

2. Navigate to the `.devcontainer` directory:
   ```bash
   cd .devcontainer
   ```

3. Start the environment using podman-compose:
   ```bash
   podman-compose -f podman-compose.yml up -d
   ```

4. Enter the running container:
   ```bash
   podman exec -it immutablue-dev bash
   ```

5. Stop the environment when finished:
   ```bash
   podman-compose -f podman-compose.yml down
   ```

Alternatively, you can use the provided script which handles all these operations:

```bash
# From the project root
./.devcontainer/devcontainer.sh start  # Build and start
./.devcontainer/devcontainer.sh exec   # Enter the container
./.devcontainer/devcontainer.sh fix    # Fix permissions for container builds
./.devcontainer/devcontainer.sh stop   # Stop when done
```

## Best Practices

1. **Commit Often**: Make small, focused commits with clear messages
2. **Run Tests**: Always run tests before submitting changes
3. **Update Documentation**: If you change functionality, update the relevant documentation
4. **Use the Provided Tools**: Utilize the tools available in the DevContainer rather than installing alternatives