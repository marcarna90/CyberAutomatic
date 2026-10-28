load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "findings::add appends one valid JSON line" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "192.168.1.5" "high" "Open Telnet" "Telnet exposed" "Disable Telnet"
  [ "$(wc -l < "$CYBERAUTO_TMP/findings.jsonl")" -eq 1 ]
  jq -e '.severity == "high"' "$CYBERAUTO_TMP/findings.jsonl"
}

@test "findings::add rejects an invalid severity" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  run findings::add "$CYBERAUTO_TMP" "recon" "x" "critical-ish" "t" "d" "r"
  [ "$status" -eq 1 ]
}

@test "findings::add escapes quotes, backslashes and newlines safely" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "web" "x" "medium" 'He said "hi"' $'line1\nline2 with a \\ backslash' "fix it"
  [ "$(wc -l < "$CYBERAUTO_TMP/findings.jsonl")" -eq 1 ]
  jq -e '.title == "He said \"hi\""' "$CYBERAUTO_TMP/findings.jsonl"
}

@test "findings::count counts matching severities" {
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "high" "a" "d" "r"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "high" "b" "d" "r"
  findings::add "$CYBERAUTO_TMP" "recon" "x" "low" "c" "d" "r"
  run findings::count "$CYBERAUTO_TMP" "high"
  [ "$output" -eq 2 ]
}
