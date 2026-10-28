load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "report::generate renders every finding and the summary counts" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/report.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "192.168.1.5" "high" "Open Telnet" "desc" "Disable it"
  findings::add "$CYBERAUTO_TMP" "web" "192.168.1.5" "low" "Missing header" "desc" "Add it"
  report::generate "$CYBERAUTO_TMP" \
    "${BATS_TEST_DIRNAME}/../templates/report.md.tpl" \
    "${BATS_TEST_DIRNAME}/../templates/finding_row.md.tpl" \
    "$CYBERAUTO_TMP/out.md"
  grep -q "Total findings: 2" "$CYBERAUTO_TMP/out.md"
  grep -q "Open Telnet" "$CYBERAUTO_TMP/out.md"
  grep -q "Missing header" "$CYBERAUTO_TMP/out.md"
}

@test "report::generate fails cleanly with no findings.jsonl" {
  source "${BATS_TEST_DIRNAME}/../lib/report.sh"
  run report::generate "$CYBERAUTO_TMP" \
    "${BATS_TEST_DIRNAME}/../templates/report.md.tpl" \
    "${BATS_TEST_DIRNAME}/../templates/finding_row.md.tpl" \
    "$CYBERAUTO_TMP/out.md"
  [ "$status" -eq 1 ]
}
