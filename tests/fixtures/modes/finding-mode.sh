mode_finding-mode_run() {
  local target="$1" workspace_path="$2" opts="$3"
  findings::add "$workspace_path" "finding-mode" "$target" "info" "test finding" "d" "r"
}
