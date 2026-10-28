load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "deps::require succeeds for a tool on PATH" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  run deps::require "bash"
  [ "$status" -eq 0 ]
}

@test "deps::require fails for a missing tool" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  run deps::require "no-such-tool-xyz"
  [ "$status" -eq 1 ]
}

@test "deps::check_or_warn logs WARN and returns 1 when tool missing" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  log="${CYBERAUTO_TMP}/mode.log"
  run deps::check_or_warn "no-such-tool-xyz" "web" "$log"
  [ "$status" -eq 1 ]
  grep -q "WARN: web: no-such-tool-xyz not found" "$log"
}
