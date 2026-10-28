load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "flags PermitRootLogin yes as a high-severity finding" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin yes\n" > "$CYBERAUTO_TMP/sshd_config"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$(findings::count "$ws" "high")" -ge 1 ]
}

@test "does not flag PermitRootLogin no" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$(findings::count "$ws" "high")" -eq 0 ]
}

@test "is inert with no --check-paths (no crash, zero findings from that check)" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  run mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ "$status" -eq 0 ]
}

@test "flags a world-writable path when --check-paths names it" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  touch "$CYBERAUTO_TMP/world-writable-file"
  chmod 666 "$CYBERAUTO_TMP/world-writable-file"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config --check-paths $CYBERAUTO_TMP/world-writable-file"
  [ "$(findings::count "$ws" "medium")" -ge 1 ]
}

@test "does not flag a non-world-writable path" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  touch "$CYBERAUTO_TMP/safe-file"
  chmod 644 "$CYBERAUTO_TMP/safe-file"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config --check-paths $CYBERAUTO_TMP/safe-file"
  [ "$(findings::count "$ws" "medium")" -eq 0 ]
}

@test "stores raw lynis output when lynis is present" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/hostaudit.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "PermitRootLogin no\n" > "$CYBERAUTO_TMP/sshd_config"
  mode_hostaudit_run "localhost" "$ws" "--sshd-config $CYBERAUTO_TMP/sshd_config"
  [ -f "$ws/loot/hostaudit/lynis.txt" ]
}
