#!/usr/bin/env bash
# run-with-host-display.sh
# Usage: ./run-with-host-display.sh [HOST_IP] [path/to/executable]
# If HOST_IP is omitted we read the Docker/WSL host from /etc/resolv.conf.
# Default executable: ./build/appDBC_Parser

set -euo pipefail

HOST_IP=${1:-$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)}
EXE=${2:-./build/appDBC_Parser}
DISPLAY_NUM=${DISPLAY_NUM:-0}   # change to 1 for :1 etc
PORT=$((6000 + DISPLAY_NUM))

if [ -z "$HOST_IP" ]; then
  echo "ERROR: Could not determine host IP. Provide it as the first argument."
  exit 2
fi

export DISPLAY="${HOST_IP}:${DISPLAY_NUM}.0"
#!/usr/bin/env bash
# run-with-host-display.sh
# Usage: ./run-with-host-display.sh [HOST_IP] [path/to/executable]
# If HOST_IP is omitted the script will pick a sensible default depending on
# environment:
#  - If host.docker.internal resolves, use it (works on Docker Desktop for Mac/Windows)
#  - If running under WSL2, use the nameserver from /etc/resolv.conf
#  - Otherwise (native Linux host) the script will prefer localhost and will
#    require the container be started with --network host (or the X server be
#    reachable from the container).

set -euo pipefail

EXE_DEFAULT=./build/appDBC_Parser
HOST_ARG=${1:-}
EXE=${2:-$EXE_DEFAULT}
DISPLAY_NUM=${DISPLAY_NUM:-0}
PORT=$((6000 + DISPLAY_NUM))

# helper: resolve host.docker.internal if available
resolve_host_docker_internal() {
  if command -v getent >/dev/null 2>&1; then
    getent hosts host.docker.internal 2>/dev/null | awk '{print $1; exit}' || true
  else
    # fallback to ping + nslookup resolution
    if ping -c1 -W1 host.docker.internal >/dev/null 2>&1; then
      if command -v nslookup >/dev/null 2>&1; then
        nslookup host.docker.internal 2>/dev/null | awk '/^Address: /{print $2; exit}' || true
      else
        true
      fi
    else
      true
    fi
  fi
}

# Determine HOST_IP
if [ -n "$HOST_ARG" ]; then
  HOST_IP=$HOST_ARG
else
  # 1) try host.docker.internal (works on Docker Desktop for Mac/Windows)
  HOST_IP=$(resolve_host_docker_internal || true)

  if [ -z "$HOST_IP" ]; then
    # 2) if running under WSL (nameserver technique)
    if grep -qi "microsoft" /proc/version 2>/dev/null || grep -qi "wsl" /proc/version 2>/dev/null; then
      HOST_IP=$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)
    fi
  fi
fi

# If still empty, assume native Linux host: prefer localhost if container was
# started with --network host. Check whether 127.0.0.1:6000 is reachable.
if [ -z "$HOST_IP" ]; then
  HOST_IP=127.0.0.1
  if timeout 1 bash -c "</dev/tcp/${HOST_IP}/${PORT}" 2>/dev/null; then
    echo "Using localhost as host (container appears to have host networking or X server on localhost)."
  else
    cat <<'MSG'
ERROR: Could not determine a host IP to reach the X server.
On Mac/Windows Docker Desktop the name "host.docker.internal" is usually available.
On WSL2 we use the nameserver entry from /etc/resolv.conf.
On native Linux you should start the container with --network host (so localhost in
the container maps to the host), or provide the host IP as the first argument.

Example (restart container with host networking):
  docker run --rm -it --network host -v "$PWD":/workdir -w /workdir your-image /workdir/run-with-host-display.sh

Or provide the host IP directly:
  ./run-with-host-display.sh 192.168.1.100
MSG
    exit 3
  fi
fi

export DISPLAY="${HOST_IP}:${DISPLAY_NUM}.0"
# Helpful Qt env vars for remote X over TCP
export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-xcb}
export QT_X11_NO_MITSHM=${QT_X11_NO_MITSHM:-1}
export LIBGL_ALWAYS_INDIRECT=${LIBGL_ALWAYS_INDIRECT:-1}

echo "HOST_IP=$HOST_IP"
echo "DISPLAY=$DISPLAY (=> TCP port $PORT)"
echo "Executable: $EXE"

# quick port test
echo -n "Testing TCP ${HOST_IP}:${PORT} ... "
if timeout 2 bash -c "</dev/tcp/${HOST_IP}/${PORT}" 2>/dev/null; then
  echo "open"
else
  echo "closed or blocked"
  echo "If closed: ensure your host X server is listening on TCP and firewall allows connections."
  echo "On Windows start VcXsrv without -nolisten tcp and allow vcxsrv in firewall, or restart with -ac for testing."
fi

# optional simple X test (if x11-apps is installed)
if command -v xclock >/dev/null 2>&1; then
  echo "Launching xclock as a quick test..."
  xclock &>/dev/null & sleep 1 || true
fi

# run program, capture log
LOG=/tmp/app_with_display.log
mkdir -p "$(dirname "$LOG")"
echo "Starting $EXE (logs -> $LOG)"
"$EXE" &> "$LOG" &
PID=$!

# tail the log in foreground
echo "PID=$PID; tailing $LOG -- press Ctrl-C to exit (app keeps running)"
tail -f "$LOG"