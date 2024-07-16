hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.ShiftIt = {
   url = "https://github.com/peterklijn/hammerspoon-shiftit",
   desc = "ShiftIt spoon repository",
   branch = "master",
}

spoon.SpoonInstall:andUse("ShiftIt", { repo = "ShiftIt" })

hs.loadSpoon("ShiftIt")
spoon.ShiftIt:bindHotkeys({})

inputEnglish = "com.apple.keylayout.ABC"

require('modules.esc_bind')
require('modules.inputsource_aurora')