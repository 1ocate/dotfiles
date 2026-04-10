return {
  {
    "hrsh7th/nvim-cmp",
    -- 전체 코드를 나열하지 않고, 필요한 부분만 opts 함수로 오버라이딩합니다.
    opts = function(_, opts)
      local cmp = require("cmp")
      local auto_select = true

      -- 1. 매핑 오버라이딩 (가장 중요한 엔터 프리징 해결)
      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        ["<CR>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            if cmp.get_active_entry() then
              -- 항목이 선택되었을 때만 확정
              LazyVim.cmp.confirm({ select = auto_select })
            else
              -- o, i 진입 직후처럼 선택된 게 없으면 창을 닫고 개행(fallback)
              cmp.close()
              fallback()
            end
          else
            fallback()
          end
        end, { "i", "s" }),

        -- 필요하다면 다른 키맵도 여기서 추가/수정 가능
        ["<C-y>"] = LazyVim.cmp.confirm({ select = true }),
      })

      -- 2. 검색 소스 커스텀 (기존 코드의 buffer 로직 유지 가능)
      -- 기본적으로 LazyVim 설정을 따르되, 우선순위나 특정 옵션만 변경합니다.
      opts.sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 1000 },
        { name = "path", priority = 500 },
        {
          name = "buffer",
          priority = 250,
          option = {
            keyword_length = 3,
            -- 기존 코드에 있던 복잡한 buffer 필터링 로직을 그대로 사용하려면 여기에 유지
          },
        },
      })

      -- 3. 포맷팅 (아이콘 옆에 출처 [LSP/Path] 표시 추가로 가독성 향상)
      local format_original = opts.formatting.format
      opts.formatting.format = function(entry, item)
        item = format_original(entry, item) -- 기존 LazyVim 아이콘 로직 호출
        item.menu = ({
          nvim_lsp = "[LSP]",
          path = "[Path]",
          buffer = "[Buf]",
        })[entry.source.name]
        return item
      end
    end,
  },
}
