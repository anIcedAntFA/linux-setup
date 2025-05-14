# Linux Setup

## 1. Introduction

✨ This is my Linux setup and dotfiles. Feel free to use it 🚀🚀🚀.

<br>

> [!WARNING]
>
> - This is the setting for my personal _laptop_. It may be different if used for a _PC_ or other devices.
> - **Be careful** when copy all settings unless you know what that entails, just read information **in detail** for each repository.

<br>

📝 Basically, I use:

- Fedora
- Cosmic Desktop
- Dnf

### 2. Installations

#### 2.1 Applications

- Terminal: I use **[Wezterm](https://wezterm.org/)**. Follow Fedora Corp

```sh
  sudo dnf copr enable wezfurlong/wezterm-nightly
  sudo dnf install wezterm
  sudo dnf update wezterm
```

- Browser: My main web browser is **[Firefox Developer Edition](https://www.mozilla.org/en-US/firefox/developer/)**. Follow Fedora Corp

```sh
  sudo dnf copr enable the4runner/firefox-dev
  sudo dnf install firefox-dev
```

- **[Google Chrome](https://www.google.com/chrome/)**: Download 64 bit .rpm (For Fedora/openSUSE)

```sh
sudo dnf install Downloads/google-chrome-stable_current_x86_64.rpm
```

```sh
sudo dnf install fedora-workstation-repositories
```

- Discord: Installing Discord via RPM Fusion Repository.

```sh
  sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf update
  sudo dnf install discord
```

- Note app: I currently use **[Anytype](https://anytype.io/)**. Download RPM for Linux here, then

```sh
  cd ~
  sudo dnf install Downloads/anytype-0.46.1.x86_64.rpm`
```

- **[fastfetch](https://github.com/fastfetch-cli/fastfetch)**:

```sh
  dnf install fastfetch
```

- Code Editor: I use **[Visual Studio Code](https://code.visualstudio.com/)**. Follow [VSCode installation page](https://code.visualstudio.com/docs/setup/linux#_rhel-fedora-and-centos-based-distributions).

```sh
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

dnf check-update
sudo dnf install code
```

- Screenshot: I use **[Flameshot](https://flameshot.org/)**:

```sh
dnf search flameshot
sudo dnf install flameshot
```

- Font Mono: I use Jetbrains

```sh
sudo dnf copr enable elxreno/jetbrains-mono-fonts -y && sudo dnf install jetbrains-mono-fonts -y
```

- Nerd Font: I use **Jetbrains Mono Nerd Fonts**. Follow [aquacash5/nerd-fonts](https://copr.fedorainfracloud.org/coprs/aquacash5/nerd-fonts/)

```sh
sudo dnf copr enable aquacash5/nerd-fonts
dnf search jet-brains-mono-nerd-fonts
sudo dnf install jet-brains-mono-nerd-fonts
```

- **[Google Noto Emoji Font](https://packages.fedoraproject.org/pkgs/google-noto-emoji-fonts/google-noto-emoji-fonts/)**

```sh
dnf search google-noto-emoji-fonts
sudo dnf install google-noto-emoji-fonts
```

- **Fish** shell:

```sh
sudo dnf install fish
```

then set default shell follow [Docs](https://fishshell.com/docs/current/index.html)

```sh
echo /usr/local/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/bin/fish
```

- **Golang**:

```sh
sudo dnf install golang
```

then place this in `config.fish`

```sh
# Go
set -g GOPATH $HOME/go
set -gx PATH $GOPATH/bin $PATH
```

- **[ghq](https://github.com/x-motemen/ghq)**: Manage remote repository clones. Install by `go get`.

```sh
go install github.com/x-motemen/ghq@latest
```

- Create `.gitconfig` file, `workspace` folder in root.

```sh
sudo nano .gitconfig
```

- Create `.ssh` folder in root. Then you can copy it to use with github.

```sh
ssh-keygen
# copy content
cat .ssh/id_ed25519.pub | fish_clipboard_copy
```

- **[Fisher](https://github.com/jorgebucaran/fisher)**

```sh
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
```

- **[z for fish](https://github.com/jethrokuan/z)**:

```sh
fisher install jethrokuan/z
```

- **[peco](https://github.com/peco/peco)**: Simplistic interactive filtering tool. Download rpm from [Fedora pkgs](https://fedora.pkgs.org/41/rpm-sphere-x86_64/peco-0.5.10-1.x86_64.rpm.html) - binary package

```sh
sudo dnf install Downloads/p_peco-0.5.10-1.x86_64.rpm
```

Add to `fish_user_key_bindings.fish`

```sh
function fish_user_key_bindings
  # peco
  bind \cr peco_select_history # Bind for peco select history to Ctrl+R
  bind \cf peco_change_directory # Bind for peco change directory to Ctrl+F

  # vim-like
  bind \cl forward-char

  # prevent iterm2 from closing when typing Ctrl-D (EOF)
  bind \cd delete-char
end
```

Add to `peco_change_directory.fish`

```sh
function _peco_change_directory
  if [ (count $argv) ]
    peco --layout=bottom-up --query "$argv "|perl -pe 's/([ ()])/\\\\$1/g'|read foo
  else
    peco --layout=bottom-up |perl -pe 's/([ ()])/\\\\$1/g'|read foo
  end
  if [ $foo ]
    builtin cd $foo
    commandline -r ''
    commandline -f repaint
  else
    commandline ''
  end
end

function peco_change_directory
  begin
    echo $HOME/.config
    ghq list -p
    ls -ad */|perl -pe "s#^#$PWD/#"|grep -v \.git
    ls -ad $HOME/workspace/*/* |grep -v \.git
  end | sed -e 's/\/$//' | awk '!a[$0]++' | _peco_change_directory $argv
end
```

Add to `peco_select_history.fish`

```sh
function peco_select_history
  if test (count $argv) = 0
    set peco_flags --layout=bottom-up
  else
    set peco_flags --layout=bottom-up --query "$argv"
  end

  history|peco $peco_flags|read foo

  if [ $foo ]
    commandline $foo
  else
    commandline ''
  end
end
```

- **[eza](https://github.com/eza-community/eza)**: A modern alternative to ls. Download from [Fedora Corp](https://copr.fedorainfracloud.org/coprs/alternateved/eza/)

```sh
sudo dnf copr enable alternateved/eza
sudo dnf install eza
```

Add to `fish/config-linux.fish`

```sh
if type -q exa
  alias ll "exa -l -g --icons --header --time-style=default"
  alias lla "ll -a"
  alias llt "ll --tree"
  alias llat "ll -a --tree"
end
```

- **[starship](https://starship.rs/)**: customizable prompt for any shell!

```sh
curl -sS https://starship.rs/install.sh | sh
```

Add the following to the end of `~/.config/fish/config.fish`:

```sh
# starship
starship init fish | source
```

- **[Dracula for fish](https://draculatheme.com/fish2)**:

```sh
fisher install dracula/fish
```

- **[volta](https://volta.sh/)**: JavaScript Tool Manager

```sh
curl https://get.volta.sh | bash
# install node, pnpm, yarn
volta install node@22.14.0
volta install pnpm@10.8.1
volta install yarn@1.22.22
```

- **[bun](https://bun.sh/)**

```sh
curl -fsSL https://bun.sh/install | bash
```

- **[Fcitx5](https://fcitx-im.org/wiki/Fcitx_5):** Bộ gõ Tiếng việt, [using fcitx5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland).

```sh
sudo dnf install fcitx5 --allowerasing
sudo dnf install fcitx5-unikey
```
