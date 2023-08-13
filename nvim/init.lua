-- OS Check
local homePwd = os.getenv('HOME')
local wslEnv = os.getenv('WSLENV')

osName =''
if homePwd then
    if string.match(homePwd, "/Users") then
        osName = 'Mac'
    else
        osName = 'Linux'

        if wslEnv then
            osName = 'WSL'
        end
    end
else
    osName ='Other'
end

autocomplete = 'cmp'

require('user.options')
require('user.plugins')
require('user.keymaps')
