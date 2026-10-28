#!/usr/bin/env bash
# scripts/schedule.sh <alias> <daily|weekly|monthly> — prints the crontab
# entry that would repeat a workspace's last recorded run (see cyberauto
# --rerun), and installs it into the user's crontab only after an explicit
# y/Y confirmation. Never touches the real crontab otherwise.
set -uo pipefail

ALIAS="${1:-}"
FREQUENCY="${2:-}"

case "$FREQUENCY" in
  daily) PREFIX="@daily" ;;
  weekly) PREFIX="@weekly" ;;
  monthly) PREFIX="@monthly" ;;
  *)
    echo "ERROR: unknown frequency '${FREQUENCY}'" >&2
    exit 1
    ;;
esac

CRON_LINE="${PREFIX} cyberauto -w ${ALIAS} --rerun --i-am-authorized"
echo "Proposed crontab entry:"
echo "${CRON_LINE}"

read -r -p "Add this to your crontab? [y/N] " answer
case "$answer" in
  y|Y)
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "Added to crontab."
    ;;
  *)
    echo "Not added."
    ;;
esac
