#!/bin/bash
# Track this service by PID and executable, never by a shared process name.
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
root=$PWD
pidfile="$root/server.pid"
binary=$(readlink -f "$root/runtime/audiocpp_server")
case "${1:-status}" in
    start)
        [ "$(id -u)" -eq 0 ] || { echo 'Start the service through DwemerDistro as root.' >&2; exit 1; }
        [ -x "$binary" ] && [ -f server.json ] || { echo 'Higgs is not installed.' >&2; exit 1; }
        exec 8<.install.lock
        flock -n 8 || { echo 'Higgs installation is running; start it after installation finishes.' >&2; exit 1; }
        exec 9>service.lock
        flock -n 9 || { echo 'Another service operation is running.' >&2; exit 1; }
        start-stop-daemon --start --quiet --oknodo --background --make-pidfile \
            --pidfile "$pidfile" --exec "$binary" --chuid dwemer --chdir "$root" \
            --output "$root/server.log" --startas "$root/start.sh" 8>&- 9>&-
        for attempt in {1..15}; do
            if "$root/service.sh" status >/dev/null 2>&1; then exit 0; fi
            sleep 1
        done
        echo 'Higgs did not start. Inspect server.log for port or runtime errors.' >&2
        exit 1
        ;;
    stop)
        [ "$(id -u)" -eq 0 ] || { echo 'Stop the service through DwemerDistro as root.' >&2; exit 1; }
        exec 9>service.lock
        flock -n 9 || { echo 'Another service operation is running.' >&2; exit 1; }
        start-stop-daemon --stop --quiet --oknodo --remove-pidfile --retry TERM/20/KILL/5 \
            --pidfile "$pidfile" --exec "$binary"
        ;;
    enable) touch .enabled ;;
    disable) rm -f -- .enabled; "$root/service.sh" stop ;;
    status)
        start-stop-daemon --status --pidfile "$pidfile" --exec "$binary" >/dev/null
        python3 - <<'PY'
import json, urllib.request
config = json.load(open('server.json'))
host = config['host']
if host in ('0.0.0.0', '::'):
    host = '127.0.0.1'
base = f"http://{host}:{int(config['port'])}"
with urllib.request.urlopen(base + '/health', timeout=3) as response:
    health = json.load(response)
with urllib.request.urlopen(base + '/v1/models', timeout=3) as response:
    models = json.load(response)['data']
assert health.get('status') == 'ok'
assert any(m.get('id') == 'higgs-v3' and m.get('family') == 'higgs_audio_tts' for m in models)
print(json.dumps({'status': 'ok', 'provider': 'higgs', 'endpoint': base}))
PY
        ;;
    *) echo 'Usage: service.sh start|stop|enable|disable|status' >&2; exit 2 ;;
esac
