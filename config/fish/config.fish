if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting
end

starship init fish | source

alias ff "fastfetch"
alias nf "neofetch"

alias ll "ls -la"

alias spit "cp ~/software/php/SPIT/spit.php . && touch content.txt"

alias ii "sudo pacman -S"
alias yy "yay -S"

alias nvm "nvim"

alias yt "yt-dlp"

# Created by `pipx` on 2026-08-05 10:41:00
set PATH $PATH /home/jhayonline/.local/bin

set -gx PATH $HOME/.config/composer/vendor/bin $PATH
set -gx PATH ~/.npm-global/bin $PATH
set -gx PATH ~/.config/composer/vendor/bin $PATH
set -gx PATH ~/.config/composer/vendor/bin $PATH
