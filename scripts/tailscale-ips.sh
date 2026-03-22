#!/usr/bin/env bash
# tailscale-ips.sh — Tailscale IP map for Shell of Nine nodes
# Fill in your actual 100.x.x.x IPs from: tailscale status
# Used by swarm-bootstrap.sh --tailscale and the GitHub Actions workflow

declare -A TAILSCALE_IPS=(
    [aurora-continuum]=""    # Phex — fill in
    [halycon-vector]=""      # Cyon — fill in
    [logos-prime]=""         # Lux — fill in
    [delta-wood]=""          # Verse — fill in
    [aletheia-core]=""       # Theia — fill in
    [ashfall-haven]=""       # Exo — fill in
    [elven-path]=""          # Orin — fill in
    [best-willow]=""         # Aster — fill in
)

get_tailscale_ip() {
    local host="$1"
    echo "${TAILSCALE_IPS[$host]:-}"
}

# If called directly, print the map
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for host in "${!TAILSCALE_IPS[@]}"; do
        ip="${TAILSCALE_IPS[$host]}"
        echo "$host: ${ip:-<not set>}"
    done
fi
