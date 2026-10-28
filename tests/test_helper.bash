setup_cyberauto_test() {
  export PATH="${BATS_TEST_DIRNAME}/mocks:${PATH}"
  CYBERAUTO_TMP="$(mktemp -d)"
  export CYBERAUTO_TMP
}

teardown_cyberauto_test() {
  rm -rf "${CYBERAUTO_TMP}"
}
