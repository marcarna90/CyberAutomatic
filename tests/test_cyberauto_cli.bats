load test_helper

setup() { setup_cyberauto_test; cp "${BATS_TEST_DIRNAME}/../conf/cyberauto.conf.example" "$CYBERAUTO_TMP/cyberauto.conf"; }
teardown() { teardown_cyberauto_test; }

@test "refuses an offensive run without --i-am-authorized" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not authorized"* ]]
}

@test "rejects a hostname target cleanly, without leaking bash arithmetic errors (set -u)" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t example.test -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outside CYBERAUTO_ALLOWED_TARGETS"* ]]
  [[ "$output" != *"unbound variable"* ]]
  [[ "$output" != *"value too great"* ]]
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

@test "dispatched modes have findings::add available through the real entrypoint" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m finding-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 0 ]
  jq -e '.title == "test finding"' "$CYBERAUTO_TMP/demo/findings.jsonl"
}

@test "bruteforce succeeds via the real entrypoint with --allow-bruteforce passed once, as documented" {
  echo "testuser" > "$CYBERAUTO_TMP/users.txt"
  echo "testpass" > "$CYBERAUTO_TMP/pass.txt"
  run "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m bruteforce -w demo \
    --i-am-authorized --allow-bruteforce --workspace-dir "$CYBERAUTO_TMP" \
    -- --service ssh --userlist "$CYBERAUTO_TMP/users.txt" --passlist "$CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 0 ]
  [ -f "$CYBERAUTO_TMP/demo/loot/bruteforce/ncrack.txt" ]
  jq -e '.severity == "critical"' "$CYBERAUTO_TMP/demo/findings.jsonl"
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

@test "--report renders a Markdown report from the workspace's findings" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m finding-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  run "${BATS_TEST_DIRNAME}/../cyberauto" -w demo --report "$CYBERAUTO_TMP/out.md" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 0 ]
  grep -q "test finding" "$CYBERAUTO_TMP/out.md"
}

@test "refuses --delete without -w instead of deleting the whole workspace dir" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w keep-me --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  run "${BATS_TEST_DIRNAME}/../cyberauto" -d --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [ -d "$CYBERAUTO_TMP/keep-me" ]
}

@test "refuses --export without -w" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" --export "$CYBERAUTO_TMP/out.tar.gz" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
}

@test "refuses --report without -w instead of polluting the workspace base dir" {
  run "${BATS_TEST_DIRNAME}/../cyberauto" --report "$CYBERAUTO_TMP/out.md" --workspace-dir "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [ ! -d "$CYBERAUTO_TMP/loot" ]
}

@test "--list prints created workspace aliases" {
  "${BATS_TEST_DIRNAME}/../cyberauto" -c "$CYBERAUTO_TMP/cyberauto.conf" -t 192.168.1.5 -m true-mode -w demo --i-am-authorized --modes-dir "${BATS_TEST_DIRNAME}/fixtures/modes" --workspace-dir "$CYBERAUTO_TMP" > /dev/null
  run "${BATS_TEST_DIRNAME}/../cyberauto" --workspace-dir "$CYBERAUTO_TMP" --list
  [[ "$output" == *"demo"* ]]
}
