if status is-interactive
    # Commands to run in interactive sessions can go here
    fzf_configure_bindings --directory=\ct --variables=\ch
    alias vi="nvim"
    alias vim="nvim"
    set fzf_fd_opts --hidden --exclude=.git
end

