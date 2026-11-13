#!/usr/bin/env bash
# FaceFlow workspace setup. Idempotent — safe to run on every start.
# Creates the persistent folders on the mounted volume (/workspace).
set -euo pipefail

WORKSPACE=${WORKSPACE:-/workspace}
FF_DATA="$WORKSPACE/facefusion"

# RunPod mounts /workspace as root. If we can't write to it, take ownership
# (via sudo if we're not root). Harmless if already owned by us.
if [ ! -w "$WORKSPACE" ]; then
    if [ "$(id -u)" = "0" ]; then
        chown -R "$(id -u)":"$(id -g)" "$WORKSPACE" 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u)":"$(id -g)" "$WORKSPACE" 2>/dev/null || true
    fi
fi

mkdir -p \
    "$FF_DATA/models" \
    "$FF_DATA/jobs" \
    "$WORKSPACE/input" \
    "$WORKSPACE/output" \
    "$WORKSPACE/downloads"

# Keep FaceFusion's downloaded models on the volume so they survive restarts.
if [ -d /opt/facefusion ] && [ ! -e /opt/facefusion/.assets ]; then
    ln -sfn "$FF_DATA/models" /opt/facefusion/.assets 2>/dev/null || true
fi

echo "FaceFlow workspace ready: $WORKSPACE"
