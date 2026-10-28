# shellcheck shell=bash
# modes/port.sh — scan specific port(s) only; requires --ports <list> in opts.

# _cyberauto_record_open_ports <nmap_output_path> <workspace_path> <target> <mode>
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

# _cyberauto_opt_value <opts> <flag>
# Prints the value following <flag> in the space-separated <opts> string.
_cyberauto_opt_value() {
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

# mode_port_run <target> <workspace_path> <opts>
mode_port_run() {
  local target="$1" workspace_path="$2" opts="$3"
  local log_path loot_dir nmap_out ports

  if ! deps::require "nmap"; then
    echo "ERROR: port: nmap is required but not found" >&2
    return 1
  fi

  ports=$(_cyberauto_opt_value "$opts" "--ports")
  if [ -z "$ports" ]; then
    echo "ERROR: port mode requires --ports <list>" >&2
    return 1
  fi

  log_path="${workspace_path}/logs/port.log"
  loot_dir="${workspace_path}/loot/port"
  nmap_out="${loot_dir}/nmap.txt"
  mkdir -p "$loot_dir"
  nmap -p "$ports" -sV "$target" > "$nmap_out" 2>> "$log_path"
  _cyberauto_record_open_ports "$nmap_out" "$workspace_path" "$target" "port"
}
