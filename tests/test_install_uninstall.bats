load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "install.sh reports unsupported distro cleanly when no known package manager exists" {
  PATH="/usr/bin:/bin"
  if command -v apt-get >/dev/null || command -v pacman >/dev/null; then
    skip "a real package manager is present in this environment"
  fi
  run "${BATS_TEST_DIRNAME}/../scripts/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported distro"* ]]
}

@test "uninstall.sh refuses to delete workspaces without confirmation" {
  mkdir -p "$CYBERAUTO_TMP/workspaces/demo"
  run bash -c "echo n | '${BATS_TEST_DIRNAME}/../scripts/uninstall.sh' --workspace-dir '$CYBERAUTO_TMP/workspaces'"
  [ -d "$CYBERAUTO_TMP/workspaces/demo" ]
}

@test "uninstall.sh deletes workspaces when confirmed" {
  mkdir -p "$CYBERAUTO_TMP/workspaces/demo"
  run bash -c "echo y | '${BATS_TEST_DIRNAME}/../scripts/uninstall.sh' --workspace-dir '$CYBERAUTO_TMP/workspaces'"
  [ ! -d "$CYBERAUTO_TMP/workspaces/demo" ]
}
