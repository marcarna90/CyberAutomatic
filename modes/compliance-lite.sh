# shellcheck shell=bash
# modes/compliance-lite.sh — maps the single v1 hostaudit check
# (PermitRootLogin yes -> CIS Control 5.2) to an indicative pass/fail score.
# Not a full compliance engine: later hostaudit checks register in this
# same table, not a parallel one.

# mode_compliance-lite_run <target> <workspace_path> <opts>
mode_compliance-lite_run() {
  local target="$1" workspace_path="$2" opts="$3"
  : "$opts" # compliance-lite takes no extra options in v1
  local loot_dir jsonl
  loot_dir="${workspace_path}/loot/compliance-lite"
  jsonl="${workspace_path}/findings.jsonl"
  mkdir -p "$loot_dir"

  local total_checks=1 fail_count=0 passed score_pct
  if [ -f "$jsonl" ]; then
    fail_count=$(jq -s --arg target "$target" \
      '[.[] | select(.mode == "hostaudit" and .target == $target and .title == "SSH PermitRootLogin yes")] | length' \
      "$jsonl")
  fi

  if [ "$fail_count" -eq 0 ]; then
    passed=1
  else
    passed=0
  fi
  score_pct=$(( passed * 100 / total_checks ))

  jq -n --argjson total_checks "$total_checks" --argjson passed "$passed" --argjson score_pct "$score_pct" \
    '{total_checks: $total_checks, passed: $passed, score_pct: $score_pct}' \
    > "${loot_dir}/score.json"
}
