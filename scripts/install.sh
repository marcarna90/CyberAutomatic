#!/usr/bin/env bash
# scripts/install.sh — detects the distro's package manager and installs
# CyberAutomatic's required and optional external tools. Nothing here is
# bundled in the repo; this only drives the system package manager.
set -uo pipefail

REQUIRED_TOOLS="jq nmap"
OPTIONAL_TOOLS="masscan whatweb httpx wafw00f nikto ffuf gowitness nuclei testssl.sh sslscan amass subfinder theharvester ncrack netexec lynis pandoc"

if command -v apt-get >/dev/null 2>&1; then
  PM="apt-get"
  INSTALL_CMD="apt-get install -y"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
  INSTALL_CMD="pacman -S --noconfirm"
else
  echo "ERROR: unsupported distro, install manually: ${REQUIRED_TOOLS} ${OPTIONAL_TOOLS}" >&2
  exit 1
fi

echo "Installing required tools via ${PM}: ${REQUIRED_TOOLS}"
# shellcheck disable=SC2086
if ! $INSTALL_CMD $REQUIRED_TOOLS; then
  echo "ERROR: failed to install required tools (${REQUIRED_TOOLS})" >&2
  exit 1
fi

for tool in $OPTIONAL_TOOLS; do
  echo "Installing optional tool: ${tool}"
  # shellcheck disable=SC2086
  if ! $INSTALL_CMD "$tool" >/dev/null 2>&1; then
    echo "optional: install ${tool} manually"
  fi
done
