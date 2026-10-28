#!/usr/bin/env bash
# scripts/uninstall.sh — removes only this project's own workspace data
# (loot/logs/reports under workspaces/). Never touches system packages and
# never deletes anything without an explicit y/Y confirmation.
set -uo pipefail

WORKSPACE_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace-dir) WORKSPACE_DIR="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${SCRIPT_DIR}/workspaces}"

read -r -p "Delete all workspace data under ${WORKSPACE_DIR}? [y/N] " answer
case "$answer" in
  y|Y)
    find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} +
    echo "Workspace data removed."
    ;;
  *)
    echo "Aborted; nothing was deleted."
    ;;
esac
