# shellcheck shell=bash
# modes/massport.sh — mode_port_run over every line of a target file.
# A failing target is logged and the batch continues (per spec: one
# target's failure never aborts the others).

# mode_massport_run <target_file_path> <workspace_path> <opts>
mode_massport_run() {
  local target_file="$1" workspace_path="$2" opts="$3"
  local log_path="${workspace_path}/logs/massport.log"
  local target status
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    if mode_port_run "$target" "$workspace_path" "$opts"; then
      status=0
    else
      status=$?
    fi
    if [ "$status" -ne 0 ]; then
      echo "${target}: port exited ${status}" >> "$log_path"
    fi
  done < "$target_file"
}
