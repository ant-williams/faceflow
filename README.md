# FaceFlow

A GPU Ubuntu desktop in your browser on RunPod, with FaceFusion and Chrome.
Streams over WebRTC (Selkies) and forwards your microphone and webcam.

## Files

| File | What it is |
|------|-----------|
| `Dockerfile` | The image: Selkies desktop + Chrome + FaceFusion |
| `start-facefusion.sh` | Starts FaceFusion on port 7860 (`start-facefusion` in the desktop terminal) |
| `.github/workflows/build.yml` | Builds the image and pushes it to Docker Hub — **manual only** |

## 1. Build the image

1. Repo secrets (Settings → Secrets and variables → Actions):
   `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (Read/Write).
2. **Actions → Build FaceFlow image → Run workflow.**
3. Result: `docker.io/<your-username>/faceflow:selkies`.

Nothing builds unless you run it.

## 2. Get Cloudflare TURN credentials

RunPod has no inbound UDP, so WebRTC needs a TURN relay. Cloudflare's is free
up to 1,000 GB/month.

1. dash.cloudflare.com → **Realtime → TURN** → create a key. Copy the
   **Key ID** (not your account ID) and the **API Token**.
2. Generate credentials (valid 24 h), in Windows PowerShell:

   ```powershell
   Invoke-RestMethod -Method Post `
     -Uri "https://rtc.live.cloudflare.com/v1/turn/keys/KEY_ID/credentials/generate-ice-servers" `
     -Headers @{ Authorization = "Bearer API_TOKEN" } `
     -ContentType "application/json" -Body '{"ttl": 86400}' | ConvertTo-Json -Depth 5
   ```

3. Keep the `username` and `credential` from the output.

## 3. RunPod template

| Field | Value |
|-------|-------|
| Container image | `docker.io/<your-username>/faceflow:selkies` |
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
| `SELKIES_TURN_HOST` | `turn.cloudflare.com` |
| `SELKIES_TURN_PORT` | `3478` |
| `SELKIES_TURN_PROTOCOL` | `udp` |
| `SELKIES_TURN_USERNAME` | `username` from step 2 |
| `SELKIES_TURN_PASSWORD` | `credential` from step 2 |

Pick a GPU with a video encoder: RTX A6000, RTX 4090, L40S. Avoid A100/H100/B200
and MIG slices.

## 4. Use it

1. **Connect → HTTP 8080**, log in with your basic-auth user/password.
2. Allow the browser's microphone and camera prompts.
3. In the desktop terminal run `start-facefusion`, then open **Connect → HTTP 7860**.
4. **Stop the pod** when done — it bills by the hour.

## Troubleshooting

- **"Waiting for stream" / `Peer connection failed`:** TURN credentials expired
  (they last 24 h) or are wrong. Generate new ones and update the env vars.
- **No mic/camera prompt:** check the running Selkies has the settings:
  ```bash
  for p in $(pgrep -f selkies); do tr '\0' '\n' < /proc/$p/environ | grep -iE 'MICRO|WEBCAM'; done
  ```
  No output means the pod runs an old image — rebuild and redeploy.
- **An app can't see the camera:** Selkies provides the camera through an
  `LD_PRELOAD` interposer, so it only reaches apps started with it loaded.
  Check `echo "$LD_PRELOAD"` in the terminal you launch FaceFusion from.

## Responsible use

Only use faces you have permission to use, keep FaceFusion's content filter on,
and tell people on a call if your face is swapped.
