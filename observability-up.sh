#!/usr/bin/env bash
# observability-up.sh -- GADO-008: additive observability activation
#
# Brings up the observability stack (otel-agent-init, otel-collector,
# prometheus, tempo, loki, grafana) on a RUNNING platform WITHOUT tearing
# down or restarting the base gridappsd services.
#
# Prerequisites:
#   GRAFANA_ADMIN_PASSWORD must be exported before running this script.
#   OBSERVABILITY_BIND_HOST defaults to 127.0.0.1 (loopback).
#     Set to 0.0.0.0 only on a trusted, firewalled network.
#
# Usage:
#   export GRAFANA_ADMIN_PASSWORD=<your-password>
#   ./observability-up.sh
#
# To stop observability services only (leaves the base platform running):
#   ./observability-up.sh --down
#
# The template file is docker-compose.d/docker-compose-grafana.yml.dist.
# This script activates a copy at docker-compose.d/docker-compose-grafana.yml
# so run.sh picks it up on the next full restart too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck disable=SC1091
# SC1091: shellcheck cannot follow the dynamic $SCRIPT_DIR path; the file
# exists at runtime in the same directory as this script.
source "$SCRIPT_DIR/utils.sh"

init_docker_compose

DIST_FILE="docker-compose.d/docker-compose-grafana.yml.dist"
ACTIVE_FILE="docker-compose.d/docker-compose-grafana.yml"
BASE_COMPOSE="docker-compose.yml"

# Observability services declared in the template (in dependency order).
# otel-agent-init runs once and exits; the rest are long-lived.
OBS_SERVICES=(otel-agent-init otel-collector prometheus tempo loki grafana)

usage() {
  echo "Usage: $0 [--down]"
  echo ""
  echo "  (no flag)  Bring observability services up additively"
  echo "  --down     Stop and remove observability services only"
  exit 1
}

# ---- parse args ----
mode="up"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --down) mode="down" ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
  shift
done

# ---- guard: GRAFANA_ADMIN_PASSWORD required for 'up' ----
if [[ "$mode" == "up" ]]; then
  if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
    echo "error: GRAFANA_ADMIN_PASSWORD is not set." >&2
    echo "  Export it before running this script:" >&2
    echo "    export GRAFANA_ADMIN_PASSWORD=<your-password>" >&2
    exit 1
  fi
fi

# ---- activate the template (copy .dist -> .yml if not already done) ----
if [[ ! -f "$ACTIVE_FILE" ]]; then
  if [[ ! -f "$DIST_FILE" ]]; then
    echo "error: template not found: $DIST_FILE" >&2
    exit 1
  fi
  echo "Activating observability template: $DIST_FILE -> $ACTIVE_FILE"
  cp "$DIST_FILE" "$ACTIVE_FILE"
fi

COMPOSE_ARGS=(-f "$BASE_COMPOSE" -f "$ACTIVE_FILE")

if [[ "$mode" == "down" ]]; then
  echo "Stopping observability services (base platform is NOT affected)..."
  # Stop and remove only the named observability services; the rest of the
  # compose project (gridappsd, blazegraph, etc.) continues running.
  $DOCKER_COMPOSE_CMD "${COMPOSE_ARGS[@]}" stop "${OBS_SERVICES[@]}"
  $DOCKER_COMPOSE_CMD "${COMPOSE_ARGS[@]}" rm -f "${OBS_SERVICES[@]}"
  echo "Observability services stopped and removed."
else
  echo "Starting observability services additively (base platform stays up)..."
  $DOCKER_COMPOSE_CMD "${COMPOSE_ARGS[@]}" up -d "${OBS_SERVICES[@]}"
  echo ""
  echo "Observability endpoints (loopback by default):"
  bind_host="${OBSERVABILITY_BIND_HOST:-127.0.0.1}"
  echo "  Grafana:          http://${bind_host}:4000/"
  echo "  Prometheus:       http://${bind_host}:9090/"
  echo "  Loki:             http://${bind_host}:3100/"
  echo "  Tempo:            http://${bind_host}:3200/"
  echo "  OTLP gRPC:        ${bind_host}:4317"
  echo "  OTLP HTTP:        http://${bind_host}:4318/"
  echo ""
  echo "To stop observability without affecting the base platform:"
  echo "  ./observability-up.sh --down"
fi
