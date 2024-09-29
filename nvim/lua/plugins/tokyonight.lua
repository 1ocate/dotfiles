return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      on_highlights = function(hl)
        -- hl.Visual = { bg = "#FF8C00", fg = "#FFFFFF" }

        -- DiffAdd: 추가된 줄에 대한 진한 녹색 배경과 흰색 텍스트
        hl.DiffAdd = { bg = "#00FF00", fg = "#000000" } -- 밝은 녹색 배경과 검정색 텍스트
        hl.DiffChange = { bg = "#0000FF", fg = "#FFFFFF" } -- 밝은 파란색 배경과 흰색 텍스트
        hl.DiffText = { bg = "#FFFF00", fg = "#000000" } -- 밝은 노란색 배경과 검정색 텍스트
        hl.DiffDelete = { bg = "#FF0000", fg = "#FFFFFF" } -- 밝은 빨간색 배경과 흰색 텍스트
      end,
    },
  },
}
