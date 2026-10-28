# shellcheck shell=bash
# modes/vulnscan.sh — vulnerability scan: nmap --script vuln (required),
# plus nuclei if present.

# mode_vulnscan_run <target> <workspace_path> <opts>
mode_vulnscan_run() {
  local target="$1" workspace_path="$2" opts="$3"
  : "$opts" # vulnscan takes no extra options in v1
  local log_path loot_dir nmap_out

  if ! deps::require "nmap"; then
    echo "ERROR: vulnscan: nmap is required but not found" >&2
    echo "ERROR: vulnscan: nmap is required but not found" >> "${workspace_path}/logs/vulnscan.log"
    return 1
  fi

  log_path="${workspace_path}/logs/vulnscan.log"
  loot_dir="${workspace_path}/loot/vulnscan"
  nmap_out="${loot_dir}/nmap-vuln.txt"
  mkdir -p "$loot_dir"

  nmap --script vuln -sV "$target" > "$nmap_out" 2>> "$log_path"

  local line cve
  while IFS= read -r line; do
    if [[ "$line" =~ (CVE-[0-9]{4}-[0-9]+) ]]; then
      cve="${BASH_REMATCH[1]}"
      findings::add "$workspace_path" "vulnscan" "$target" "high" \
        "Possible vulnerability: ${cve}" \
        "Reported by nmap vuln scripts" \
        "Patch or mitigate ${cve}"
    fi
  done < "$nmap_out"

  if deps::check_or_warn "nuclei" "vulnscan" "$log_path"; then
    local nuclei_out severity title
    nuclei_out="${loot_dir}/nuclei.txt"
    nuclei -u "$target" > "$nuclei_out" 2>> "$log_path"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if [[ "$line" =~ \[(critical|high|medium|low|info)\] ]]; then
        severity="${BASH_REMATCH[1]}"
      else
        severity="medium"
      fi
      title="$line"
      findings::add "$workspace_path" "vulnscan" "$target" "$severity" \
        "Nuclei finding: ${title}" \
        "Reported by nuclei" \
        "Review and remediate the reported issue"
    done < "$nuclei_out"
  fi
}
