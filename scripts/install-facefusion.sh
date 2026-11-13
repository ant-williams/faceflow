#!/usr/bin/env bash
# Install or repair FaceFusion's GPU runtime. Safe to run more than once.
# Run this inside the pod if the build-time install was skipped or failed.
set -euo pipefail

export PIP_BREAK_SYSTEM_PACKAGES=1

FF_DIR=/opt/facefusion
VENV="$FF_DIR/venv"

if [ ! -d "$FF_DIR" ]; then
    echo "Cloning FaceFusion into $FF_DIR ..."
    git clone --depth 1 https://github.com/facefusion/facefusion.git "$FF_DIR"
fi

if [ ! -d "$VENV" ]; then
    python3 -m venv "$VENV"
fi

"$VENV/bin/pip" install --upgrade pip
echo "Installing onnxruntime-gpu + FaceFusion dependencies ..."
"$VENV/bin/python" "$FF_DIR/install.py" cuda@12 --skip-conda

echo
echo "FaceFusion ready. GPU check:"
"$VENV/bin/python" - <<'PY'
try:
    import onnxruntime as ort
    print("onnxruntime providers:", ort.get_available_providers())
except Exception as e:
    print("onnxruntime not importable yet:", e)
PY
echo "Done."
