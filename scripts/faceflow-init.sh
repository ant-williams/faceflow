#!/usr/bin/env bash
# FaceFlow workspace setup. Idempotent — safe to run on every start.
# Creates the persistent folders on the mounted volume (/workspace).
set -euo pipefail

# Choose a writable workspace. Prefer /workspace (a mounted volume) when it
# exists and is writable; otherwise fall back to the user's home, since this
# image can run unprivileged (no real root to create/chown /workspace).
if [ -n "${WORKSPACE:-}" ]; then
    :
elif [ -d /workspace ] && [ -w /workspace ]; then
    WORKSPACE=/workspace
elif [ -d /workspace ] && [ "$(id -u)" = "0" ]; then
    chown -R "$(id -u)":"$(id -g)" /workspace 2>/dev/null || true
    WORKSPACE=/workspace
else
    WORKSPACE="$HOME/faceflow-data"
fi
FF_DATA="$WORKSPACE/facefusion"

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
