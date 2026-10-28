load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_web_run uses whichever tools are present and records findings" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_web_run "192.168.1.5" "$ws" ""
  [ -f "$ws/loot/web/whatweb.txt" ]
  [ -f "$ws/loot/web/nikto.txt" ]
  [ "$(findings::count "$ws" "medium")" -ge 1 ]
}

@test "mode_web_run fails cleanly when no web tool is on PATH" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  PATH="/usr/bin:/bin" # none of the mocks on PATH
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_web_run "192.168.1.5" "$ws" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"no web tool available"* ]]
}

@test "mode_web_run records low-severity findings for weak TLS versions" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_web_run "192.168.1.5" "$ws" ""
  [ -f "$ws/loot/web/testssl.sh.txt" ]
  [ "$(findings::count "$ws" "low")" -ge 1 ]
}
