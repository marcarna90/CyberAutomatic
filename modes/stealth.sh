# shellcheck shell=bash
# modes/stealth.sh — quieter/slower scan: SYN stealth, reduced timing.

# _cyberauto_record_open_ports <nmap_output_path> <workspace_path> <target> <mode>
# Parses "PORT/proto open service" lines and records one info finding each.
_cyberauto_record_open_ports() {
  local nmap_out="$1" workspace_path="$2" target="$3" mode="$4"
  local line port_proto service
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+/(tcp|udp))[[:space:]]+open[[:space:]]+([^[:space:]]+) ]]; then
      port_proto="${BASH_REMATCH[1]}"
      service="${BASH_REMATCH[3]}"
      findings::add "$workspace_path" "$mode" "$target" "info" \
        "Open port ${port_proto} (${service})" \
        "Detected by nmap during ${mode}" \
        "Confirm this service is intended to be exposed"
    fi
  done < "$nmap_out"
}

# mode_stealth_run <target> <workspace_path> <opts>
mode_stealth_run() {
  local target="$1" workspace_path="$2" opts="$3"
  : "$opts" # stealth takes no extra options in v1
  local log_path loot_dir nmap_out
  log_path="${workspace_path}/logs/stealth.log"
  loot_dir="${workspace_path}/loot/stealth"
  nmap_out="${loot_dir}/nmap.txt"

  if ! deps::require "nmap"; then
    echo "ERROR: stealth: nmap is required but not found" >&2
    echo "ERROR: stealth: nmap is required but not found" >> "$log_path"
    return 1
  fi

  mkdir -p "$loot_dir"
  nmap -sS -T2 -sV "$target" > "$nmap_out" 2>> "$log_path"
  _cyberauto_record_open_ports "$nmap_out" "$workspace_path" "$target" "stealth"
}
