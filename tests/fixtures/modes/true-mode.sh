mode_true-mode_run() {
  local target="$1" workspace_path="$2" opts="$3"
  echo "ran true-mode on $target with opts [$opts]" > "$workspace_path/loot/true-mode.out"
  return 0
}
