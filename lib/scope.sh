#!/usr/bin/env bash
# lib/scope.sh — authorization + allow-list guard.
# Every offensive action must pass scope::check before touching the network.

# scope::_ip_to_int <ipv4> — prints the IPv4 address as a 32-bit integer.
scope::_ip_to_int() {
  local ip="$1" a b c d
  IFS='.' read -r a b c d <<< "$ip"
  echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# scope::cidr_match <ip> <cidr>
# Returns 0 if <ip> is inside <cidr> (A.B.C.D/N), 1 otherwise.
scope::cidr_match() {
  local ip="$1" cidr="$2" net mask_bits ip_int net_int mask
  net="${cidr%/*}"
  mask_bits="${cidr#*/}"
  ip_int=$(scope::_ip_to_int "$ip")
  net_int=$(scope::_ip_to_int "$net")
  if [ "$mask_bits" -eq 0 ]; then
    mask=0
  else
    mask=$(( (0xFFFFFFFF << (32 - mask_bits)) & 0xFFFFFFFF ))
  fi
  if [ $(( ip_int & mask )) -eq $(( net_int & mask )) ]; then
    return 0
  fi
  return 1
}

# scope::check <target> <allowed_targets_csv> <authorized_flag>
# Returns 0 if allowed, prints to stderr and returns:
#   1 — authorized_flag is not the literal string "1"
#   2 — target matches no CIDR/host in allowed_targets_csv
scope::check() {
  local target="$1" allowed_csv="$2" authorized_flag="$3"
  local entry

  if [ "$target" = "localhost" ]; then
    return 0
  fi

  if [ "$authorized_flag" != "1" ]; then
    echo "ERROR: not authorized (pass --i-am-authorized)" >&2
    return 1
  fi

  IFS=',' read -ra entries <<< "$allowed_csv"
  for entry in "${entries[@]}"; do
    if [[ "$entry" == */* ]]; then
      if scope::cidr_match "$target" "$entry"; then
        return 0
      fi
    elif [ "$entry" = "$target" ]; then
      return 0
    fi
  done

  echo "ERROR: target '${target}' is outside CYBERAUTO_ALLOWED_TARGETS" >&2
  return 2
}
