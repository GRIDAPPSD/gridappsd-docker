#!/usr/bin/env bats
#
# Smoke tests for print_access_urls() from utils.sh (dynamic runtime-state variant).
#
# Tests stub `docker` via a PATH-prepended stub (tests/stubs/docker) that reads
# per-container port data from $DOCKER_STUB_DIR/<name>.ports. Absent file means
# the container is not running; a file present but missing the requested port
# means the container runs but does not publish that port.
#
# Assertions check actual URL strings in output (not just exit 0), per
# [[data-invariants]] Rule 1.

REPO_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
STUBS_DIR="${REPO_DIR}/tests/stubs"

setup() {
  # Temp dir for per-container stub .ports files
  DOCKER_STUB_DIR="$(mktemp -d)"
  export DOCKER_STUB_DIR

  # Prepend the stubs directory so our docker stub wins over the real docker
  PATH="${STUBS_DIR}:${PATH}"
  export PATH

  # Source utils.sh to define _published_host_port and print_access_urls.
  # utils.sh has no top-level function calls; safe to source without real docker.
  # SC1091: path computed at runtime from REPO_DIR, cannot be followed statically.
  # shellcheck disable=SC1091
  source "${REPO_DIR}/utils.sh"
}

teardown() {
  rm -rf "${DOCKER_STUB_DIR}"
}

# Helper: register a published port for a container in the stub.
# Usage: stub_port <container_name> <container_port> <host_port> [bind_address]
# bind_address defaults to 0.0.0.0 when omitted.
# Pass e.g. "127.0.0.1", "[::]", or "::" to test alternate bind forms.
stub_port() {
  local name="$1" cport="$2" hport="$3" bind="${4:-0.0.0.0}"
  printf '%s\t%s:%s\n' "$cport" "$bind" "$hport" >> "${DOCKER_STUB_DIR}/${name}.ports"
}

# ---------------------------------------------------------------------------
# Base platform: published ports produce URLs
# ---------------------------------------------------------------------------

@test "viz running on default port: Viz URL is printed" {
  stub_port viz 8082 8080
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8080"* ]]
}

@test "gridappsd running on API port: API URL is printed" {
  stub_port gridappsd 8000 8000
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8000"* ]]
}

@test "blazegraph running: Blazegraph URL is printed" {
  stub_port blazegraph 8080 8889
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8889"* ]]
}

@test "influxdb running: InfluxDB URL is printed" {
  stub_port influxdb 8086 8086
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8086"* ]]
}

# ---------------------------------------------------------------------------
# Not-running: no URL line when container stub file is absent
# ---------------------------------------------------------------------------

@test "viz not running: no Viz URL in output" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"Viz"* ]]
}

@test "blazegraph not running: no Blazegraph URL in output" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:8889"* ]]
}

@test "influxdb not running: no InfluxDB URL in output" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:8086"* ]]
}

# ---------------------------------------------------------------------------
# Not-publishing: container stub file exists but requested port not in it
# ---------------------------------------------------------------------------

@test "gridappsd running but API port not published: no API URL" {
  # Container is up (file exists) but only STOMP is published, not 8000
  stub_port gridappsd 61613 61613
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:8000"* ]]
}

@test "gridappsd running but STOMP not published: no STOMP URL" {
  stub_port gridappsd 8000 8000
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:61613"* ]]
}

# ---------------------------------------------------------------------------
# Observability: only when containers are actually running
# ---------------------------------------------------------------------------

@test "grafana running: Grafana URL is printed" {
  stub_port grafana 3000 4000
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
}

@test "prometheus running: Prometheus URL is printed" {
  stub_port prometheus 9090 9090
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:9090"* ]]
}

@test "grafana NOT running: no Grafana URL" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:4000"* ]]
}

@test "loki NOT running: no Loki URL" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:3100"* ]]
}

# ---------------------------------------------------------------------------
# Numeric-port guard: garbage docker port output yields no URL
# ---------------------------------------------------------------------------

@test "docker port returns non-numeric garbage: no URL printed for that surface" {
  # Write a stub line whose second field is not a numeric port after the colon
  printf '3000\t0.0.0.0:not-a-port\n' >> "${DOCKER_STUB_DIR}/grafana.ports"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:not-a-port"* ]]
  [[ "$output" != *"Grafana"* ]]
}

# ---------------------------------------------------------------------------
# Empty-state header: no surfaces running means no header
# ---------------------------------------------------------------------------

@test "no containers running: header is not printed" {
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"Platform is up. Reachable surfaces:"* ]]
}

# ---------------------------------------------------------------------------
# Bind-address agnostic: port extracted correctly across all bind forms.
# These cases gate the GADO-006 forward-compatibility fix.
# ---------------------------------------------------------------------------

@test "grafana bound to 0.0.0.0 (standard): URL prints with correct port" {
  stub_port grafana 3000 4000 "0.0.0.0"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
}

@test "grafana bound to 127.0.0.1 (GADO-006 loopback rebind): URL still prints" {
  stub_port grafana 3000 4000 "127.0.0.1"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
}

@test "loki bound to [::] (IPv6 bracketed) only: URL prints with correct port" {
  stub_port loki 3100 3100 "[::]"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:3100"* ]]
}

@test "tempo bound to :: (IPv6 bare) only: URL prints with correct port" {
  stub_port tempo 3200 3200 "::"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:3200"* ]]
}

@test "grafana bound to both 0.0.0.0 and [::]: URL printed once with correct port" {
  # Real docker port output has two lines (IPv4 then IPv6); function prefers IPv4
  stub_port grafana 3000 4000 "0.0.0.0"
  stub_port grafana 3000 4000 "[::]"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
}

# ---------------------------------------------------------------------------
# Remap: operator-remapped host port prints the actual port, not the default
# ---------------------------------------------------------------------------

@test "grafana remapped to 127.0.0.1:4001 (loopback remap): URL prints 4001 not 4000" {
  # Covers both the remap and the loopback-bind correctness in one assertion.
  stub_port grafana 3000 4001 "127.0.0.1"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4001"* ]]
  [[ "$output" != *"localhost:4000"* ]]
}

@test "viz remapped to host port 9080: URL prints 9080 not 8080" {
  stub_port viz 8082 9080
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:9080"* ]]
  [[ "$output" != *"localhost:8080"* ]]
}

# ---------------------------------------------------------------------------
# Full platform + observability all up: all expected URLs present
# ---------------------------------------------------------------------------

@test "all base and observability running: all URLs present" {
  stub_port viz        8082  8080
  stub_port gridappsd  8000  8000
  stub_port gridappsd 61613 61613
  stub_port gridappsd 61614 61614
  stub_port gridappsd 61616 61616
  stub_port blazegraph 8080  8889
  stub_port influxdb   8086  8086
  stub_port grafana    3000  4000
  stub_port prometheus 9090  9090
  stub_port loki       3100  3100
  stub_port tempo      3200  3200
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8080"* ]]
  [[ "$output" == *"http://localhost:8000"* ]]
  [[ "$output" == *"http://localhost:8889"* ]]
  [[ "$output" == *"http://localhost:8086"* ]]
  [[ "$output" == *"tcp://localhost:61613"* ]]
  [[ "$output" == *"ws://localhost:61614"* ]]
  [[ "$output" == *"tcp://localhost:61616"* ]]
  [[ "$output" == *"http://localhost:4000"* ]]
  [[ "$output" == *"http://localhost:9090"* ]]
  [[ "$output" == *"http://localhost:3100"* ]]
  [[ "$output" == *"http://localhost:3200"* ]]
}

# ---------------------------------------------------------------------------
# Observability down, base up: observability URLs absent
# ---------------------------------------------------------------------------

@test "base up, observability containers not running: no observability URLs" {
  stub_port viz        8082  8080
  stub_port gridappsd  8000  8000
  stub_port blazegraph 8080  8889
  stub_port influxdb   8086  8086
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:8080"* ]]
  [[ "$output" != *"localhost:4000"* ]]
  [[ "$output" != *"localhost:9090"* ]]
  [[ "$output" != *"localhost:3100"* ]]
  [[ "$output" != *"localhost:3200"* ]]
}

# ---------------------------------------------------------------------------
# GADO-009: generated-password banner line
# When GRAFANA_PASSWORD_GENERATED=1 and GRAFANA_ADMIN_PASSWORD is set,
# the Grafana line includes the password and the dev-only caveat.
# ---------------------------------------------------------------------------

@test "GADO-009: generated password flag causes Grafana line to show password and caveat" {
  stub_port grafana 3000 4000
  # Simulate what ensure_grafana_password sets when it auto-generates
  export GRAFANA_PASSWORD_GENERATED=1
  export GRAFANA_ADMIN_PASSWORD="GeneratedTestPw99"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
  [[ "$output" == *"GeneratedTestPw99"* ]]
  [[ "$output" == *"dev use only"* ]]
}

@test "GADO-009: operator-set password flag absent: Grafana line shows URL but no password" {
  stub_port grafana 3000 4000
  # Simulate operator-supplied password: flag is NOT set
  unset GRAFANA_PASSWORD_GENERATED || true
  export GRAFANA_ADMIN_PASSWORD="OperatorSecret42"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4000"* ]]
  [[ "$output" != *"OperatorSecret42"* ]]
  [[ "$output" != *"dev use only"* ]]
}

@test "GADO-009: grafana not running: no password logic fires regardless of flags" {
  # No stub file for grafana = container not running
  export GRAFANA_PASSWORD_GENERATED=1
  export GRAFANA_ADMIN_PASSWORD="ShouldNotAppear"
  run print_access_urls
  [ "$status" -eq 0 ]
  [[ "$output" != *"localhost:4000"* ]]
  [[ "$output" != *"ShouldNotAppear"* ]]
  [[ "$output" != *"dev use only"* ]]
}
