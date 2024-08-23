#!/usr/bin/env fish
curl -sL https://git.io/fisher | source
and fisher install jorgebucaran/fisher

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

fisher install PatrickF1/fzf.fish
fisher install IlanCosman/tide@v5
fisher install jorgebucaran/nvm.fish
fisher install edc/bass
