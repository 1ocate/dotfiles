return {
  {
    -- selection = function(source)
    --   return select.visual(source)
    -- end,
    "CopilotC-Nvim/CopilotChat.nvim",
    -- event = "VeryLazy",
    event = "BufNewFile",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      debug = false, -- Enable debugging
      -- show_folds = true, -- Shows folds for sections in chat
      -- show_help = true, -- Shows help message as virtual lines when waiting for user input
      -- auto_follow_cursor = false, -- Auto-follow cursor in chat
      -- auto_insert_mode = false, -- Automatically enter insert mode when opening window and on new prompt
      -- insert_at_end = false, -- Move cursor to end of buffer when inserting text
      -- clear_chat_on_new_prompt = false, -- Clears chat on every new prompt
      -- highlight_selection = true, -- Highlight selection in the source buffer when in the chat window
      -- default prompts
      prompts = {
        Explain = {
          prompt = "/COPILOT_EXPLAIN 활성 선택에 대한 설명을 텍스트 단락으로 한글을 사용하여 작성하세요",
        },
        Review = {
          prompt = "/COPILOT_REVIEW 선택한 코드를 검토하세요.",
          callback = function(response, source) end,
        },
        Fix = {
          prompt = "/COPILOT_GENERATE 이 코드에 문제가 있습니다. 버그가 수정된 코드를 다시 작성하세요.",
        },
        Optimize = {
          prompt = "/COPILOT_GENERATE 선택한 코드를 성능과 가독성을 향상시키기 위해 최적화하세요.",
        },
        Docs = {
          prompt = "/COPILOT_GENERATE 선택한 코드에 대한 문서 주석을 한글로 추가하세요.",
        },
        Tests = {
          prompt = "/COPILOT_GENERATE 내 코드에 대한 테스트를 생성하세요.",
        },
        FixDiagnostic = {
          prompt = "파일의 다음 진단 문제를 해결하는 데 도움을 주세요:",
          selection = function(source)
            -- Here you should implement the function to select diagnostics
          end,
        },
        Commit = {
          prompt = "한글로 변경 사항에 대한 커밋 메시지를 commitizen 규칙에 따라 작성하세요. 제목은 최대 50자, 메시지는 72자에서 줄바꿈하세요. 전체 메시지를 gitcommit 언어의 코드 블록으로 감싸세요.",
          selection = function(source)
            -- Here you should implement the function to select gitdiff
          end,
        },
        CommitStaged = {
          prompt = "한글로 변경 사항에 대한 커밋 메시지를 commitizen 규칙에 따라 작성하세요. 제목은 최대 50자, 메시지는 72자에서 줄바꿈하세요. 전체 메시지를 gitcommit 언어의 코드 블록으로 감싸세요.",
          selection = function(source)
            -- Here you should implement the function to select gitdiff
          end,
        },
      },
      -- default mappings
      mappings = {
        complete = {
          -- detail = "Use @<Tab> or /<Tab> for options.",
          detail = "",
          -- insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-r>",
          insert = "<C-r>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-L>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
          register = '"',
        },
        show_diff = {
          normal = "gd",
        },
        show_system_prompt = {
          normal = "gp",
        },
        show_user_selection = {
          normal = "gs",
        },
      },
    },
  },
}
