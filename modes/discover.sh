# shellcheck shell=bash
# modes/discover.sh — host discovery only (no port scan, no findings).

# mode_discover_run <target> <workspace_path> <opts>
mode_discover_run() {
  local target="$1" workspace_path="$2" opts="$3"
  : "$opts" # discover takes no extra options in v1
  local log_path loot_dir nmap_out
  log_path="${workspace_path}/logs/discover.log"
  loot_dir="${workspace_path}/loot/discover"
  nmap_out="${loot_dir}/nmap.txt"

  if ! deps::require "nmap"; then
    echo "ERROR: discover: nmap is required but not found" >&2
    echo "ERROR: discover: nmap is required but not found" >> "$log_path"
    return 1
  fi

  mkdir -p "$loot_dir"
  nmap -sn "$target" > "$nmap_out" 2>> "$log_path"
}
