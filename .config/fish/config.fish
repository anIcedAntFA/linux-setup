if status is-interactive
  # Commands to run in interactive sessions can go here
  alias gg="ghq get"
  alias pn=pnpm

  # Clipse Aliases
  alias cb="wezterm start  -- clipse" # Alias to quickly open Clipse TUI
  alias cba="clipse -a" # Add standard input to history
  alias cbc="clipse -c" # Copy standard input to clipboard and history
  alias cbp="clipse -p" # Print current clipboard content
  alias cbclear="clipse -clear" # Clear all history except pinned items
  alias cbclear-images="clipse -clear-images" # Clear only image history
  alias cbclear-text="clipse -clear-text" # Clear only text history
  alias cbclear-all="clipse -clear-all" # Clear entire history
  alias cbkill="clipse -kill" # Kill any existing background listener processes
  alias cblisten="clipse -listen" # Manually start the background listener (if not auto-started)

  # Unix convert
  alias unix=dos2unix
end

# Starship 
set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml
starship init fish | source

# Volta 
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Go
set -g GOPATH $HOME/go
set -gx PATH $GOPATH/bin $PATH

# Load OS-specific configurations
switch (uname)
  case Darwin
    source (dirname (status --current-filename))/config-osx.fish
  case Linux
    source (dirname (status --current-filename))/config-linux.fish
  case '*'
    source (dirname (status --current-filename))/config-windows.fish
end