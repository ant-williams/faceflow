#!/usr/bin/python3
# Runs in place of Selkies' launcher on every pod start. It:
# 1. allows this pod's RunPod web address (https://<pod-id>-8080.proxy.runpod.net)
#    to open Selkies' streaming connection — Selkies only accepts its own address
#    by default. A SELKIES_ALLOWED_ORIGINS set on the pod still takes priority.
# 2. fetches Cloudflare TURN credentials from Cloudflare's current API and gives
#    them to Selkies through its RTC config file, renewing them every 12 hours.
#    Selkies 2.2's built-in Cloudflare support calls an older API endpoint and
#    silently falls back to an unreachable built-in relay when that fails.
# 3. starts FaceFusion in the background (log: ~/facefusion.log) so port 7860 is
#    ready without opening a terminal, unless it's already running.
# Then it hands over to the real Selkies.
import json
import os
import subprocess
import sys
import time
import urllib.request

TURN_API = os.environ.get("FACEFLOW_TURN_API", "https://rtc.live.cloudflare.com/v1/turn/keys")
TURN_TTL = 86400
TURN_REFRESH_SECONDS = 12 * 3600
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def log(message):
    print(f"faceflow: {message}", file=sys.stderr, flush=True)


def process_running(pid_file, marker):
    # Alive (not a zombie) and really the expected program, not a reused process ID.
    try:
        with open(pid_file) as f:
            pid = int(f.read().strip())
        with open(f"/proc/{pid}/stat") as f:
            state = f.read().rsplit(")", 1)[1].split()[0]
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read()
        return state != "Z" and marker in cmdline
    except (OSError, ValueError, IndexError):
        return False


def start_background(pid_file, marker, command, log_path):
    if process_running(pid_file, marker):
        return
    with open(log_path, "ab") as log_file:
        proc = subprocess.Popen(command, stdout=log_file, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True)
    with open(pid_file, "w") as f:
        f.write(str(proc.pid))


def write_turn_config(key_id, api_token, path):
    request = urllib.request.Request(
        f"{TURN_API}/{key_id}/credentials/generate-ice-servers",
        data=json.dumps({"ttl": TURN_TTL}).encode(),
        headers={"Authorization": f"Bearer {api_token}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(request, timeout=15) as response:
        config = json.loads(response.read())
    if not config.get("iceServers"):
        raise ValueError("Cloudflare reply has no iceServers")
    # Selkies only trusts the file if it is ours, not a symlink, and not
    # writable by others; replace it atomically so it never reads half a file.
    temp_path = f"{path}.faceflow-tmp"
    fd = os.open(temp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(config, f)
    os.replace(temp_path, path)


def refresh_turn_forever(key_id, api_token, path):
    while True:
        time.sleep(TURN_REFRESH_SECONDS)
        try:
            write_turn_config(key_id, api_token, path)
            log("renewed Cloudflare TURN credentials")
        except Exception as error:
            log(f"could not renew Cloudflare TURN credentials: {error}")


if len(sys.argv) > 1 and sys.argv[1] == "--refresh-turn":
    refresh_turn_forever(os.environ["SELKIES_CLOUDFLARE_TURN_TOKEN_ID"],
                         os.environ["SELKIES_CLOUDFLARE_TURN_API_TOKEN"],
                         sys.argv[2])
    sys.exit(0)

# 1. Allow this pod's RunPod address.
pod_id = os.environ.get("RUNPOD_POD_ID")
if pod_id and not os.environ.get("SELKIES_ALLOWED_ORIGINS"):
    os.environ["SELKIES_ALLOWED_ORIGINS"] = f"https://{pod_id}-8080.proxy.runpod.net"

# 2. Cloudflare TURN through the RTC config file.
key_id = os.environ.get("SELKIES_CLOUDFLARE_TURN_TOKEN_ID")
api_token = os.environ.get("SELKIES_CLOUDFLARE_TURN_API_TOKEN")
if key_id and api_token:
    rtc_path = os.environ.setdefault("SELKIES_RTC_CONFIG_JSON", "/tmp/rtc.json")
    try:
        write_turn_config(key_id, api_token, rtc_path)
        os.environ["SELKIES_ENABLE_CLOUDFLARE_TURN"] = "false"  # skip Selkies' own outdated fetch
        log(f"Cloudflare TURN credentials written to {rtc_path}")
        start_background(os.path.join(RUNTIME_DIR, "faceflow-turn.pid"), b"--refresh-turn",
                         [sys.executable, os.path.abspath(__file__), "--refresh-turn", rtc_path],
                         os.path.expanduser("~/faceflow-turn.log"))
    except Exception as error:
        log(f"could not fetch Cloudflare TURN credentials ({error}); leaving it to Selkies")

# 3. FaceFusion in the background.
try:
    start_background(os.path.join(RUNTIME_DIR, "facefusion.pid"), b"facefusion",
                     ["/usr/local/bin/start-facefusion"], os.path.expanduser("~/facefusion.log"))
except Exception as error:  # never let FaceFusion problems stop the desktop
    log(f"could not start FaceFusion: {error}")

os.execv(sys.executable, [sys.executable, "/usr/local/bin/selkies-real", *sys.argv[1:]])
