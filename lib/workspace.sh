#!/usr/bin/env bash
# lib/workspace.sh — workspace CRUD (loot/logs/reports per scan session).

# workspace::create <alias> <base_dir>
# Idempotent: creates the workspace if absent, reuses it (untouched) if
# present. Prints the absolute workspace path to stdout. Always returns 0.
workspace::create() {
  local alias="$1" base_dir="$2" path resolved_base
  mkdir -p "$base_dir"
  resolved_base="$(cd "$base_dir" && pwd)"
  if [ -z "$resolved_base" ]; then
    echo "ERROR: workspace::create: cannot resolve base directory '${base_dir}'" >&2
    return 1
  fi
  path="${resolved_base}/${alias}"
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

# workspace::record_last <workspace_path> <mode> <target> <is_file> <opts>
# Records the most recent run's config in workspace.meta, overwriting any
# previously recorded last_* fields (never duplicating them) so --rerun can
# repeat it later.
workspace::record_last() {
  local workspace_path="$1" mode="$2" target="$3" is_file="$4" opts="$5"
  local meta tmp
  meta="${workspace_path}/workspace.meta"
  tmp="${meta}.tmp"
  grep -v -E '^last_(mode|target|is_file|opts)=' "$meta" > "$tmp" 2>/dev/null || true
  {
    cat "$tmp" 2>/dev/null
    echo "last_mode=${mode}"
    echo "last_target=${target}"
    echo "last_is_file=${is_file}"
    echo "last_opts=${opts}"
  } > "$meta"
  rm -f "$tmp"
}

# workspace::last <workspace_path> <field>
# field is mode|target|is_file|opts. Prints the recorded value, or nothing
# if no run was ever recorded for this workspace.
workspace::last() {
  local workspace_path="$1" field="$2" meta
  meta="${workspace_path}/workspace.meta"
  [ -f "$meta" ] || return 0
  grep "^last_${field}=" "$meta" | tail -n1 | cut -d= -f2-
  return 0
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
