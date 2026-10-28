load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_recon_run records an open-port finding and raw loot" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/recon.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_recon_run "192.168.1.5" "$ws" ""
  [ -f "$ws/loot/recon/nmap.txt" ]
  jq -e '.title | contains("22/tcp")' "$ws/findings.jsonl"
}

@test "mode_discover_run passes -sn and produces no port findings" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/discover.sh"
  export CYBERAUTO_NMAP_ARGS_LOG="$CYBERAUTO_TMP/nmap_args.log"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_discover_run "192.168.1.0/24" "$ws" ""
  grep -q -- "-sn" "$CYBERAUTO_TMP/nmap_args.log"
}

@test "mode_stealth_run uses SYN scan and slow timing" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/stealth.sh"
  export CYBERAUTO_NMAP_ARGS_LOG="$CYBERAUTO_TMP/nmap_args.log"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_stealth_run "192.168.1.5" "$ws" ""
  grep -q -- "-sS" "$CYBERAUTO_TMP/nmap_args.log"
  grep -q -- "-T2" "$CYBERAUTO_TMP/nmap_args.log"
}

@test "mode_fullport_run scans the full port range and records findings" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/fullport.sh"
  export CYBERAUTO_NMAP_ARGS_LOG="$CYBERAUTO_TMP/nmap_args.log"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  mode_fullport_run "192.168.1.5" "$ws" ""
  grep -q -- "-p-" "$CYBERAUTO_TMP/nmap_args.log"
  jq -e '.title | contains("22/tcp")' "$ws/findings.jsonl"
}

@test "mode_port_run fails loudly when nmap is entirely missing" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/port.sh"
  # Prepare the empty PATH target and the workspace *before* restricting
  # PATH below — both need external tools (mkdir, date) that must still be
  # resolvable at this point. See Task 8 ledger ruling.
  mkdir -p "$CYBERAUTO_TMP/empty-path-dir"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  local old_path="$PATH"
  PATH="$CYBERAUTO_TMP/empty-path-dir" # nmap (and everything else) not here
  run mode_port_run "192.168.1.5" "$ws" "--ports 80"
  PATH="$old_path" # restore before teardown needs rm/mktemp back on PATH
  [ "$status" -eq 1 ]
}
