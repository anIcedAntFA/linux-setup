# Linux Setup

![desktop screenshot](./images/desktop-screenshot-01.png)

![desktop screenshot](./images/desktop-screenshot-02.png)

![desktop screenshot](./images/desktop-screenshot-03.png)

## Table of Contents

- [Linux Setup](#linux-setup)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Contents](#contents)
    - [Dependencies](#dependencies)
    - [i3 configs](#i3-configs)
    - [Shell configs](#shell-configs)
    - [Applications](#applications)
  - [Credits](#credits)

## Introduction

✨ This is my Linux setup and _dotfiles_. **Feel free** to use it 🚀🚀🚀.

<br>

> [!WARNING]
>
> - This is the setting for my personal _laptop_. It may be different if used for a _PC_ or other devices.
> - **Be careful** when copy all settings unless you know what that entails, just read information **in detail** for each repository.

<br>

📝 Basically, I use:

<details>
  <summary>🪐 <a href="https://endeavouros.com/">EndeavourOS</a></summary>

- Download [ISO file](https://endeavouros.com/#Download).
- Dual boots with [Ventoy](https://github.com/ventoy/Ventoy).
  ![Desktop screenshot](./images/ventoy-disk-screenshot.png)

</details>

<details>
  <summary>
    🤯 <a href="https://system76.com/cosmic/">Cosmic</a> - Desktop Environment.
  </summary>
</details>

<details>
  <summary>
  🛠️ <a href="https://github.com/Jguer/yay">yay</a> - Arch Linux AUR helper tool.
  </summary>

- With _yay_ you can easily install, update and manage your packages.
- Here is an example when using _yay_ to install VS Code.
  ![Desktop screenshot](./images/yay-install-screenshot.png)

</details>

<br />

🥳 Many thanks to my colleagues at **NDVN** for inspiring me and guiding me towards _Linux_. You guys are amazing and kind.

[`⬆ BACK TO TOP ⬆`](#table-of-contents)

## Contents

### Dependencies

```sh
yay -S [package-name]
```

Here is a list of packages:

`extra/wezterm` `tmux` `extra/neofetch` `extra/brightnessctl` `picom-git` `polybar` `fish` `extra/fisher` `git` `peco` `neovim` `eza` `starship` `htop` `redshift` `ttf-jetbrains-mono-nerd` `extra/noto-fonts-emoji` `nitrogen` `betterlockscreen` `flameshot` `visual-studio-code-bin` `jetbrains-toolbox` `docker` `docker-compose` `go` `i3lock-color` `arttime-git` `rofi-bluetooth-git` `extra/blueman` `network-dmenu-git` `appimagelauncher` `postman-bin` `firefox-developer-edition` `google-chrome` `microsoft-edge-dev-bin` `teams` `slack-desktop` `aur/prospect-mail` `extra/discord` `extra/telegram-desktop` `obsidian` `extra/calc` `aur/networkmanager-dmenu-git`

[`⬆ BACK TO TOP ⬆`](#table-of-contents)

### i3 configs

- [weztem](https://wezfurlong.org/wezterm/index.html) - A cross-platform terminal emulator and multiplexer.
- [betterlockscreen](https://github.com/betterlockscreen/betterlockscreen) - 🍀 sweet looking lockscreen for linux system

[`⬆ BACK TO TOP ⬆`](#table-of-contents)

### Shell configs

- [fish](https://github.com/fish-shell/fish-shell) - The user-friendly command line shell.
- [fisher](https://github.com/jorgebucaran/fisher) - A plugin manager for Fish.
- [dracula-fish](https://github.com/dracula/fish) - Dark theme for fish.
- [z for fish](https://github.com/jethrokuan/z) - Pure-fish z directory jumping.
- [ghq](https://github.com/x-motemen/ghq) - Remote repository management made easy.
- [peco](https://github.com/peco/peco) - Simplistic interactive filtering tool.
- [volta](https://volta.sh/) - The Hassle-Free JavaScript Tool Manager.
- [eza](https://github.com/eza-community/eza) - A modern, maintained replacement for ls.
- [starship](https://starship.rs/) - The minimal, blazing-fast, and infinitely customizable prompt for any shell!
- [go](https://go.dev/)
- [rust](https://www.rust-lang.org/)

[`⬆ BACK TO TOP ⬆`](#table-of-contents)

### Applications

-

## Credits

This config has heavy inspiration from:

- [devaslife](https://github.com/craftzdog/dotfiles-public) - Takuya Matsuyama
- [mantran1611](https://github.com/manhtran1611/dotfiles) - Manh Tran
- [lazarus2019](https://github.com/lazarus2019) - Thai Son

[`⬆ BACK TO TOP ⬆`](#table-of-contents)
