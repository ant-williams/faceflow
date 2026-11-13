# FaceFlow Selkies (WebRTC) on RunPod with Cloudflare TURN

This is the **fast** variant: low latency + audio, using the `:selkies` image.
Because RunPod doesn't give inbound UDP, WebRTC needs an **external TURN server**.
We use **Cloudflare TURN** — free up to 1,000 GB/month, no VPS.

> If you just want something that always works with no extra setup, use the
> `:kasmvnc` image instead (see `runpod/README.md`). Come here for the fast one.

---

## Step 1 — Create a Cloudflare TURN key

1. Sign up / log in at <https://dash.cloudflare.com>.
2. Left sidebar → **Realtime** (may be shown as "Calls").
3. Open **TURN** → **Create** a TURN App/Key.
4. Copy the two values it gives you:
   - **Turn Token ID** (a key id)
   - **API Token** (a secret)

## Step 2 — Generate TURN credentials

TURN credentials are time-limited. Generate a set (valid up to 24h here) by
running this in any terminal — replace the two placeholders:

```bash
curl -sS -X POST \
  "https://rtc.live.cloudflare.com/v1/turn/keys/TURN_TOKEN_ID/credentials/generate-ice-servers" \
  -H "Authorization: Bearer API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ttl": 86400}'
```

The response looks like:

```json
{
  "iceServers": {
    "urls": [
      "stun:stun.cloudflare.com:3478",
      "turn:turn.cloudflare.com:3478?transport=udp",
      "turn:turn.cloudflare.com:3478?transport=tcp",
      "turns:turn.cloudflare.com:5349?transport=tcp"
    ],
    "username": "GENERATED_USERNAME",
    "credential": "GENERATED_CREDENTIAL"
  }
}
```

Keep the **username** and **credential** — they go into RunPod next. Re-run this
command to get fresh ones when they expire (e.g. daily / per session).

## Step 3 — RunPod template (Selkies image)

Templates → New Template:

| Field | Value |
|-------|-------|
| Container Image | `docker.io/<your-username>/faceflow:selkies` |
| Registry Credentials | your Docker Hub credential |
| Container Disk | 20 GB |
| Volume Disk | 20 GB |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `8080,7860` |

**Environment variables:**

| Name | Value |
|------|-------|
| `SELKIES_ENABLE_BASIC_AUTH` | `true` |
| `SELKIES_BASIC_AUTH_USER` | a username |
| `SELKIES_BASIC_AUTH_PASSWORD` | a strong password |
| `SELKIES_TURN_HOST` | `turn.cloudflare.com` |
| `SELKIES_TURN_PORT` | `3478` |
| `SELKIES_TURN_PROTOCOL` | `udp` |
| `SELKIES_TURN_USERNAME` | the **username** from Step 2 |
| `SELKIES_TURN_PASSWORD` | the **credential** from Step 2 |
| `SELKIES_STUN_HOST` | `stun.cloudflare.com` |
| `SELKIES_STUN_PORT` | `3478` |

> Env var names can differ between Selkies versions. If the stream still won't
> connect, check the base image's docs for the exact TURN variable names
> (some builds use `TURN_HOST` without the `SELKIES_` prefix) and adjust.

## Step 4 — Deploy and connect

1. Deploy on a GPU (A40 or RTX 4090 are good value). Any datacenter is fine —
   TURN is external, so you do **not** need RunPod's UDP port support.
2. **Connect → HTTP Service → port 8080**, log in.
3. You should get a responsive desktop **with audio**. Double-click **FaceFusion**
   or run `/opt/faceflow/scripts/run-facefusion.sh`.

## Troubleshooting

- **"Waiting for stream" / `Peer connection failed`:** TURN creds wrong/expired,
  or the env var names don't match this Selkies version. Regenerate creds
  (Step 2) and double-check the variable names.
- **Connects but no audio:** confirm the browser allowed audio; check the Selkies
  sidebar audio toggle.
- **Webcam into apps:** not available on RunPod (kernel-module limit) regardless
  of TURN. Use a Vast.ai VM for that.
- **Bandwidth:** Cloudflare TURN is free to 1,000 GB/mo (~150–500 hours). Beyond
  that it's $0.05/GB.
