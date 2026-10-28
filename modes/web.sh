# shellcheck shell=bash
# modes/web.sh — web recon/scan: whichever of whatweb/nikto/testssl.sh are
# present; skips any that are missing, fails only if none at all are found.

# mode_web_run <target> <workspace_path> <opts>
mode_web_run() {
  local target="$1" workspace_path="$2" opts="$3"
  : "$opts" # web takes no extra options in v1
  local log_path loot_dir ran_any
  log_path="${workspace_path}/logs/web.log"
  loot_dir="${workspace_path}/loot/web"
  ran_any=0

  if ! deps::require "whatweb" && ! deps::require "nikto" && ! deps::require "testssl.sh"; then
    echo "ERROR: web: no web tool available (whatweb, nikto, testssl.sh all missing)" >&2
    return 1
  fi

  mkdir -p "$loot_dir"

  if deps::check_or_warn "whatweb" "web" "$log_path"; then
    whatweb "$target" > "${loot_dir}/whatweb.txt" 2>> "$log_path"
    ran_any=1
  fi

  if deps::check_or_warn "nikto" "web" "$log_path"; then
    nikto -h "$target" > "${loot_dir}/nikto.txt" 2>> "$log_path"
    ran_any=1
    local line
    while IFS= read -r line; do
      case "$line" in
        "+ Target IP:"*|"+ Server:"*) continue ;;
        "+ "*)
          findings::add "$workspace_path" "web" "$target" "medium" \
            "Nikto finding: ${line#+ }" \
            "Reported by nikto" \
            "Review and remediate the reported issue"
          ;;
      esac
    done < "${loot_dir}/nikto.txt"
  fi

  if deps::check_or_warn "testssl.sh" "web" "$log_path"; then
    testssl.sh "$target" > "${loot_dir}/testssl.sh.txt" 2>> "$log_path"
    ran_any=1
    local tls_line
    while IFS= read -r tls_line; do
      if [[ "$tls_line" == *"NOT ok"* ]]; then
        findings::add "$workspace_path" "web" "$target" "low" \
          "Weak TLS configuration: $(echo "$tls_line" | xargs)" \
          "Reported by testssl.sh" \
          "Disable outdated protocol versions/ciphers"
      fi
    done < "${loot_dir}/testssl.sh.txt"
  fi

  : "$ran_any"
}
