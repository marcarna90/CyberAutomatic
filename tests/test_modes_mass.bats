load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "mode_massport_run scans every target successfully when --ports is given" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/port.sh"
  source "${BATS_TEST_DIRNAME}/../modes/massport.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_massport_run "$CYBERAUTO_TMP/targets.txt" "$ws" "--ports 80"
  [ -f "$ws/loot/port/nmap.txt" ]
  [ ! -s "$ws/logs/massport.log" ]
}

@test "mode_massport_run logs a per-target failure for every target without aborting the batch" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/port.sh"
  source "${BATS_TEST_DIRNAME}/../modes/massport.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  # No --ports: mode_port_run fails for every target. The batch must still
  # process both (one log line each), never aborting after the first.
  mode_massport_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ "$(grep -c . "$ws/logs/massport.log")" -eq 2 ]
  grep -q "192.168.1.5" "$ws/logs/massport.log"
  grep -q "192.168.1.6" "$ws/logs/massport.log"
}

@test "mode_massweb_run scans every target" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  source "${BATS_TEST_DIRNAME}/../modes/massweb.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_massweb_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ -f "$ws/loot/web/whatweb.txt" ]
}

@test "mode_massvuln_run scans every target" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  source "${BATS_TEST_DIRNAME}/../modes/massvuln.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_massvuln_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ -f "$ws/loot/vulnscan/nmap-vuln.txt" ]
}

@test "mode_airstrike_run scans every target" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/recon.sh"
  source "${BATS_TEST_DIRNAME}/../modes/airstrike.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n192.168.1.6\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_airstrike_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ -f "$ws/loot/recon/nmap.txt" ]
}

@test "mode_full_run runs recon, web and vulnscan for a single target" {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
  source "${BATS_TEST_DIRNAME}/../lib/findings.sh"
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  source "${BATS_TEST_DIRNAME}/../modes/recon.sh"
  source "${BATS_TEST_DIRNAME}/../modes/web.sh"
  source "${BATS_TEST_DIRNAME}/../modes/vulnscan.sh"
  source "${BATS_TEST_DIRNAME}/../modes/osint.sh"
  source "${BATS_TEST_DIRNAME}/../modes/full.sh"
  ws=$(workspace::create "demo" "$CYBERAUTO_TMP")
  printf "192.168.1.5\n" > "$CYBERAUTO_TMP/targets.txt"
  mode_full_run "$CYBERAUTO_TMP/targets.txt" "$ws" ""
  [ -f "$ws/loot/recon/nmap.txt" ]
  [ -f "$ws/loot/web/whatweb.txt" ]
}
