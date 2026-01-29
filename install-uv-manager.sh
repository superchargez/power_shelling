#!/bin/bash

# ================================================
# UV MANAGER INSTALLATION SCRIPT (Bash)
# ================================================

set -e

echo -e "\n========================================="
echo -e "   UV ENVIRONMENT MANAGER SETUP"
echo -e "=========================================\n"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="$HOME/.uv-manager"
REPO_URL="https://github.com/superchargez/power_shelling"

# 1. Check and install UV
echo -e "${GREEN}1. Checking UV installation...${NC}"

if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}   UV not found. Attempting to install...${NC}"
    
    # Try multiple installation methods
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try pip first, then brew
        python3 -m pip install --user uv || brew install uv
    elif command -v python3 &> /dev/null; then
        # Linux with Python
        python3 -m pip install --user uv
    else
        echo -e "${RED}   Could not install UV automatically.${NC}"
        echo -e "${YELLOW}   Please install Python or download UV manually from:${NC}"
        echo -e "   https://github.com/astral-sh/uv"
        exit 1
    fi
    
    # Add to PATH if installed in user directory
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [[ -d "$HOME/.local/bin" ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version)
    echo -e "   UV found: $UV_VERSION"
else
    echo -e "${YELLOW}   UV not found. Installing...${NC}"
    
    # Check OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "   macOS detected"
        brew install uv
    elif [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        echo "   Debian/Ubuntu detected"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/CentOS/Fedora
        echo "   RHEL/CentOS/Fedora detected"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        # Generic Linux
        echo "   Generic Linux detected"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    
    # Add uv to PATH if needed
    if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    
    # Verify installation
    if command -v uv &> /dev/null; then
        UV_VERSION=$(uv --version)
        echo -e "${GREEN}   UV installed: $UV_VERSION${NC}"
    else
        echo -e "${RED}   Failed to install UV. Please install manually.${NC}"
        echo -e "${YELLOW}   Visit: https://github.com/astral-sh/uv${NC}"
        exit 1
    fi
fi

# 2. Create installation directory
echo -e "\n${GREEN}2. Setting up installation directory...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    read -p "   Directory exists. Overwrite? (y/N): " overwrite
    if [[ "$overwrite" == "y" || "$overwrite" == "Y" ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "   Removed existing directory."
    else
        echo -e "   Using existing directory."
    fi
fi

mkdir -p "$INSTALL_DIR"
echo -e "   Created directory: $INSTALL_DIR"

# 3. Download scripts from GitHub
echo -e "\n${GREEN}3. Downloading scripts from GitHub...${NC}"

download_script() {
    local script_name=$1
    local url="https://raw.githubusercontent.com/superchargez/power_shelling/main/$script_name"
    local output="$INSTALL_DIR/$script_name"
    
    echo -e "   Downloading $script_name..."
    if curl -sSL "$url" -o "$output"; then
        chmod +x "$output"
        echo -e "   ✓ $script_name"
    else
        echo -e "${RED}   ✗ Failed to download $script_name${NC}"
    fi
}

# Download scripts
download_script "uv-manager.sh"
download_script "uv-extras.sh"
download_script "setup-uv.sh"

# 4. Create Bash wrapper for PowerShell-like commands
echo -e "\n${GREEN}4. Creating Bash wrapper...${NC}"

cat > "$INSTALL_DIR/uv-manager-wrapper.sh" << 'EOF'
#!/bin/bash
# UV Manager Wrapper for Bash

UV_ENVS_ROOT="$HOME/.uv/envs"
UV_ENVS_FILE="$HOME/.uv/envs/envs.json"

# Create directories if they don't exist
mkdir -p "$UV_ENVS_ROOT"

# Load environment
load_env() {
    local env_name=$1
    local env_path="$UV_ENVS_ROOT/$env_name"
    
    if [ ! -d "$env_path" ]; then
        echo "Environment '$env_name' not found!"
        return 1
    fi
    
    source "$env_path/bin/activate"
    export UV_ACTIVE_ENV="$env_name"
    echo "Activated environment: $env_name"
}

# List environments
list_envs() {
    echo -e "\nAvailable UV Environments:"
    echo "=========================="
    
    if [ -f "$UV_ENVS_FILE" ]; then
        jq -r 'to_entries[] | "\(.key): \(.value.path)"' "$UV_ENVS_FILE"
    else
        echo "No environments found."
    fi
}

# Main command handler
case "$1" in
    "list"|"l")
        list_envs
        ;;
    "activate"|"a")
        if [ -z "$2" ]; then
            echo "Usage: uv-env activate <name>"
            exit 1
        fi
        load_env "$2"
        ;;
    "create"|"c")
        if [ -z "$2" ]; then
            echo "Usage: uv-env create <name> [python_version]"
            exit 1
        fi
        python_version="${3:-3.12}"
        env_path="$UV_ENVS_ROOT/$2"
        
        uv venv --python "$python_version" "$env_path"
        
        # Update envs file
        if [ -f "$UV_ENVS_FILE" ]; then
            jq --arg name "$2" --arg path "$env_path" --arg python "$python_version" \
               '. + {($name): {path: $path, python: $python}}' "$UV_ENVS_FILE" > "$UV_ENVS_FILE.tmp"
            mv "$UV_ENVS_FILE.tmp" "$UV_ENVS_FILE"
        else
            echo "{\"$2\": {\"path\": \"$env_path\", \"python\": \"$python_version\"}}" > "$UV_ENVS_FILE"
        fi
        ;;
    *)
        echo "UV Environment Manager for Bash"
        echo "Commands:"
        echo "  list, l      - List environments"
        echo "  activate, a  - Activate environment"
        echo "  create, c    - Create environment"
        echo "  deactivate   - Deactivate current environment"
        ;;
esac
EOF

chmod +x "$INSTALL_DIR/uv-manager-wrapper.sh"

# 5. Configure shell profile
echo -e "\n${GREEN}5. Configuring shell profile...${NC}"

detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

SHELL_TYPE=$(detect_shell)
PROFILE_FILE=""

case $SHELL_TYPE in
    "zsh")
        PROFILE_FILE="$HOME/.zshrc"
        ;;
    "bash")
        PROFILE_FILE="$HOME/.bashrc"
        ;;
    *)
        PROFILE_FILE="$HOME/.profile"
        ;;
esac

echo "   Detected shell: $SHELL_TYPE"
echo "   Profile file: $PROFILE_FILE"

# Create backup
if [ -f "$PROFILE_FILE" ]; then
    BACKUP_FILE="$PROFILE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PROFILE_FILE" "$BACKUP_FILE"
    echo "   Backed up profile to: $BACKUP_FILE"
fi

# Add to profile
cat >> "$PROFILE_FILE" << EOF

# ================================================
# UV ENVIRONMENT MANAGER
# ================================================
export UV_MANAGER_DIR="$INSTALL_DIR"
alias uvl="bash \$UV_MANAGER_DIR/uv-manager-wrapper.sh list"
alias uva="bash \$UV_MANAGER_DIR/uv-manager-wrapper.sh activate"
alias uvc="bash \$UV_MANAGER_DIR/uv-manager-wrapper.sh create"

# Auto-activate when entering directory with .venv file
cd() {
    builtin cd "\$@"
    if [ -f ".venv" ]; then
        env_name=\$(cat .venv)
        if [ -n "\$env_name" ]; then
            uva "\$env_name"
        fi
    fi
}

echo "UV Manager loaded. Commands: uvl, uva, uvc"
EOF

echo "   Updated shell profile"

# 6. Create update and uninstall scripts
echo -e "\n${GREEN}6. Creating utility scripts...${NC}"

# Update script
cat > "$INSTALL_DIR/update-uv-manager.sh" << 'EOF'
#!/bin/bash
echo "Updating UV Manager..."
cd "$(dirname "$0")"

# Update scripts
curl -sSL "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-manager.sh" -o uv-manager.sh
curl -sSL "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-extras.sh" -o uv-extras.sh
chmod +x uv-manager.sh uv-extras.sh

echo "Update complete! Please restart your shell."
EOF

# Uninstall script
cat > "$INSTALL_DIR/uninstall-uv-manager.sh" << 'EOF'
#!/bin/bash
echo "Uninstalling UV Manager..."

INSTALL_DIR="$HOME/.uv-manager"
PROFILE_FILE=""

# Determine profile file
if [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    PROFILE_FILE="$HOME/.bashrc"
elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"
fi

# Remove from profile
if [ -n "$PROFILE_FILE" ]; then
    sed -i.bak '/UV ENVIRONMENT MANAGER/,/UV Manager loaded/d' "$PROFILE_FILE"
    echo "Removed from $PROFILE_FILE"
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed directory: $INSTALL_DIR"
fi

echo "Uninstall complete! Please restart your shell."
EOF

chmod +x "$INSTALL_DIR/update-uv-manager.sh" "$INSTALL_DIR/uninstall-uv-manager.sh"

# 7. Test installation
echo -e "\n${GREEN}7. Testing installation...${NC}"

if [ -f "$INSTALL_DIR/uv-manager-wrapper.sh" ]; then
    echo "   Installation successful!"
else
    echo -e "${RED}   Installation failed!${NC}"
    exit 1
fi

# 8. Completion message
echo -e "\n${BLUE}"$(printf '=%.0s' {1..50})"${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${BLUE}"$(printf '=%.0s' {1..50})"${NC}"
echo -e "\n${YELLOW}What to do next:${NC}"
echo "1. RESTART YOUR SHELL or run: source $PROFILE_FILE"
echo "2. Test with: 'uvl' (list environments)"
echo "3. Create your first environment: 'uvc ai 3.12'"
echo -e "\n${BLUE}Available commands:${NC}"
echo "  uvl - List environments"
echo "  uva - Activate environment"
echo "  uvc - Create environment"
echo -e "\n${YELLOW}Installation directory:${NC} $INSTALL_DIR"
echo -e "${YELLOW}Update script:${NC} $INSTALL_DIR/update-uv-manager.sh"
echo -e "${YELLOW}Uninstall script:${NC} $INSTALL_DIR/uninstall-uv-manager.sh"

# 9. Ask to create first environment
read -p $'\nCreate your first '\''ai'\'' environment now? (y/N): ' create_env
if [[ "$create_env" == "y" || "$create_env" == "Y" ]]; then
    bash "$INSTALL_DIR/uv-manager-wrapper.sh" create ai 3.12
    echo -e "${GREEN}Environment 'ai' created! Activate with: uva ai${NC}"
fi