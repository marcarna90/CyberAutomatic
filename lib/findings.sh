#!/usr/bin/env bash
# lib/findings.sh — structured findings storage (one JSON object per line).

# findings::add <workspace_path> <mode> <target> <severity> <title> <description> <recommendation>
# Appends one JSON object to <workspace_path>/findings.jsonl.
# Returns 1 without writing if <severity> is not info|low|medium|high|critical.
findings::add() {
  local workspace_path="$1" mode="$2" target="$3" severity="$4"
  local title="$5" description="$6" recommendation="$7"

  case "$severity" in
    info|low|medium|high|critical) ;;
    *)
      echo "ERROR: invalid severity '${severity}'" >&2
      return 1
      ;;
  esac

  jq -c -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg mode "$mode" \
    --arg target "$target" \
    --arg severity "$severity" \
    --arg title "$title" \
    --arg description "$description" \
    --arg recommendation "$recommendation" \
    '{ts: $ts, mode: $mode, target: $target, severity: $severity, title: $title, description: $description, recommendation: $recommendation}' \
    >> "${workspace_path}/findings.jsonl"
}

# findings::count <workspace_path> <severity>
# Prints the number of findings with the given severity.
findings::count() {
  local workspace_path="$1" severity="$2" jsonl
  jsonl="${workspace_path}/findings.jsonl"
  if [ ! -f "$jsonl" ]; then
    echo 0
    return 0
  fi
  jq -s --arg sev "$severity" '[.[] | select(.severity == $sev)] | length' "$jsonl"
}
