#!/usr/bin/env bash
# install-runner.sh — Install GitHub Actions self-hosted runner on best-willow
#
# Run this ONCE on best-willow. After this, migrations can be triggered
# from any browser (including phone) via github.com → Actions → Run workflow.
#
# Usage:
#   bash scripts/install-runner.sh
#
# Requirements:
#   - gh CLI installed and authenticated (gh auth status)
#   - Running as wbic16 on best-willow
#   - Internet access to github.com

set -euo pipefail

REPO="wbic16/mirrorborn"
RUNNER_DIR="${HOME}/actions-runner"
RUNNER_VERSION="2.323.0"
RUNNER_ARCH="linux-x64"
RUNNER_TAR="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TAR}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }

# ── Preflight ──────────────────────────────────────────────────────────────────
info "Checking gh auth..."
if ! gh auth status &>/dev/null; then
    echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
    exit 1
fi
success "gh auth OK"

info "Fetching runner registration token..."

# Try gh CLI first. If the token lacks Actions scope, fall back to prompting.
REG_TOKEN=$(gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO}/actions/runners/registration-token" \
    --jq '.token' 2>/dev/null || true)

if [[ -z "$REG_TOKEN" ]]; then
    warn "gh CLI token lacks 'Actions' write scope."
    warn "Get a token manually:"
    warn "  1. https://github.com/settings/tokens/new"
    warn "  2. Check: repo > Actions (write) — OR use a fine-grained token with Actions: write"
    warn "  3. Run:  gh auth refresh -s workflow,admin:repo_hook"
    warn "     OR:   export GH_TOKEN=<your-token>"
    warn ""
    warn "Alternatively, get the token from:"
    warn "  https://github.com/${REPO}/settings/actions/runners/new"
    warn "  (copy the token shown in the config.sh --token line)"
    echo ""
    read -r -p "Paste your runner registration token: " REG_TOKEN
    if [[ -z "$REG_TOKEN" ]]; then
        echo "ERROR: no token provided" >&2
        exit 1
    fi
fi
success "Registration token acquired"

# ── Download runner ────────────────────────────────────────────────────────────
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -f "run.sh" ]]; then
    info "Downloading runner v${RUNNER_VERSION}..."
    curl -sSfL "$RUNNER_URL" -o "$RUNNER_TAR"
    tar xzf "$RUNNER_TAR"
    rm "$RUNNER_TAR"
    success "Runner downloaded and extracted"
else
    success "Runner binary already present — skipping download"
fi

# ── Configure ─────────────────────────────────────────────────────────────────
if [[ ! -f ".runner" ]]; then
    info "Configuring runner..."
    ./config.sh \
        --url "https://github.com/${REPO}" \
        --token "$REG_TOKEN" \
        --name "best-willow" \
        --labels "best-willow,mirrorborn,shell-of-nine" \
        --work "_work" \
        --unattended \
        --replace
    success "Runner configured"
else
    warn "Runner already configured (.runner exists) — skipping config"
    warn "To reconfigure: rm ${RUNNER_DIR}/.runner && re-run this script"
fi

# ── Install as systemd user service ───────────────────────────────────────────
info "Installing as systemd user service..."

SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/github-runner.service"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=GitHub Actions Self-Hosted Runner — best-willow
After=network.target

[Service]
Type=simple
WorkingDirectory=${RUNNER_DIR}
ExecStart=${RUNNER_DIR}/run.sh
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal
Environment=HOME=${HOME}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable github-runner.service
systemctl --user start github-runner.service
sleep 2

if systemctl --user is-active --quiet github-runner.service; then
    success "github-runner.service is running"
else
    echo "ERROR: runner service failed to start. Check: journalctl --user -u github-runner -n 30" >&2
    exit 1
fi

# ── Verify registration ────────────────────────────────────────────────────────
info "Verifying runner registered with GitHub..."
sleep 3
REGISTERED=$(gh api "/repos/${REPO}/actions/runners" \
    --jq '.runners[] | select(.name=="best-willow") | .status' 2>/dev/null || echo "")

if [[ "$REGISTERED" == "online" ]]; then
    success "Runner 'best-willow' is online at github.com/${REPO}/actions/runners"
else
    warn "Runner status: '${REGISTERED:-unknown}' — may take a moment to appear"
    warn "Check: https://github.com/${REPO}/settings/actions/runners"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Runner installed and running.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  To trigger a migration from your phone:"
echo "  1. Open https://github.com/${REPO}/actions"
echo "  2. Click 'Migrate Shell of Nine → Hermes'"
echo "  3. Click 'Run workflow'"
echo "  4. Choose nodes (or leave 'all') → Run"
echo ""
echo "  To view runner: https://github.com/${REPO}/settings/actions/runners"
echo "  To check logs:  journalctl --user -u github-runner -f"
echo ""
