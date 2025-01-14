if status is-interactive
    # Commands to run in interactive sessions can go here
    alias vi='nvim'
    alias vim='nvim'
    alias apt-get='sudo apt-get'
    alias k8s-up='ssh -fNTML 6443:localhost:6443 hkcd-cluster83'
    alias k8s-status='ssh -TO check hkcd-cluster83'
    alias k8s-down='ssh -TO exit hkcd-cluster83'
    alias proxmox-up='ssh -fNTMD 9000 proxmox'
    alias proxmox-status='ssh -TO check proxmox'
    alias proxmox-down='ssh -TO exit proxmox'
    fzf_configure_bindings --directory=\ct --variables=\ch --git_log=\cg
    set fzf_fd_opts --hidden --exclude=.git
    set -x fish_greeting "🐟"
    fish_vi_key_bindings
    set -x FZF_DEFAULT_COMMAND "fd --hidden --no-ignore --follow --exclude='**/.git/'"
    set -x PATH ~/bin ~/.local/bin/ /opt/homebrew/bin /opt/local/bin /opt/local/sbin ~/.cargo/bin $PATH
    set -x KIND_EXPERIMENTAL_PROVIDER podman
    # for xsel, yankclip.vim 
    set -x DISPLAY :0
end

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \ce forward-char
        bind -M $mode \cp up-or-search
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
