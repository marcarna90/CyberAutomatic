load test_helper

setup() {
  setup_cyberauto_test
  echo "testuser" > "$CYBERAUTO_TMP/users.txt"
  echo "testpass" > "$CYBERAUTO_TMP/pass.txt"
}
teardown() { teardown_cyberauto_test; }

@test "refuses without --allow-bruteforce even if called directly" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--service ssh --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--allow-bruteforce"* ]]
}

@test "refuses an unsupported service" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service telnet --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported service"* ]]
}

@test "refuses a missing wordlist path" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --userlist /no/such/file --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wordlist not found"* ]]
}

@test "default backend ncrack records a critical finding on success" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ -f "$ws/loot/bruteforce/ncrack.txt" ]
  [ "$(findings::count "$ws" "critical")" -ge 1 ]
}

@test "netexec backend is rejected for a non-smb service" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  run mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service ssh --backend netexec --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ "$status" -eq 1 ]
}

@test "netexec backend succeeds for --service smb and records a critical finding" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/bruteforce.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_bruteforce_run "192.168.1.5" "$ws" "--allow-bruteforce --service smb --backend netexec --userlist $CYBERAUTO_TMP/users.txt --passlist $CYBERAUTO_TMP/pass.txt"
  [ -f "$ws/loot/bruteforce/netexec.txt" ]
  [ "$(findings::count "$ws" "critical")" -ge 1 ]
}
