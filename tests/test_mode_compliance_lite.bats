load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "scores 0% when the PermitRootLogin finding is present" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/compliance-lite.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  findings::add "$ws" "hostaudit" "localhost" "high" "SSH PermitRootLogin yes" "d" "r"
  mode_compliance-lite_run "localhost" "$ws" ""
  jq -e '.score_pct == 0' "$ws/loot/compliance-lite/score.json"
}

@test "scores 100% when there is no PermitRootLogin finding" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/compliance-lite.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  findings::add "$ws" "recon" "192.168.1.5" "info" "unrelated" "d" "r"
  mode_compliance-lite_run "localhost" "$ws" ""
  jq -e '.score_pct == 100' "$ws/loot/compliance-lite/score.json"
}

@test "scores 100% when findings.jsonl does not exist yet" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/compliance-lite.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_compliance-lite_run "localhost" "$ws" ""
  jq -e '.score_pct == 100 and .total_checks == 1' "$ws/loot/compliance-lite/score.json"
}
