# FaceFlow

A GPU desktop in your browser on RunPod (Selkies desktop 2.2.1, Ubuntu 26.04)
with FaceFusion, Chrome and Firefox.
Streams over WebRTC (Selkies) through a Cloudflare TURN relay and forwards your
microphone and webcam.

## Files

| File | What it is |
|------|-----------|
| `Dockerfile` | The image: Selkies desktop + FaceFusion |
| `start-facefusion.sh` | Starts FaceFusion on port 7860 (`start-facefusion` in the desktop terminal) |
| `.github/workflows/build.yml` | Builds the image and pushes it to Docker Hub — **manual only** |

## 1. Build the image

1. Repo secrets (Settings → Secrets and variables → Actions):
   `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (Read/Write).
2. **Actions → Build FaceFlow image → Run workflow.**
3. Result: `docker.io/<your-username>/faceflow:latest`.

Nothing builds unless you run it.

## 2. Get a Cloudflare TURN key

RunPod has no inbound UDP, so WebRTC needs a TURN relay. Cloudflare's is free
up to 1,000 GB/month, and Selkies generates the credentials from your key by
itself — nothing to renew.

dash.cloudflare.com → **Realtime → TURN** → create a key. Copy the **Key ID**
(not your account ID) and the **API Token** (shown only once).

## 3. RunPod template

| Field | Value |
|-------|-------|
| Container image | `docker.io/<your-username>/faceflow:latest` |
| Registry credentials | your Docker Hub login (read-only token is enough) |
| Container disk | 20 GB |
| Volume | 20 GB at `/workspace` (keeps FaceFusion's models) |
| HTTP ports | `8080` (desktop), `7860` (FaceFusion) |

Environment variables:

| Name | Value |
|------|-------|
| `SELKIES_ENABLE_BASIC_AUTH` | `true` |
| `SELKIES_BASIC_AUTH_USER` | your login name |
| `SELKIES_BASIC_AUTH_PASSWORD` | your login password |
| `SELKIES_ENABLE_CLOUDFLARE_TURN` | `true` |
| `SELKIES_CLOUDFLARE_TURN_TOKEN_ID` | Key ID from step 2 |
| `SELKIES_CLOUDFLARE_TURN_API_TOKEN` | API Token from step 2 |

Remove any old `SELKIES_TURN_HOST/PORT/PROTOCOL/USERNAME/PASSWORD` variables.

Pick a GPU with a video encoder: RTX A6000, RTX 4090, L40S. Avoid A100/H100/B200
and MIG slices.

## 4. Use it

1. **Connect → HTTP 8080**, log in with your basic-auth user/password.
2. Allow the browser's microphone and camera prompts.
3. In the desktop terminal run `start-facefusion`, then open **Connect → HTTP 7860**.
4. **Stop the pod** when done — it bills by the hour.

## Troubleshooting

- **Port 8080 "not ready" or "waiting for service to respond":** Selkies must
  listen on all interfaces over plain HTTP (RunPod's proxy adds HTTPS). The image
  sets `SELKIES_PUBLIC=true` and `SELKIES_ENABLE_HTTPS=false`; on an older image,
  add both env vars to the pod.

- **"Waiting for stream" / `Peer connection failed`:** the browser log line
  `using TURN servers:` must show `turn.cloudflare.com`. If it shows the pod's
  own IP, the Cloudflare key isn't being used — check the Key ID (a 32-character
  ID that fails is often your account ID) and API Token. Fallback: generate
  credentials yourself (valid 24 h) and set `SELKIES_TURN_HOST=turn.cloudflare.com`,
  `SELKIES_TURN_PORT=3478`, `SELKIES_TURN_PROTOCOL=udp`, `SELKIES_TURN_USERNAME`,
  `SELKIES_TURN_PASSWORD` instead of the three Cloudflare variables:
  ```powershell
  Invoke-RestMethod -Method Post `
    -Uri "https://rtc.live.cloudflare.com/v1/turn/keys/KEY_ID/credentials/generate-ice-servers" `
    -Headers @{ Authorization = "Bearer API_TOKEN" } `
    -ContentType "application/json" -Body '{"ttl": 86400}' | ConvertTo-Json -Depth 5
  ```
- **No mic/camera prompt:** check the running Selkies has the settings:
  ```bash
  for p in $(pgrep -f selkies); do tr '\0' '\n' < /proc/$p/environ | grep -iE 'MICRO|WEBCAM'; done
  ```
  No output means the pod runs an old image — rebuild and redeploy.
- **An app can't see the camera:** Selkies provides the camera through an
  `LD_PRELOAD` interposer. `start-facefusion` loads it for FaceFusion. Test it:
  ```bash
  LD_PRELOAD=/usr/lib/selkies_v4l2_interposer.so /opt/facefusion/venv/bin/python -c "import cv2; c=cv2.VideoCapture(0); print('opened:', c.isOpened(), 'frame:', c.read()[0])"
  ```
- **Holding a key doesn't repeat:** key auto-repeat is turned off on purpose so
  stream delay can't type runs of characters. Turn it back on with `xset r on`.

## Responsible use

Only use faces you have permission to use, keep FaceFusion's content filter on,
and tell people on a call if your face is swapped.
