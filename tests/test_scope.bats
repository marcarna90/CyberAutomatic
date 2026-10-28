load test_helper

setup() { setup_cyberauto_test; }
teardown() { teardown_cyberauto_test; }

@test "cidr_match: 192.168.1.5 is inside 192.168.0.0/16" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::cidr_match "192.168.1.5" "192.168.0.0/16"
  [ "$status" -eq 0 ]
}

@test "cidr_match: 8.8.8.8 is outside 192.168.0.0/16" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::cidr_match "8.8.8.8" "192.168.0.0/16"
  [ "$status" -eq 1 ]
}

@test "cidr_match: a hostname target against a CIDR entry returns no-match cleanly, no interpreter errors" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::cidr_match "example.test" "192.168.0.0/16"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "scope::check rejects a hostname not in the allow-list without leaking interpreter errors" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "example.test" "192.168.0.0/16,10.0.0.0/8" "1"
  [ "$status" -eq 2 ]
  [[ "$output" != *"unbound variable"* ]]
  [[ "$output" != *"value too great"* ]]
}

@test "scope::check allows a hostname that is an exact allow-list entry" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "example.test" "192.168.0.0/16,example.test" "1"
  [ "$status" -eq 0 ]
}

@test "scope::check refuses without --i-am-authorized" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "192.168.1.5" "192.168.0.0/16" "0"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not authorized"* ]]
}

@test "scope::check refuses a target outside the allow-list even when authorized" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "8.8.8.8" "192.168.0.0/16" "1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"outside CYBERAUTO_ALLOWED_TARGETS"* ]]
}

@test "scope::check allows an authorized in-scope target" {
  source "${BATS_TEST_DIRNAME}/../lib/scope.sh"
  run scope::check "192.168.1.5" "192.168.0.0/16,10.0.0.0/8" "1"
  [ "$status" -eq 0 ]
}
