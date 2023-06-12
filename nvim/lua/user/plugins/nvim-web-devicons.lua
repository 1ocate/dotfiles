
local dockerInfo =  {
    icon = "",
    color = "#458ee6",
    cterm_color = "33",
    name = "Dockerfile"
}
require('nvim-web-devicons').setup({
    color_icons = true,
    default = true,
    strict = true,
    override_by_filename = {
        ["Dockerfile"] = dockerInfo,  
        ["Containerfile"] = dockerInfo,
        ["docker-compose.yml"] = dockerInfo,
        ["docker-compose.yaml"] = dockerInfo,
        [".dockerignore"] = dockerInfo,
        ["dockerfile"] = dockerInfo,
    }
})
