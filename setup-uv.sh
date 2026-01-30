#!/bin/bash
# ================================================
# UNIX UNIVERSAL UV SETUP (Bash + Zsh)
# ================================================

INSTALL_DIR="$HOME/.uv-manager"
mkdir -p "$INSTALL_DIR"

# 1. Install UV
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
fi

# 2. Install Files (Local First)
if [ -f "./uv-manager.sh" ]; then
    cp "./uv-manager.sh" "$INSTALL_DIR/uv-manager.sh"
else
    curl -sSL "https://raw.githubusercontent.com/superchargez/power_shelling/dev/uv-manager.sh" -o "$INSTALL_DIR/uv-manager.sh"
fi
chmod +x "$INSTALL_DIR/uv-manager.sh"

# 3. Configure Profile
detect_profile() {
    if [[ "$SHELL" == *"zsh"* ]]; then echo "$HOME/.zshrc"; else echo "$HOME/.bashrc"; fi
}
PROFILE_FILE=$(detect_profile)

if ! grep -q "UV MANAGER START" "$PROFILE_FILE"; then
    cat >> "$PROFILE_FILE" << EOF

# >> UV MANAGER START
if [ -f "$INSTALL_DIR/uv-manager.sh" ]; then
    source "$INSTALL_DIR/uv-manager.sh"
fi
# >> UV MANAGER END
EOF
    echo "Updated $PROFILE_FILE"
fi

echo "SETUP COMPLETE! Please restart your terminal or run: source $PROFILE_FILE"