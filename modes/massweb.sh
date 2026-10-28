# shellcheck shell=bash
# modes/massweb.sh — mode_web_run over every line of a target file.

# mode_massweb_run <target_file_path> <workspace_path> <opts>
mode_massweb_run() {
  local target_file="$1" workspace_path="$2" opts="$3"
  local log_path="${workspace_path}/logs/massweb.log"
  local target status
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    if mode_web_run "$target" "$workspace_path" "$opts"; then
      status=0
    else
      status=$?
    fi
    if [ "$status" -ne 0 ]; then
      echo "${target}: web exited ${status}" >> "$log_path"
    fi
  done < "$target_file"
}
