load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_osint_run records subdomain findings from subfinder" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_osint_run "example.test" "$ws" ""
  [ -f "$ws/loot/osint/subfinder.txt" ]
  [ "$(findings::count "$ws" "info")" -ge 1 ]
}

@test "mode_osint_run only runs theHarvester when --deep is passed" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_osint_run "example.test" "$ws" ""
  [ ! -f "$ws/loot/osint/theHarvester.txt" ]
  mode_osint_run "example.test" "$ws" "--deep"
  [ -f "$ws/loot/osint/theHarvester.txt" ]
}
