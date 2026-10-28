load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "workspace::create makes loot/logs/reports and workspace.meta" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  [ -d "$path/loot" ]
  [ -d "$path/logs" ]
  [ -d "$path/reports" ]
  grep -q "alias=demo" "$path/workspace.meta"
}

@test "workspace::create is idempotent and keeps existing loot" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  echo "keep-me" > "$path/loot/marker.txt"
  workspace::create "demo" "$CYBERAUTO_TMP" > /dev/null
  [ -f "$path/loot/marker.txt" ]
}

@test "workspace::list shows created workspaces" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  workspace::create "alpha" "$CYBERAUTO_TMP" > /dev/null
  workspace::create "beta" "$CYBERAUTO_TMP" > /dev/null
  run workspace::list "$CYBERAUTO_TMP"
  [[ "$output" == *"alpha"* ]]
  [[ "$output" == *"beta"* ]]
}

@test "workspace::delete removes the workspace" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "gone" "$CYBERAUTO_TMP")
  workspace::delete "gone" "$CYBERAUTO_TMP"
  [ ! -d "$path" ]
}

@test "workspace::export then workspace::reimport restores the workspace" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "roundtrip" "$CYBERAUTO_TMP")
  echo "data" > "$path/loot/f.txt"
  workspace::export "roundtrip" "$CYBERAUTO_TMP" "$CYBERAUTO_TMP/roundtrip.tar.gz"
  workspace::delete "roundtrip" "$CYBERAUTO_TMP"
  workspace::reimport "$CYBERAUTO_TMP/roundtrip.tar.gz" "$CYBERAUTO_TMP"
  [ -f "$path/loot/f.txt" ]
}
