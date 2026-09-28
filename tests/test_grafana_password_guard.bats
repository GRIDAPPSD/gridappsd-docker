#!/usr/bin/env bats
# tests/test_grafana_password_guard.bats
#
# Unit tests for ensure_grafana_password (utils.sh) -- GADO-009 semantics.
# The function replaced the GADO-007 hard-stop with auto-generate-and-surface:
#   - Overlay active, password unset/empty: generate, export, set flag; exit 0.
#   - Overlay active, password set: leave unchanged, no flag; exit 0.
#   - Overlay absent: no-op regardless of password state; exit 0.
#
# Drives the function in isolation: no containers are started or stopped.
# Each test sources utils.sh into a subshell and asserts exit code, flag state,
# and password value per shell.md / data-invariants.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
UTILS="$REPO_ROOT/utils.sh"
OVERLAY="docker-compose.d/docker-compose-grafana.yml"

# Helper: call ensure_grafana_password in a subshell with controlled env.
# Usage: run_guard COMPOSE_FILES [GRAFANA_ADMIN_PASSWORD_value]
# Passing no second arg leaves the variable unset.
# Emits "FLAG=<value>" and "PW=<value>" lines so assertions can check them.
run_guard() {
  local compose_files="$1"
  local password="${2-__UNSET__}"  # sentinel so caller can distinguish unset vs empty
  if [[ "$password" == "__UNSET__" ]]; then
    run bash -c "
      source '$UTILS'
      unset GRAFANA_ADMIN_PASSWORD
      ensure_grafana_password '$compose_files'
      echo \"FLAG=\${GRAFANA_PASSWORD_GENERATED:-UNSET}\"
      echo \"PW=\${GRAFANA_ADMIN_PASSWORD:-UNSET}\"
    "
  else
    run bash -c "
      source '$UTILS'
      export GRAFANA_ADMIN_PASSWORD='$password'
      ensure_grafana_password '$compose_files'
      echo \"FLAG=\${GRAFANA_PASSWORD_GENERATED:-UNSET}\"
      echo \"PW=\${GRAFANA_ADMIN_PASSWORD:-UNSET}\"
    "
  fi
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password UNSET: must auto-generate, set flag, exit 0
# ---------------------------------------------------------------------------
@test "GADO-009: overlay active, password unset: exits 0 (no hard-stop)" {
  run_guard "-f docker-compose.yml -f $OVERLAY"
  [ "$status" -eq 0 ]
}

@test "GADO-009: overlay active, password unset: generates a non-empty password" {
  run_guard "-f docker-compose.yml -f $OVERLAY"
  [ "$status" -eq 0 ]
  # PW= line must NOT be UNSET or empty
  [[ "$output" != *"PW=UNSET"* ]]
  [[ "$output" != *"PW="$'\n'* ]]
  # The generated password replaces UNSET: verify the line exists with a value
  [[ "$output" == *"PW="* ]]
}

@test "GADO-009: overlay active, password unset: sets GRAFANA_PASSWORD_GENERATED=1" {
  run_guard "-f docker-compose.yml -f $OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FLAG=1"* ]]
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password EMPTY: same auto-generate behavior as unset
# ---------------------------------------------------------------------------
@test "GADO-009: overlay active, password empty string: exits 0 (no hard-stop)" {
  run_guard "-f docker-compose.yml -f $OVERLAY" ""
  [ "$status" -eq 0 ]
}

@test "GADO-009: overlay active, password empty string: generates a password" {
  run_guard "-f docker-compose.yml -f $OVERLAY" ""
  [ "$status" -eq 0 ]
  [[ "$output" != *"PW=UNSET"* ]]
  [[ "$output" == *"FLAG=1"* ]]
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password NON-EMPTY: leave unchanged, no flag, exit 0
# ---------------------------------------------------------------------------
@test "GADO-009: overlay active, password set: exits 0" {
  run_guard "-f docker-compose.yml -f $OVERLAY" "s3cr3t"
  [ "$status" -eq 0 ]
}

@test "GADO-009: overlay active, password set: retains original password" {
  run_guard "-f docker-compose.yml -f $OVERLAY" "s3cr3t"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PW=s3cr3t"* ]]
}

@test "GADO-009: overlay active, password set: does NOT set generated flag" {
  run_guard "-f docker-compose.yml -f $OVERLAY" "s3cr3t"
  [ "$status" -eq 0 ]
  # FLAG should be UNSET (flag not exported when using operator password)
  [[ "$output" != *"FLAG=1"* ]]
}

# ---------------------------------------------------------------------------
# Overlay NOT active: no-op regardless of password
# ---------------------------------------------------------------------------
@test "overlay absent, password unset: no-op, exits 0" {
  run_guard "-f docker-compose.yml"
  [ "$status" -eq 0 ]
}

@test "overlay absent, password empty: no-op, exits 0" {
  run_guard "-f docker-compose.yml" ""
  [ "$status" -eq 0 ]
}

@test "overlay absent, password unset: does not generate password" {
  run_guard "-f docker-compose.yml"
  [ "$status" -eq 0 ]
  # No generation when overlay is not active
  [[ "$output" != *"FLAG=1"* ]]
}

# ---------------------------------------------------------------------------
# Fail-closed: openssl absent or errored (Leon MEDIUM, fix 1)
# When openssl fails and returns empty, ensure_grafana_password must exit
# nonzero, must NOT export an empty password, and must NOT set the flag.
# ---------------------------------------------------------------------------
@test "GADO-009 fail-closed: openssl absent/errored: exits nonzero" {
  local fail_stub="$REPO_ROOT/tests/stubs/openssl-fail"
  run bash -c "
    export PATH=\"$fail_stub:\$PATH\"
    source '$UTILS'
    unset GRAFANA_ADMIN_PASSWORD
    ensure_grafana_password '-f docker-compose.yml -f $OVERLAY'
  "
  [ "$status" -ne 0 ]
}

@test "GADO-009 fail-closed: openssl absent/errored: does NOT export empty password" {
  local fail_stub="$REPO_ROOT/tests/stubs/openssl-fail"
  # exit 1 inside the function terminates the shell before 'export GRAFANA_ADMIN_PASSWORD'
  # is reached.  Capture stderr (the error message) to confirm the guard fired; its
  # presence proves the export line was never reached, so no empty password was exported.
  run bash -c "
    export PATH=\"$fail_stub:\$PATH\"
    source '$UTILS'
    unset GRAFANA_ADMIN_PASSWORD
    ensure_grafana_password '-f docker-compose.yml -f $OVERLAY'
  " 2>&1
  [[ "$output" == *"password generation failed"* ]]
}

@test "GADO-009 fail-closed: openssl absent/errored: does NOT set generated flag" {
  local fail_stub="$REPO_ROOT/tests/stubs/openssl-fail"
  run bash -c "
    export PATH=\"$fail_stub:\$PATH\"
    source '$UTILS'
    unset GRAFANA_ADMIN_PASSWORD
    ensure_grafana_password '-f docker-compose.yml -f $OVERLAY' || true
    echo \"FLAG=\${GRAFANA_PASSWORD_GENERATED:-UNSET}\"
  "
  [[ "$output" != *"FLAG=1"* ]]
}
