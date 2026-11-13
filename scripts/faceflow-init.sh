#!/usr/bin/env bash
# FaceFlow first-run setup. The Selkies base image runs user autostart scripts
# on login; this prepares the persistent workspace and desktop launchers.
# It must be idempotent — it runs on every desktop login.
set -euo pipefail

WORKSPACE=${WORKSPACE:-/workspace}
FF_DATA="$WORKSPACE/facefusion"

# Persistent folders on the mounted volume (survive pod restarts).
mkdir -p \
    "$FF_DATA/models" \
    "$FF_DATA/jobs" \
    "$WORKSPACE/input" \
    "$WORKSPACE/output" \
    "$WORKSPACE/downloads"

# Point FaceFusion's data at the volume via a symlink if not already there.
if [ -d /opt/facefusion ] && [ ! -e /opt/facefusion/.assets ]; then
    ln -sfn "$FF_DATA/models" /opt/facefusion/.assets 2>/dev/null || true
fi

# Desktop launcher: FaceFusion web UI.
DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/FaceFusion.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=FaceFusion
Comment=Start the FaceFusion web UI
Exec=/opt/faceflow/scripts/run-facefusion.sh
Icon=applications-graphics
Terminal=true
EOF
chmod +x "$DESKTOP_DIR/FaceFusion.desktop" 2>/dev/null || true

echo "FaceFlow init complete. Workspace: $WORKSPACE"
