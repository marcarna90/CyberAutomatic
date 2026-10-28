load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_vulnscan_run records findings from both nmap vuln scripts and nuclei" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_vulnscan_run "192.168.1.5" "$ws" ""
  [ "$(findings::count "$ws" "high")" -ge 1 ]
  [ "$(findings::count "$ws" "medium")" -ge 1 ]
}

@test "mode_vulnscan_run fails when nmap is missing even if nuclei is present" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  # Prepare the nuclei-only PATH and the workspace *before* restricting
  # PATH below — both steps need external tools (mkdir, date, cp) that
  # must still be resolvable at this point. See Task 8/11 ledger ruling.
  mkdir -p "$CYBERAUTO_TMP/only-nuclei"
  cp "${BATS_TEST_DIRNAME}/mocks/nuclei" "$CYBERAUTO_TMP/only-nuclei/"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  local old_path="$PATH"
  PATH="$CYBERAUTO_TMP/only-nuclei"
  run mode_vulnscan_run "192.168.1.5" "$ws" ""
  PATH="$old_path" # restore before teardown needs rm/mktemp back on PATH
  [ "$status" -eq 1 ]
}
