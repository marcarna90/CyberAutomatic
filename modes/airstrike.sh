# shellcheck shell=bash
# modes/airstrike.sh — fast single-pass recon over every line of a target file.

# mode_airstrike_run <target_file_path> <workspace_path> <opts>
mode_airstrike_run() {
  local target_file="$1" workspace_path="$2" opts="$3"
  local log_path="${workspace_path}/logs/airstrike.log"
  local target status
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    if mode_recon_run "$target" "$workspace_path" "$opts"; then
      status=0
    else
      status=$?
    fi
    if [ "$status" -ne 0 ]; then
      echo "${target}: recon exited ${status}" >> "$log_path"
    fi
  done < "$target_file"
}
