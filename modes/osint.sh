# shellcheck shell=bash
# modes/osint.sh — passive OSINT: crt.sh (via curl), subfinder, theHarvester.
# theHarvester only runs when opts contains --deep (kept off by default to
# stay fast); crt.sh and subfinder always run if their tool is available.

# mode_osint_run <target> <workspace_path> <opts>
mode_osint_run() {
  local target="$1" workspace_path="$2" opts="$3"
  local log_path loot_dir
  log_path="${workspace_path}/logs/osint.log"
  loot_dir="${workspace_path}/loot/osint"
  mkdir -p "$loot_dir"

  if deps::check_or_warn "curl" "osint" "$log_path"; then
    curl -s "https://crt.sh/?q=${target}&output=json" > "${loot_dir}/crtsh.txt" 2>> "$log_path"
  fi

  if deps::check_or_warn "subfinder" "osint" "$log_path"; then
    subfinder -d "$target" > "${loot_dir}/subfinder.txt" 2>> "$log_path"
    local sub
    while IFS= read -r sub; do
      [ -n "$sub" ] || continue
      findings::add "$workspace_path" "osint" "$target" "info" \
        "Discovered subdomain: ${sub}" \
        "Found via subfinder" \
        "Confirm this subdomain is intended to be public"
    done < "${loot_dir}/subfinder.txt"
  fi

  if [[ "$opts" == *"--deep"* ]]; then
    if deps::check_or_warn "theHarvester" "osint" "$log_path"; then
      theHarvester -d "$target" -b all > "${loot_dir}/theHarvester.txt" 2>> "$log_path"
    fi
  fi
}
