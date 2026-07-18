#!/bin/bash

# Common utilities for gridappsd-docker scripts

# Common variables
DATA_DIR="dumps"
MYSQL_FILE="gridappsd_mysql_dump.sql"

# Detect docker compose command (newer 'docker compose' vs older 'docker-compose')
detect_docker_compose() {
  if docker compose version &>/dev/null; then
    echo "docker compose"
  elif docker-compose --version &>/dev/null; then
    echo "docker-compose"
  else
    echo ""
  fi
}

# Initialize and validate docker compose command
# Sets DOCKER_COMPOSE_CMD variable and exits if not found
init_docker_compose() {
  DOCKER_COMPOSE_CMD=$(detect_docker_compose)
  if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo "Error: Neither 'docker compose' nor 'docker-compose' command found"
    echo "Please install Docker Compose"
    exit 1
  fi
  echo "Using: $DOCKER_COMPOSE_CMD"
}

# Build compose files string from docker-compose.d/*.yml
get_compose_files() {
  local files=$( ls -1 docker-compose.d/*yml 2>/dev/null | sed -e 's/^/-f /g' | tr '\n' ' ' )
  echo "-f docker-compose.yml $files"
}

# check_grafana_password COMPOSE_FILES_STRING
#
# When the active grafana overlay (docker-compose.d/docker-compose-grafana.yml)
# is included in the compose set, verify that GRAFANA_ADMIN_PASSWORD is set
# and non-empty.  Fail loudly if it is not.
#
# Why: Grafana 10.x treats an empty GF_SECURITY_ADMIN_PASSWORD as unset and
# falls back to its built-in defaults.ini value ("admin").  Removing the shell
# fallback in the compose file does NOT produce a fail-closed state inside the
# image.  This guard is the actual enforcement point.
check_grafana_password() {
  local compose_files="$1"
  local grafana_overlay="docker-compose.d/docker-compose-grafana.yml"
  # Only enforce when the activated grafana overlay is in the compose set.
  # The .dist template is inert; check only for the activated .yml copy.
  if echo "$compose_files" | grep -qF "$grafana_overlay"; then
    if [ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]; then
      echo "" >&2
      echo "error: GRAFANA_ADMIN_PASSWORD is not set or is empty." >&2
      echo "  The Grafana observability overlay is active, but no admin password" >&2
      echo "  has been supplied.  Grafana 10.x falls back to its built-in default" >&2
      echo "  (admin/admin) when GF_SECURITY_ADMIN_PASSWORD is empty, which" >&2
      echo "  restores the exposure GADO-007 was filed to eliminate." >&2
      echo "" >&2
      echo "  Export GRAFANA_ADMIN_PASSWORD before running this script:" >&2
      echo "    export GRAFANA_ADMIN_PASSWORD=<your-password>" >&2
      echo "" >&2
      exit 1
    fi
  fi
}

# Resolve the actual published host port for a running container.
# Usage: _published_host_port <container_name> <container_port>
# Prints the host port (digits only) if the container is running and publishing
# that port; prints nothing and returns 1 otherwise.
# Uses `docker port`, which is available on both `docker compose` and legacy
# `docker-compose` installs because it is a plain docker CLI command.
_published_host_port() {
  local name="$1"
  local cport="$2"
  local output line port

  # docker port exits nonzero and writes to stderr when the container is absent
  # or the port is not published; capture output, suppress stderr, and neutralise
  # the nonzero exit so set -e (if active in the caller) does not abort.
  output=$(docker port "$name" "$cport" 2>/dev/null) || true
  if [ -z "$output" ]; then
    return 1
  fi

  # Extract the published host port regardless of bind address.
  # docker port lines come in four forms:
  #   0.0.0.0:PORT      (IPv4 any)
  #   127.0.0.1:PORT    (IPv4 loopback, used by GADO-006 rebind)
  #   [::]:PORT         (IPv6 bracketed)
  #   :::PORT           (IPv6 bare)
  # Strategy: prefer the first IPv4 line (does not start with [ or ::) because
  # it is always present when a port is published on an IPv4 interface.
  # Fall back to the first line when only an IPv6 binding exists.
  # ${line##*:} strips everything up to and including the last colon, yielding
  # just the PORT digits for all four formats above.
  line=$(printf '%s\n' "$output" | grep -v -e '^\[' -e '^::' | head -1)
  if [ -z "$line" ]; then
    line=$(printf '%s\n' "$output" | head -1)
  fi

  port="${line##*:}"
  # Reject empty or non-numeric port; guards against malformed docker output.
  case "$port" in
    ""|*[!0-9]*) return 1 ;;
  esac
  echo "$port"
}

# Print a human-readable access URL list driven by ACTUAL RUNTIME STATE.
#
# For each known surface, queries `docker port <container> <container_port>` to
# learn the actual published host port. A line is printed ONLY if the container
# is running and that port is currently published. A remap (e.g. grafana on 4001
# instead of the default 4000) is honoured automatically because the host port
# comes from the live container, not a hardcoded literal.
#
# Known surfaces in display order (container_name|container_port|label|scheme|path):
#   viz         8082  GridAPPS-D Viz (main UI)   http  /
#   gridappsd   8000  GridAPPS-D API             http  /
#   blazegraph  8080  Blazegraph (triplestore)   http  /bigdata/
#   influxdb    8086  InfluxDB                   http  /
#   gridappsd  61613  STOMP                      tcp   (no path)
#   gridappsd  61614  WebSocket                  ws    (no path)
#   gridappsd  61616  OpenWire                   tcp   (no path)
#   grafana     3000  Grafana                    http  /
#   prometheus  9090  Prometheus                 http  /
#   loki        3100  Loki                       http  /
#   tempo       3200  Tempo                      http  /
#
# An unknown container/port that is running and publishing will be silently
# omitted because the label map is exhaustive for the services defined across
# docker-compose.yml and docker-compose.d/*.yml.dist. Adding a new service
# means adding a row here.
#
# Call once, after a successful docker compose up, in the platform-mode
# (autostart) path of run.sh. Do NOT call in services-only (-s) mode or in the
# no-autostart (-n) container-shell path.
print_access_urls() {
  local host_port label scheme path_suffix url
  local header_printed=0
  local container cport rest

  # Each element: container_name|container_port|label|scheme|url_path
  # Ordered for display: base platform first, then observability.
  local surfaces=(
    "viz|8082|GridAPPS-D Viz (main UI)|http|/"
    "gridappsd|8000|GridAPPS-D API|http|/"
    "blazegraph|8080|Blazegraph (triplestore)|http|/bigdata/"
    "influxdb|8086|InfluxDB|http|/"
    "gridappsd|61613|STOMP|tcp|"
    "gridappsd|61614|WebSocket|ws|"
    "gridappsd|61616|OpenWire|tcp|"
    "grafana|3000|Grafana|http|/"
    "prometheus|9090|Prometheus|http|/"
    "loki|3100|Loki|http|/"
    "tempo|3200|Tempo|http|/"
  )

  for surface in "${surfaces[@]}"; do
    # Split on | using parameter expansion; no subshell needed.
    container="${surface%%|*}"
    rest="${surface#*|}"
    cport="${rest%%|*}"
    rest="${rest#*|}"
    label="${rest%%|*}"
    rest="${rest#*|}"
    scheme="${rest%%|*}"
    path_suffix="${rest#*|}"

    host_port=$(_published_host_port "$container" "$cport") || continue

    if [ "$header_printed" -eq 0 ]; then
      echo " "
      echo "Platform is up. Reachable surfaces:"
      echo " "
      header_printed=1
    fi

    case "$scheme" in
      http|https)
        url="${scheme}://localhost:${host_port}${path_suffix}"
        ;;
      *)
        url="${scheme}://localhost:${host_port}"
        ;;
    esac

    printf "  %-30s %s\n" "${label}:" "$url"
  done

  if [ "$header_printed" -eq 1 ]; then
    echo " "
  fi
}
