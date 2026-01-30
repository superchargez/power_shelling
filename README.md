# ⚡ UV Environment Manager (v3.2)

![PowerShell](https://img.shields.io/badge/PowerShell-7.2+-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Bash/Zsh](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Cross-Platform](https://img.shields.io/badge/Platform-Win%20%7C%20macOS%20%7C%20Linux-lightgrey?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

> **Conda-like convenience, UV-level speed.**  
> A centralized management system for your Python environments. No more searching for hidden `.venv` folders—manage everything from one place with global aliases.

---

## ✨ Features

- 🗃️ **Centralized Registry**: Tracks all environments in `~/.uv/envs/envs.json`.
- 🚀 **Lightning Fast**: Powered by [Astral's UV](https://github.com/astral-sh/uv), the fastest Python package manager.
- 🌍 **Unified Aliases**: Identical commands across Windows (CMD/PS) and Unix (Bash/Zsh).
- 🔍 **Tab Completion**: Intelligent environment name completion for PowerShell users.
- 🧹 **Health Checks**: Built-in pruning to remove broken or deleted environment references.
- 📦 **One-Touch Updates**: Batch update all outdated packages in an environment with one command.

---

## 📦 Installation

Choose the installer for your operating system:

### **Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/superchargez/power_shelling/main/install-uv-manager.ps1 | iex
```

### **Linux / macOS (Bash or Zsh)**
```bash
curl -sSL https://raw.githubusercontent.com/superchargez/power_shelling/main/setup-uv.sh | bash
```

### **Windows (Legacy CMD)**
```batch
:: Download and run the .bat installer
curl -O https://raw.githubusercontent.com/superchargez/power_shelling/main/install-uv-manager.bat
install-uv-manager.bat
```

---

## 🚀 Quick Start

```powershell
# 1. Create a new environment named 'ai' with Python 3.11
uvc ai 3.11

# 2. Activate it from anywhere
uva ai

# 3. Install packages (blazing fast)
uv pip install torch numpy

# 4. List all your environments
uvl

# 5. Deactivate when finished
uvx
```

---

## 📚 Command Reference

| Alias | Full Command | Description |
| :--- | :--- | :--- |
| `uvl` | `Get-UvEnvList` | List all environments (Use `uvl -Prune` to clean up missing folders) |
| `uvc` | `New-UvEnv` | Create: `uvc <name> <python_version>` |
| `uva` | `Enter-UvEnv` | Activate an environment by name |
| `uvx` | `Exit-UvEnv` | Deactivate the current environment |
| `uvr` | `Remove-UvEnv` | Delete an environment and its physical files |
| `uvu` | `Update-UvEnv` | Automatically upgrade all packages in the environment |
| `uve` | `Export-UvEnv` | Export environment to `requirements.txt` |
| `uvk` | `Clear-UvCache` | Wipe the global UV cache to free up space |

---

## ⚙️ How It Works

### File Structure
The manager organizes itself in your user profile:
- **Windows**: `$HOME\.uv\envs\`
- **Unix**: `~/.uv/envs/`

```text
.uv/envs/
├── envs.json          # The central registry database
├── project-a/         # Virtual environment 1
└── project-b/         # Virtual environment 2
```

### Registry Example (`envs.json`)
Your environments are tracked so you don't have to remember where they are:
```json
{
  "data-science": {
    "path": "C:\\Users\\You\\.uv\\envs\\data-science",
    "python": "3.14",
    "created": "2026-01-27T10:00:00"
  }
}
```

---

## 🛠️ Advanced Usage

### **Bulk Package Updates**
Instead of manually updating packages, run `uvu` while an environment is active. It scans for outdated versions and upgrades them using `uv pip install --upgrade`.

### **Environment Maintenance**
If you manually delete an environment folder, your registry will show it as `[MISSING]`. Run:
```powershell
uvl -Prune
```
This will automatically clean up the `envs.json` file.

### **Shell Integration**
The installers automatically inject the manager into your profile:
- **PowerShell**: Adds to `$PROFILE`
- **Bash**: Adds to `~/.bashrc`
- **Zsh**: Adds to `~/.zshrc`
- **CMD**: Uses the `AutoRun` registry key for instant availability.

---

## 🤝 Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/AmazingFeature`.
3. Commit your changes: `git commit -m 'Add AmazingFeature'`.
4. Push to the branch: `git push origin feature/AmazingFeature`.
5. Open a Pull Request.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Made with ⚡ by [superchargez](https://github.com/superchargez)**  
*"Stop managing environments, start coding."*