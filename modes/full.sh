# shellcheck shell=bash
# modes/full.sh — recon + web + vulnscan + osint, in sequence, for every
# target in the file. Never implies bruteforce — that always needs its own
# explicit --allow-bruteforce flag regardless of mode.

# mode_full_run <target_file_path> <workspace_path> <opts>
mode_full_run() {
  local target_file="$1" workspace_path="$2" opts="$3"
  local log_path="${workspace_path}/logs/full.log"
  local target status mode_fn
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    for mode_fn in mode_recon_run mode_web_run mode_vulnscan_run mode_osint_run; do
      if "$mode_fn" "$target" "$workspace_path" "$opts"; then
        status=0
      else
        status=$?
      fi
      if [ "$status" -ne 0 ]; then
        echo "${target}: ${mode_fn} exited ${status}" >> "$log_path"
      fi
    done
  done < "$target_file"
}
