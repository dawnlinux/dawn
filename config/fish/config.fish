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
