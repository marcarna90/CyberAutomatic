#!/usr/bin/env bash
# lib/report.sh — renders findings.jsonl into a Markdown/HTML report via
# simple {{PLACEHOLDER}} substitution (no eval, no sed regex on free text).

# report::generate <workspace_path> <template_path> <row_template_path> <output_path>
# Returns 1 if <workspace_path>/findings.jsonl does not exist.
report::generate() {
  local workspace_path="$1" template_path="$2" row_template_path="$3" output_path="$4"
  local jsonl
  jsonl="${workspace_path}/findings.jsonl"

  if [ ! -f "$jsonl" ]; then
    echo "ERROR: no findings.jsonl in ${workspace_path}" >&2
    return 1
  fi

  local row_template rows count
  row_template="$(cat "$row_template_path")"
  rows=""
  count=0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local severity target title description recommendation row
    severity=$(jq -r '.severity' <<< "$line")
    target=$(jq -r '.target' <<< "$line")
    title=$(jq -r '.title' <<< "$line")
    description=$(jq -r '.description' <<< "$line")
    recommendation=$(jq -r '.recommendation' <<< "$line")

    row="$row_template"
    row="${row//\{\{SEVERITY\}\}/$severity}"
    row="${row//\{\{TARGET\}\}/$target}"
    row="${row//\{\{TITLE\}\}/$title}"
    row="${row//\{\{DESCRIPTION\}\}/$description}"
    row="${row//\{\{RECOMMENDATION\}\}/$recommendation}"

    rows="${rows}${row}"$'\n'
    count=$((count + 1))
  done < "$jsonl"

  local out generated_at
  out="$(cat "$template_path")"
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  out="${out//\{\{GENERATED_AT\}\}/$generated_at}"
  out="${out//\{\{FINDING_COUNT\}\}/$count}"
  out="${out//\{\{FINDINGS_ROWS\}\}/$rows}"

  printf '%s\n' "$out" > "$output_path"
}
