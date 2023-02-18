if status is-interactive
    # Commands to run in interactive sessions can go here
    alias vi='nvim'
    alias vim='nvim'
    fzf_configure_bindings --directory=\ct --variables=\ch --git_log=\cg
    set fzf_fd_opts --hidden --exclude=.git
    set -U fish_greeting "🐟"
    fish_vi_key_bindings
    set -x PATH $PATH ~/bin ~/.local/bin/ /opt/homebrew/bin /opt/local/bin /opt/local/sbin
end

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \ce forward-char
    end
end

function ssh
    set TERM xterm-256color
    command ssh $argv
end

function nvim
    set TERM wezterm 
    command nvim $argv
end
