#!/usr/bin/env bash
# fix-hermes-path.sh — run on a remote node to install hermes CLI wrapper + PATH
set -euo pipefail

HERMES_AGENT="$HOME/.hermes/hermes-agent"
VENV_PYTHON="$HERMES_AGENT/venv/bin/python"
LOCAL_BIN="$HOME/.local/bin"
WRAPPER="$LOCAL_BIN/hermes"

# 1. Verify venv exists
if [[ ! -f "$VENV_PYTHON" ]]; then
    echo "ERROR: venv python not found at $VENV_PYTHON — run migration first"
    exit 1
fi

# 2. Create ~/.local/bin if missing
mkdir -p "$LOCAL_BIN"

# 3. Write/overwrite the hermes wrapper
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
HERMES_AGENT="$HOME/.hermes/hermes-agent"
exec "$HERMES_AGENT/venv/bin/python" -m hermes_cli.main "$@"
EOF
chmod +x "$WRAPPER"
echo "  ✓ wrapper written: $WRAPPER"

# 4. Add ~/.local/bin to PATH in ~/.bashrc if not already there
BASHRC="$HOME/.bashrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qF '.local/bin' "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# Hermes CLI" >> "$BASHRC"
    echo "$PATH_LINE" >> "$BASHRC"
    echo "  ✓ PATH updated in $BASHRC"
else
    echo "  ✓ .local/bin already in $BASHRC"
fi

# 5. Also add to ~/.profile for login shells that don't source ~/.bashrc
PROFILE="$HOME/.profile"
if ! grep -qF '.local/bin' "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# Hermes CLI" >> "$PROFILE"
    echo "$PATH_LINE" >> "$PROFILE"
    echo "  ✓ PATH updated in $PROFILE"
else
    echo "  ✓ .local/bin already in $PROFILE"
fi

# 6. Verify
export PATH="$LOCAL_BIN:$PATH"
if hermes --version 2>/dev/null | head -1; then
    echo "  ✓ hermes works"
else
    echo "  ✓ wrapper installed (open a new shell or: source ~/.bashrc)"
fi
