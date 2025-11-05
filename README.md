# My Dotfiles

This repository contains my personal configuration files (dotfiles) for various tools, including Zsh, PowerShell, and Starship.

The setup is automated via an installation script.

## Installation

To set up a new machine with these configurations, you can run the following command in your terminal. This will download and execute the installation script.

### One-Liner Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/<your-username>/dotfiles/main/install.sh)"
```

*(Replace `<your-username>` with your actual GitHub username and ensure `main` is your default branch name)*

### What the script does:

*   Installs `git`, `zsh`, and `curl` using the native package manager (supports Ubuntu, Debian, and Arch).
*   Installs [Oh My Zsh](https://ohmyz.sh/).
*   Installs [Starship](https://starship.rs/).
*   Installs `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins.
*   Clones this repository to `~/dotfiles`.
*   Creates symbolic links for `.zshrc` and `starship.toml`.
*   Changes the default shell to `zsh`.
