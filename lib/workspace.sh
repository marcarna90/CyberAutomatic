#!/usr/bin/env bash
# lib/workspace.sh — workspace CRUD (loot/logs/reports per scan session).

# workspace::create <alias> <base_dir>
# Idempotent: creates the workspace if absent, reuses it (untouched) if
# present. Prints the absolute workspace path to stdout. Always returns 0.
workspace::create() {
  local alias="$1" base_dir="$2" path
  path="$(cd "$base_dir" && pwd)/${alias}"
  mkdir -p "$path/loot" "$path/logs" "$path/reports"
  if [ ! -f "$path/workspace.meta" ]; then
    {
      echo "alias=${alias}"
      echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$path/workspace.meta"
  fi
  echo "$path"
  return 0
}

# workspace::list <base_dir>
# Prints one alias per line for every subdirectory containing workspace.meta.
workspace::list() {
  local base_dir="$1" dir
  for dir in "$base_dir"/*/; do
    [ -f "${dir}workspace.meta" ] || continue
    basename "${dir%/}"
  done
}

# workspace::delete <alias> <base_dir>
workspace::delete() {
  local alias="$1" base_dir="$2" path
  path="${base_dir}/${alias}"
  if [ ! -d "$path" ]; then
    echo "ERROR: workspace '${alias}' does not exist" >&2
    return 1
  fi
  rm -rf "$path"
}

# workspace::export <alias> <base_dir> <dest_tar_path>
workspace::export() {
  local alias="$1" base_dir="$2" dest_tar_path="$3"
  if [ ! -d "${base_dir}/${alias}" ]; then
    echo "ERROR: workspace '${alias}' does not exist" >&2
    return 1
  fi
  tar czf "$dest_tar_path" -C "$base_dir" "$alias"
}

# workspace::reimport <src_tar_path> <base_dir>
workspace::reimport() {
  local src_tar_path="$1" base_dir="$2"
  if [ ! -f "$src_tar_path" ]; then
    echo "ERROR: archive '${src_tar_path}' not found" >&2
    return 1
  fi
  tar xzf "$src_tar_path" -C "$base_dir"
}
