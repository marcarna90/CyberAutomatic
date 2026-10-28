# shellcheck shell=bash
# modes/bruteforce.sh — opt-in, double-gated credential testing.
# Never implied by any other mode (mass*/full never call this). Requires
# --allow-bruteforce on top of --i-am-authorized; this file re-checks the
# former itself as defense-in-depth even when called directly, bypassing
# the entrypoint. No wordlists are bundled — the caller always supplies
# --userlist/--passlist paths of their own.

_cyberauto_bf_opt_value() {
  local opts="$1" flag="$2" i
  local -a opt_arr
  read -ra opt_arr <<< "$opts"
  for i in "${!opt_arr[@]}"; do
    if [ "${opt_arr[$i]}" = "$flag" ]; then
      echo "${opt_arr[$((i + 1))]:-}"
      return 0
    fi
  done
}

# mode_bruteforce_run <target> <workspace_path> <opts>
mode_bruteforce_run() {
  local target="$1" workspace_path="$2" opts="$3"

  if [[ "$opts" != *"--allow-bruteforce"* ]]; then
    echo "ERROR: bruteforce requires --allow-bruteforce" >&2
    return 1
  fi

  local service
  service=$(_cyberauto_bf_opt_value "$opts" "--service")
  case "$service" in
    ssh|ftp|http|rdp|smb) ;;
    *)
      echo "ERROR: unsupported service '${service}'" >&2
      return 1
      ;;
  esac

  local userlist passlist
  userlist=$(_cyberauto_bf_opt_value "$opts" "--userlist")
  passlist=$(_cyberauto_bf_opt_value "$opts" "--passlist")
  if [ ! -f "$userlist" ] || [ ! -f "$passlist" ]; then
    echo "ERROR: wordlist not found" >&2
    return 1
  fi

  local backend
  backend=$(_cyberauto_bf_opt_value "$opts" "--backend")
  backend="${backend:-ncrack}"

  if [ "$backend" = "netexec" ] && [ "$service" != "smb" ]; then
    echo "ERROR: netexec backend only supports --service smb" >&2
    return 1
  fi

  local log_path loot_dir out_file
  log_path="${workspace_path}/logs/bruteforce.log"
  loot_dir="${workspace_path}/loot/bruteforce"
  out_file="${loot_dir}/${backend}.txt"

  if ! deps::require "$backend"; then
    echo "ERROR: bruteforce: ${backend} is required but not found" >&2
    echo "ERROR: bruteforce: ${backend} is required but not found" >> "$log_path"
    return 1
  fi

  mkdir -p "$loot_dir"

  case "$backend" in
    ncrack)
      ncrack -p "$service" -U "$userlist" -P "$passlist" "$target" > "$out_file" 2>> "$log_path"
      ;;
    netexec)
      netexec "$service" "$target" -u "$userlist" -p "$passlist" > "$out_file" 2>> "$log_path"
      ;;
  esac

  local line
  while IFS= read -r line; do
    if [[ "$line" == *"Discovered credentials"* ]] || [[ "$line" == *"Pwn3d!"* ]]; then
      findings::add "$workspace_path" "bruteforce" "$target" "critical" \
        "Valid credentials found (${service})" \
        "$line" \
        "Rotate the exposed credential immediately and enforce stronger authentication"
    fi
  done < "$out_file"
}
