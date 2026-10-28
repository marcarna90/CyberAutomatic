load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "rejects an unknown frequency" {
  run "${BATS_TEST_DIRNAME}/../scripts/schedule.sh" demo hourly
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown frequency"* ]]
}

@test "prints the crontab line for a known frequency without confirming" {
  run bash -c "echo n | '${BATS_TEST_DIRNAME}/../scripts/schedule.sh' demo daily"
  [[ "$output" == *"@daily"* ]]
  [[ "$output" == *"cyberauto -w demo --rerun"* ]]
}
