# FaceFlow

A GPU-powered Ubuntu desktop you control from your browser, with **FaceFusion**
and **Chrome** preinstalled. Built on a **KasmVNC** desktop (the same
HTTP/WebSocket streaming RunPod's official desktop template uses), so the screen,
sound, keyboard and mouse stay responsive through RunPod's proxy. Runs on
**RunPod** or on your own **NVIDIA PC** from the same image.

## What you get

- Ubuntu + XFCE desktop in the browser (hardware-encoded video stream)
- FaceFusion with GPU (CUDA / onnxruntime-gpu) for face swap on photos and video
- Google Chrome
- Mic forwarding from your browser into the desktop
- A persistent `/workspace` for models, inputs and outputs

## Two variants (same repo, two image tags)

| Tag | Transport | Feel | Audio | Extra setup | Use when |
|-----|-----------|------|-------|-------------|----------|
| `:kasmvnc` | HTTP/WebSocket (KasmVNC) | Snappy on RunPod | OK | None | Default — always works |
| `:selkies` | WebRTC (Selkies) | Fastest + lowest latency | Best | Cloudflare TURN (free) | You want the smoothest desktop |

- KasmVNC is the same streaming RunPod's own desktop uses — reliable anywhere.
- Selkies/WebRTC needs an **external TURN server** on RunPod (no inbound UDP).
  Use **Cloudflare TURN** (free to 1,000 GB/mo) — setup in
  [`runpod/selkies-turn.md`](runpod/selkies-turn.md). Only `:selkies` forwards
  your mic and camera.

## Quick start

### On RunPod
See [`runpod/README.md`](runpod/README.md).

### On your own NVIDIA PC
Needs Docker + the NVIDIA Container Toolkit.

```bash
cp .env.example .env         # set FACEFLOW_PASSWORD
docker compose build
docker compose up
```

Open <https://localhost:6901> (accept the self-signed cert) and log in as
`kasm_user` with your password. Double-click the **FaceFusion** desktop icon.

## Repository layout

```
Dockerfile              # KasmVNC desktop + Chrome + FaceFusion
docker-compose.yml      # local testing on an NVIDIA PC
.env.example            # config template (copy to .env)
scripts/
  faceflow-init.sh      # first-run: sets up /workspace, desktop launchers
  install-facefusion.sh # (re)install FaceFusion GPU runtime
  run-facefusion.sh     # launch the FaceFusion web UI on port 7860
runpod/README.md        # RunPod template + deploy guide
```

## Known limits

| Want | Works here? |
|------|-------------|
| Cloud desktop + apps | Yes |
| FaceFusion on photos/videos (GPU) | Yes |
| Microphone into the desktop | Yes, with `:selkies` |
| Your webcam into the desktop / FaceFusion | Expected yes with `:selkies` — not yet tested on a live pod |

The `:selkies` image enables mic and webcam forwarding. The webcam uses Selkies'
rootless V4L2 Interposer, so it doesn't need the `v4l2loopback` kernel module
that containers can't load. If it doesn't work for an app, the fallback is a
Vast.ai VM instance — see [`vast/README.md`](vast/README.md).

## Before you build

- **Base image tag.** `BASE_TAG` is a [Kasm workspace core tag](https://hub.docker.com/r/kasmweb/core-ubuntu-jammy/tags).
  The default should work; bump it if you want a newer Kasm.
- GPU is not needed to build, only to run.

## Responsible use

FaceFusion is for consenting, lawful use only. Keep the built-in content filter
on. Only use faces you have permission to use. If you swap your face on a live
call, tell the other people. Impersonation can be illegal and can get your
accounts banned.
