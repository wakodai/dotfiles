#!/bin/bash

if [ "$(uname)" != "Darwin" ] ; then
	echo "Not macOS!"
	exit 1
fi

# Xcode Command Line Tools のインストールを確認し、未インストールの場合のみ実行
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install > /dev/null
else
    echo "Xcode Command Line Tools are already installed. Skipping."
fi

# Install brew
# brew がインストールされていない場合にのみ実行
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed. Skipping."
fi

# Install rosetta2
# AppleシリコンかつRosettaが未インストールの場合にのみ実行
if [[ $(uname -m) == "arm64" ]]; then
    if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Installing Rosetta..."
        softwareupdate --install-rosetta --agree-to-license
    else
        echo "Rosetta is already installed. Skipping."
    fi
else
    echo "This is not an Apple Silicon Mac. Skipping Rosetta installation."
fi

# install oh-my-zsh
# oh-my-zsh がインストールされているか確認
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed. Skipping installation."
else
    echo "Oh My Zsh is not installed. Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# install p10k
# Powerlevel10k のインストールディレクトリを定義
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
# Powerlevel10k がインストールされているか確認
if [ -d "$P10K_DIR" ]; then
    echo "Powerlevel10k is already installed. Skipping installation."
else
    echo "Powerlevel10k is not installed. Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# fzf-tab のインストールディレクトリを定義
FZF_TAB_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab"
# fzf-tab がインストールされているか確認
if [ -d "$FZF_TAB_DIR" ]; then
    echo "fzf-tab is already installed. Skipping installation."
else
    echo "fzf-tab is not installed. Installing fzf-tab..."
    git clone https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"
fi


# deploy dotfiles on home dir
for i in .?*; do
  echo "$i"
  if [ "$i" != '..' ] && [ "$i" != '.git' ]; then
    ln -Fsi ~/dotfiles/"$i" ~
  fi
done

# deploy dotfiles on .config dir
# yabai
mkdir -p ~/.config/yabai
ln -Fsi ~/dotfiles/yabai/yabairc ~/.config/yabai/yabairc

# skhd
mkdir -p ~/.config/skhd
ln -Fsi ~/dotfiles/skhd/skhdrc ~/.config/skhd/skhdrc

# stats
mkdir -p ~/.config/stats
ln -Fsi ~/dotfiles/stats/Stats.plist ~/.config/stats/Stats.plist

# karabiner
mkdir -p ~/.config/karabiner
ln -Fsi ~/dotfiles/karabiner ~/.config/

# iterm2
mkdir -p ~/.config/iterm2
ln -Fsi ~/dotfiles/iterm2 ~/.config/

# make mount point
mkdir -p ~/mount_bezos_m2
mkdir -p ~/mount_bezos_sda
