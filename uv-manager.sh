#!/bin/bash
# ================================================
# UV ENVIRONMENT MANAGER - v3.2 (Bash/Zsh)
# ================================================

# 1. CONFIGURATION
export UV_ENVS_ROOT="$HOME/.uv/envs"
export UV_ENVS_FILE="$UV_ENVS_ROOT/envs.json"

# Ensure directories exist
mkdir -p "$UV_ENVS_ROOT"

# 2. INTERNAL HELPERS
_uv_check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "\033[0;31mError: 'jq' is not installed.\033[0m Please install it to use UV Manager (e.g., sudo apt install jq or brew install jq)."
        return 1
    fi
}

# 3. CORE FUNCTIONS

uvl() { # Get-UvEnvList
    _uv_check_jq || return 1
    local prune=false
    if [[ "$1" == "-Prune" ]]; then prune=true; fi

    if [ ! -f "$UV_ENVS_FILE" ] || [ "$(jq 'length' "$UV_ENVS_FILE")" -eq 0 ]; then
        echo -e "\033[1;33mNo environments managed.\033[0m"
        return
    fi

    if [ "$prune" = true ]; then
        echo "Pruning missing environments..."
        local keys=$(jq -r 'keys[]' "$UV_ENVS_FILE")
        for key in $keys; do
            local path=$(jq -r ".\"$key\".path" "$UV_ENVS_FILE")
            if [ ! -d "$path" ]; then
                echo -e "  [PRUNING] $key (Folder missing)"
                local tmp=$(mktemp)
                jq "del(.\"$key\")" "$UV_ENVS_FILE" > "$tmp" && mv "$tmp" "$UV_ENVS_FILE"
            fi
        done
    fi

    echo -e "\n\033[0;36mUV Environments:\033[0m"
    echo -e "\033[0;36m----------------\033[0m"

    jq -r 'to_entries[] | "\(.key) \(.value.python) \(.value.path)"' "$UV_ENVS_FILE" | while read -r name python path; do
        local marker=" "
        if [[ "$VIRTUAL_ENV" == "$path" ]]; then marker="*"; fi
        
        local color="\033[0;90m" # Gray
        if [ ! -d "$path" ]; then color="\033[0;31m"; python="[MISSING]"; fi

        echo -e "\033[1;33m$marker $name\033[0m $color($python)\033[0m"
        echo -e "    \033[0;90m$path\033[0m"
    done
    echo ""
}

uvc() { # New-UvEnv
    _uv_check_jq || return 1
    local name=$1
    local python=${2:-"default"}
    
    if [ -z "$name" ]; then echo "Usage: uvc <name> [python_version]"; return 1; fi
    
    local target_path="$UV_ENVS_ROOT/$name"
    
    echo -e "\033[0;36mCreating '$name' (Python: $python)...\033[0m"
    
    if [[ "$python" == "default" ]]; then
        uv venv "$target_path"
    else
        uv venv --python "$python" "$target_path"
    fi

    if [ $? -eq 0 ]; then
        local created_at=$(date +%Y-%m-%dT%H:%M:%S)
        local tmp=$(mktemp)
        jq --arg name "$name" --arg path "$target_path" --arg py "$python" --arg date "$created_at" \
           '. + {($name): {path: $path, python: $py, created: $date}}' "$UV_ENVS_FILE" > "$tmp" && mv "$tmp" "$UV_ENVS_FILE"
        echo -e "\033[0;32mCreated. Activate with: uva $name\033[0m"
    fi
}

uva() { # Enter-UvEnv
    _uv_check_jq || return 1
    local name=$1
    if [ -z "$name" ]; then echo "Usage: uva <name>"; return 1; fi

    local path=$(jq -r ".\"$name\".path // empty" "$UV_ENVS_FILE")
    
    if [ -z "$path" ]; then
        echo -e "\033[0;31mEnv '$name' not found.\033[0m"
        return 1
    fi

    if [ -f "$path/bin/activate" ]; then
        if command -v deactivate &> /dev/null; then deactivate; fi
        source "$path/bin/activate"
        echo -e "\033[0;32mActivated $name\033[0m"
    else
        echo -e "\033[0;31mActivation script missing. Try 'uvl -Prune'.\033[0m"
    fi
}

uvr() { # Remove-UvEnv
    _uv_check_jq || return 1
    local name=$1
    if [ -z "$name" ]; then echo "Usage: uvr <name>"; return 1; fi

    local path=$(jq -r ".\"$name\".path // empty" "$UV_ENVS_FILE")
    if [ -z "$path" ]; then echo "Env not found."; return 1; fi

    if [[ "$VIRTUAL_ENV" == "$path" ]]; then
        echo "Please deactivate (uvx) before removing the active environment."
        return 1
    fi

    read -p "Delete '$name' and all files? (y/N): " confirm
    if [[ "$confirm" == [yY] ]]; then
        rm -rf "$path"
        local tmp=$(mktemp)
        jq "del(.\"$name\")" "$UV_ENVS_FILE" > "$tmp" && mv "$tmp" "$UV_ENVS_FILE"
        echo "Removed."
    fi
}

uvx() { # Exit-UvEnv
    if command -v deactivate &> /dev/null; then
        deactivate
    else
        echo "Not in a virtual environment."
    fi
}

uvu() { # Update-UvEnv
    local target_path=$VIRTUAL_ENV
    if [ -z "$target_path" ]; then echo "No active environment."; return 1; fi
    
    echo -e "\033[0;36mScanning updates...\033[0m"
    uv pip list --outdated
    uv pip install --upgrade $(uv pip list --format freeze | cut -d= -f1)
}

uve() { # Export-UvEnv
    local out=${1:-"requirements.txt"}
    uv pip freeze > "$out"
    echo "Exported to $out"
}

uvk() { # Clear-UvCache
    uv cache clean
}

# 4. TAB COMPLETION
_uv_manager_completions() {
    if [ ! -f "$UV_ENVS_FILE" ]; then return; fi
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local envs=$(jq -r 'keys[]' "$UV_ENVS_FILE")
    COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
}
complete -F _uv_manager_completions uva uvr

echo -e "\033[0;32mUV Manager v3.2 Loaded.\033[0m"