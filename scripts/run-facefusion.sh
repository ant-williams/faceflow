#!/usr/bin/env bash
# Launch the FaceFusion web UI on port 7860 with GPU execution.
# Use this for headless file/video work (no desktop needed), or from the
# desktop launcher. Content filter is left ON (FaceFusion default) on purpose.
set -euo pipefail

FF_DIR=/opt/facefusion
VENV="$FF_DIR/venv"

# Ensure the persistent workspace folders exist.
/opt/faceflow/scripts/faceflow-init.sh || true

if [ ! -x "$VENV/bin/python" ]; then
    echo "FaceFusion venv missing — running installer first..."
    /opt/faceflow/scripts/install-facefusion.sh
fi

cd "$FF_DIR"
echo "Open the FaceFusion UI via the pod's port 7860 (RunPod: Connect -> HTTP 7860)."
exec "$VENV/bin/python" facefusion.py run \
    --execution-providers cuda \
    --ui-layouts default
