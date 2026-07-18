#!/usr/bin/env bats
# tests/test_grafana_password_guard.bats
#
# Unit tests for check_grafana_password (utils.sh).
# Drives the guard function in isolation: no containers are started or stopped.
#
# Each test sources utils.sh into a subshell, calls check_grafana_password with
# a compose-files string that either includes or excludes the grafana overlay,
# and asserts exit code AND error message content per shell.md / data-invariants.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
UTILS="$REPO_ROOT/utils.sh"
OVERLAY="docker-compose.d/docker-compose-grafana.yml"

# Helper: call check_grafana_password in a subshell with controlled env.
# Usage: run_guard COMPOSE_FILES [GRAFANA_ADMIN_PASSWORD_value]
# Passing no second arg leaves the variable unset.
run_guard() {
  local compose_files="$1"
  local password="${2-__UNSET__}"  # sentinel so caller can distinguish unset vs empty
  if [[ "$password" == "__UNSET__" ]]; then
    # Unset: source utils and call the function with the var absent
    run bash -c "
      source '$UTILS'
      unset GRAFANA_ADMIN_PASSWORD
      check_grafana_password '$compose_files'
    "
  else
    run bash -c "
      source '$UTILS'
      export GRAFANA_ADMIN_PASSWORD='$password'
      check_grafana_password '$compose_files'
    "
  fi
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password UNSET -> must fail with clear message
# ---------------------------------------------------------------------------
@test "guard fails when overlay active and GRAFANA_ADMIN_PASSWORD is unset" {
  run_guard "-f docker-compose.yml -f $OVERLAY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"GRAFANA_ADMIN_PASSWORD"* ]]
  [[ "$output" == *"not set or is empty"* ]]
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password EMPTY -> must fail (Grafana falls back to admin)
# ---------------------------------------------------------------------------
@test "guard fails when overlay active and GRAFANA_ADMIN_PASSWORD is empty string" {
  run_guard "-f docker-compose.yml -f $OVERLAY" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"GRAFANA_ADMIN_PASSWORD"* ]]
  [[ "$output" == *"not set or is empty"* ]]
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE, password NON-EMPTY -> must succeed (exit 0, no error output)
# ---------------------------------------------------------------------------
@test "guard passes when overlay active and GRAFANA_ADMIN_PASSWORD is non-empty" {
  run_guard "-f docker-compose.yml -f $OVERLAY" "s3cr3t"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Overlay NOT active (only base compose) -> guard is a no-op regardless of password
# ---------------------------------------------------------------------------
@test "guard is no-op when grafana overlay is absent and password is unset" {
  run_guard "-f docker-compose.yml"
  [ "$status" -eq 0 ]
}

@test "guard is no-op when grafana overlay is absent and password is empty" {
  run_guard "-f docker-compose.yml" ""
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Overlay ACTIVE: verify the Grafana admin/admin fallback explanation appears
# (confirms the actionable reason is in the message, not just the var name)
# ---------------------------------------------------------------------------
@test "guard message mentions Grafana admin fallback when password unset" {
  run_guard "-f docker-compose.yml -f $OVERLAY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"admin/admin"* ]]
}
