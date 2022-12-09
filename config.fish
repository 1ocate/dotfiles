if status is-interactive
    # Commands to run in interactive sessions can go here
    fzf_configure_bindings --directory=\ct --variables=\ch --git_log=\cg
    alias vi="nvim"
    alias vim="nvim"
    set fzf_fd_opts --hidden --exclude=.git
    set -U fish_greeting "🐟"
    fish_vi_key_bindings
end

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \ce forward-char
    end
end
