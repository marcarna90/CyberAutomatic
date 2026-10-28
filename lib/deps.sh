#!/usr/bin/env bash
# lib/deps.sh — external tool availability checks.

# deps::require <tool>
# Returns 0 if <tool> is on PATH, 1 otherwise. No output.
deps::require() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1
}

# deps::check_or_warn <tool> <mode_name> <log_path>
# If <tool> is missing, appends a WARN line to <log_path> and returns 1.
# Otherwise returns 0 with no output.
deps::check_or_warn() {
  local tool="$1" mode_name="$2" log_path="$3"
  if deps::require "$tool"; then
    return 0
  fi
  echo "WARN: ${mode_name}: ${tool} not found, skipping step" >> "$log_path"
  return 1
}
