return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    event = "VimEnter",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    build = "make tiktoken",
    opts = {
      model = "gpt-4o-2024-11-20",
      debug = false,
      selection = function(source)
        local select = require("CopilotChat.select")
        local selected_text = select.visual(source)
        return selected_text or ""
      end,
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
        },
        Commit = {
          prompt = "한글로 변경 사항에 대한 커밋 메시지를 commitizen 규칙에 따라 작성하세요. 제목은 최대 50자, 메시지는 72자에서 줄바꿈하세요. 전체 메시지를 gitcommit 언어의 코드 블록으로 감싸세요.",
          options = {}, -- ✅ 오류 방지를 위한 기본값 추가
        },
        CommitStaged = {
          prompt = "한글로 변경 사항에 대한 커밋 메시지를 commitizen 규칙에 따라 작성하세요. 제목은 최대 50자, 메시지는 72자에서 줄바꿈하세요. 전체 메시지를 gitcommit 언어의 코드 블록으로 감싸세요.",
          options = {}, -- ✅ 오류 방지를 위한 기본값 추가
        },
      },
      mappings = {
        complete = { detail = "" },
        close = { normal = "q", insert = "<C-c>" },
        reset = { normal = "<C-r>", insert = "<C-r>" },
        submit_prompt = { normal = "<CR>", insert = "<C-L>" },
        accept_diff = { normal = "<C-y>", insert = "<C-y>" },
        yank_diff = { normal = "gy", register = '"' },
        show_diff = { normal = "gd" },
        show_system_prompt = { normal = "gp" },
        show_user_selection = { normal = "gs" },
      },
    },
    config = function(_, opts)
      require("CopilotChat").setup(opts)

      -- ✅ 커밋 메시지 자동 생성 명령어 등록
      vim.api.nvim_create_user_command("CreateCommit", function()
        local diff_summary = vim.fn.system("git diff --staged")

        if diff_summary == "" then
          print("스테이징된 변경사항이 없습니다.")
          return
        end

        local prompt = [[
다음은 git 스테이지에 있는 변경 요약입니다. 이를 기반으로 한글로 commitizen 규칙에 따라 커밋 메시지를 작성해 주세요.
- 제목은 최대 50자 이내로 작성하세요.
- 본문 메시지는 72자에서 줄바꿈하세요.
- 전체 메시지를 ```gitcommit``` 코드 블록으로 감싸주세요.

변경 요약:
]] .. diff_summary

        require("CopilotChat").ask(prompt, {})
      end, {})
      -- ✅ 커밋 편집창 열릴 때 자동 실행
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "COMMIT_EDITMSG",
        callback = function()
          if vim.bo.filetype == "gitcommit" then
            vim.defer_fn(function()
              vim.cmd("CreateCommit")
            end, 100)
          end
        end,
      })
    end,
  },
}
