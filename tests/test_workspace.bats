load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "workspace::create creates the base directory itself if it does not exist yet" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  fresh_base="${CYBERAUTO_TMP}/not-created-yet"
  path=$(workspace::create "demo" "$fresh_base")
  [ -d "$path/loot" ]
}

@test "workspace::create never falls back to a root-relative path for a deeply missing base_dir" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  fresh_base="${CYBERAUTO_TMP}/deeply/nested/not-created-yet"
  path=$(workspace::create "demo" "$fresh_base")
  [[ "$path" == "$CYBERAUTO_TMP"/* ]]
}

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

@test "workspace::delete refuses an empty alias instead of deleting the whole base dir" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  workspace::create "keep-me" "$CYBERAUTO_TMP" > /dev/null
  run workspace::delete "" "$CYBERAUTO_TMP"
  [ "$status" -eq 1 ]
  [ -d "$CYBERAUTO_TMP/keep-me" ]
}

@test "workspace::export refuses an empty alias" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  run workspace::export "" "$CYBERAUTO_TMP" "$CYBERAUTO_TMP/out.tar.gz"
  [ "$status" -eq 1 ]
  [ ! -f "$CYBERAUTO_TMP/out.tar.gz" ]
}

@test "workspace::delete removes the workspace" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "gone" "$CYBERAUTO_TMP")
  workspace::delete "gone" "$CYBERAUTO_TMP"
  [ ! -d "$path" ]
}

@test "workspace::record_last then workspace::last round-trips every field" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  workspace::record_last "$path" "recon" "192.168.1.5" "0" "--deep"
  [ "$(workspace::last "$path" mode)" = "recon" ]
  [ "$(workspace::last "$path" target)" = "192.168.1.5" ]
  [ "$(workspace::last "$path" is_file)" = "0" ]
  [ "$(workspace::last "$path" opts)" = "--deep" ]
}

@test "workspace::record_last overwrites a previous recording instead of duplicating it" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  workspace::record_last "$path" "recon" "192.168.1.5" "0" ""
  workspace::record_last "$path" "web" "192.168.1.6" "0" ""
  [ "$(workspace::last "$path" mode)" = "web" ]
  [ "$(grep -c '^last_mode=' "$path/workspace.meta")" -eq 1 ]
}

@test "workspace::last prints nothing when no run was ever recorded" {
  source "${BATS_TEST_DIRNAME}/../lib/workspace.sh"
  path=$(workspace::create "demo" "$CYBERAUTO_TMP")
  [ -z "$(workspace::last "$path" mode)" ]
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
