load test_helper

setup() { setup_cyberauto_test; cp "${BATS_TEST_DIRNAME}/../conf/cyberauto.conf.example" "$CYBERAUTO_TMP/cyberauto.conf"; }
teardown() { teardown_cyberauto_test; }

@test "refuses an offensive run without --i-am-authorized" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not authorized"* ]]
}

@test "refuses a target outside the allow-list even when authorized" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 8.8.8.8 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outside CYBERAUTO_ALLOWED_TARGETS"* ]]
}

@test "unknown mode exits 2 with a clear message" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m no-such-mode -w demo --i-am-authorized --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown mode"* ]]
}

@test "dispatches an authorized, in-scope run to the mode's run function" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 0 ]
  grep -q "ran true-mode on 192.168.1.5" "$CYBERAUTO_TMP/demo/loot/true-mode.out"
}

@test "refuses bruteforce mode without --allow-bruteforce before even sourcing the mode file" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m bruteforce -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--allow-bruteforce"* ]]
}

@test "--rerun repeats the last recorded run for a workspace" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  rm -f "$CYBERAUTO_TMP/demo/loot/true-mode.out"
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -w demo --rerun --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 0 ]
  grep -q "ran true-mode on 192.168.1.5" "$CYBERAUTO_TMP/demo/loot/true-mode.out"
}

@test "--rerun fails cleanly when no previous run was recorded for the workspace" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -w never-run --rerun --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no previous run"* ]]
}

@test "--list prints created workspace aliases" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  run "${BATS_TEST_DIRNAME}/../cyberauto" --workspace-dir "$CYBERAUTO_TMP" --list
  [[ "$output" == *"demo"* ]]
}
