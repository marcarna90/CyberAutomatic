# shellcheck shell=bash
# modes/hostaudit.sh — defensive host audit. target is always "localhost"
# (scope::check short-circuits it to always allowed).

_cyberauto_ha_opt_value() {
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

# mode_hostaudit_run <target> <workspace_path> <opts>
mode_hostaudit_run() {
  local target="$1" workspace_path="$2" opts="$3"
  local log_path loot_dir
  log_path="${workspace_path}/logs/hostaudit.log"
  loot_dir="${workspace_path}/loot/hostaudit"
  mkdir -p "$loot_dir"

  local sshd_config
  sshd_config=$(_cyberauto_ha_opt_value "$opts" "--sshd-config")
  sshd_config="${sshd_config:-/etc/ssh/sshd_config}"

  if [ -f "$sshd_config" ] && grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "$sshd_config"; then
    findings::add "$workspace_path" "hostaudit" "$target" "high" \
      "SSH PermitRootLogin yes" \
      "sshd_config at ${sshd_config} permits direct root login over SSH" \
      "Set PermitRootLogin no and use sudo for privileged access"
  fi

  local check_paths
  check_paths=$(_cyberauto_ha_opt_value "$opts" "--check-paths")
  if [ -n "$check_paths" ]; then
    local -a paths
    IFS=',' read -ra paths <<< "$check_paths"
    local path perm digit
    for path in "${paths[@]}"; do
      [ -e "$path" ] || continue
      perm=$(stat -c '%a' "$path" 2>/dev/null)
      digit="${perm: -1}"
      if [ -n "$digit" ] && (( (8#$digit) & 2 )); then
        findings::add "$workspace_path" "hostaudit" "$target" "medium" \
          "World-writable path: ${path}" \
          "Checked path is writable by others" \
          "Remove world-write permission (chmod o-w)"
      fi
    done
  fi

  if deps::check_or_warn "lynis" "hostaudit" "$log_path"; then
    lynis audit system > "${loot_dir}/lynis.txt" 2>> "$log_path"
  fi
}
