#!/usr/bin/env bash
set -euo pipefail

VIP=192.168.1.100
SAM=192.168.1.101
CLOVER=192.168.1.102
ALEX=192.168.1.103
MANDY=192.168.1.104

talosctl -n $VIP etcd members

talhelper genconfig

review_and_apply() {
    local name="$1"
    local ip="$2"
    local gen_file="clusterconfig/woohp-$name.yaml"
    local live_file
    live_file="$(mktemp)"
    trap 'rm -f "$live_file"' RETURN

    # Compare against the machine config actually persisted on the node itself
    talosctl -n "$ip" -e "$ip" get machineconfig -o yaml 2>/dev/null \
        | yq 'select(.metadata.id == "persistent") | .spec' -r > "$live_file"

    echo "=========================================="
    echo "=== Reviewing $(echo "$name" | tr '[:lower:]' '[:upper:]') Node Configuration (live vs generated) ==="
    echo "=========================================="
    diff --color -u "$live_file" "$gen_file" || true
    echo ""
    read -p "Apply configuration to $name node? (y/n): " CONFIRMATION

    if [[ "$CONFIRMATION" == "y" ]]; then
        talosctl apply-config -e "$ip" -n "$ip" --file "$gen_file"
        echo "✅ $name configuration applied"
    else
        echo "❌ $name configuration skipped"
    fi
    echo ""
}

review_and_apply sam "$SAM"
review_and_apply clover "$CLOVER"
review_and_apply alex "$ALEX"
review_and_apply mandy "$MANDY"

talosctl -n $VIP etcd members
