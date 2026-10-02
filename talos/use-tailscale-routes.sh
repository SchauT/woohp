#!/usr/bin/env bash
set -euo pipefail

# When you're not on the home LAN, macOS prefers a local interface route over
# the Tailscale subnet route for 192.168.1.0/24 if your current network
# happens to use the same range — so talosctl/kubectl traffic to the nodes
# silently goes nowhere instead of through the tunnel.
# Run this once per remote session (before gen_and_apply_conf_to_all_nodes.sh)
# to pin the node IPs through Tailscale. Not needed, and not harmful to skip,
# when you're actually on the home LAN.

VIP=192.168.1.100
SAM=192.168.1.101
CLOVER=192.168.1.102
ALEX=192.168.1.103
MANDY=192.168.1.104

ACTION="${1:-add}"

TAILSCALE_IF=$(ifconfig | awk '
  /^utun[0-9]+:/ { iface=$1; sub(":", "", iface) }
  /inet 100\./ { print iface; exit }
')

if [[ -z "$TAILSCALE_IF" ]]; then
  echo "No Tailscale interface found (no utun with a 100.x address) — skipping, assuming you're on the home LAN." >&2
  exit 0
fi

for ip in "$VIP" "$SAM" "$CLOVER" "$ALEX" "$MANDY"; do
  case "$ACTION" in
    add)
      sudo route add -host "$ip" -interface "$TAILSCALE_IF" 2>&1 | grep -v "File exists" || true
      ;;
    down)
      sudo route delete -host "$ip" 2>&1 | grep -v "not in table" || true
      ;;
    *)
      echo "Usage: $0 [add|down]" >&2
      exit 1
      ;;
  esac
done

echo "Done ($ACTION) via $TAILSCALE_IF"
