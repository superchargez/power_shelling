#!/bin/bash
# ================================================
# UV MANAGER INSTALLATION SCRIPT (Bash/Zsh)
# ================================================

INSTALL_DIR="$HOME/.uv-manager"
BRANCH="dev"

echo -e "\n\033[0;36m========================================="
echo -e "   UV ENVIRONMENT MANAGER SETUP"
echo -e "=========================================\033[0m\n"

# 1. Install UV
if ! command -v uv &> /dev/null; then
    echo "Installing UV..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
fi

# 2. Dependency Check (jq)
if ! command -v jq &> /dev/null; then
    echo -e "\033[1;33mNote: 'jq' is required for the manager to work.\033[0m"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Suggestion: brew install jq"
    else
        echo "Suggestion: sudo apt install jq"
    fi
fi

# 3. Setup Directory & Files
mkdir -p "$INSTALL_DIR"

install_file() {
    local file=$1
    if [ -f "./$file" ]; then
        echo "Using local $file"
        cp "./$file" "$INSTALL_DIR/$file"
    else
        echo "Downloading $file..."
        curl -sSL "https://raw.githubusercontent.com/superchargez/power_shelling/$BRANCH/$file" -o "$INSTALL_DIR/$file"
    fi
    chmod +x "$INSTALL_DIR/$file"
}

install_file "uv-manager.sh"

# 4. Profile Configuration
SHELL_RC="$HOME/.bashrc"
[[ "$SHELL" == *"zsh"* ]] && SHELL_RC="$HOME/.zshrc"

echo "Updating $SHELL_RC..."
# Backup
cp "$SHELL_RC" "$SHELL_RC.backup.$(date +%Y%m%d)"

# Remove old block if exists
sed -i '/# >> UV MANAGER START/,/# >> UV MANAGER END/d' "$SHELL_RC"

# Append new block
cat >> "$SHELL_RC" << EOF

# >> UV MANAGER START
if [ -f "$INSTALL_DIR/uv-manager.sh" ]; then
    source "$INSTALL_DIR/uv-manager.sh"
fi
# >> UV MANAGER END
EOF

echo -e "\033[0;32mINSTALLATION COMPLETE!\033[0m"
echo -e "Please run: \033[1;37msource $SHELL_RC\033[0m"