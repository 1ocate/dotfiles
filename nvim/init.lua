-- OS Check
local homePwd = os.getenv('HOME')
osName =''
if homePwd then
    if string.match(homePwd, "/Users") then
        osName = 'Mac'
    else
        osName = 'Linux'
    end
else
    osName = 'WSL'
end

require('user.options')
require('user.plugins')
require('user.keymaps')
