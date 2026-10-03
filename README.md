# dotfiles

호스트별 환경 선택과 이미 세팅된 환경 등록은 [공통 환경 등록 절차](docs/environment-registration.md)를 따릅니다. `scripts/environment.py`는 로컬 선택값만 기록하며 프로그램 설치·설정 연결은 수행하지 않습니다.

공통 설정을 원본으로 유지하고 OS별 스크립트는 환경 차이만 연결합니다. 이후 작업 기준은 [공통 설정 가드레일](docs/setup-guardrails.md)과 [AGENTS.md](AGENTS.md)에 기록합니다.

AI는 요청 범위의 분석·병렬 분담·수정·검증·PR 제출까지 자율적으로 진행하고 사용자는 최종 PR을 검토합니다. Codex 실행 옵션과 에이전트 역할은 [AI 작업 흐름](docs/ai-workflow.md#자율-진행과-병렬-분담)을 따릅니다.

먼저 실행 환경을 macOS, Windows WSL, Windows 네이티브 PowerShell, Linux로 판별하고 공통 설정과 해당 환경 전용 설정만 적용하는 것을 작업 기준으로 삼습니다. 전용 변경은 다른 환경에서 실행되지 않도록 구분합니다. 네 환경의 통합 설치는 아직 완료되지 않았습니다.

Neovim, 셸, 터미널 및 키보드 설정을 모은 개인 개발 환경 저장소입니다.
macOS 중심 설정과 Linux/WSL 및 Windows용 설정이 함께 있으며, 모든 파일을 모든 운영체제에 적용하는 구성은 아닙니다.
사용자 경로와 설치된 도구에 맞게 필요한 설정을 선택해서 사용합니다.

## 저장소 구성

| 경로 | 역할 |
| --- | --- |
| [`nvim/`](nvim/) | LazyVim 기반 Neovim 설정과 플러그인 구성 |
| [`fish/`](fish/), [`.zshrc`](.zshrc), [`.p10k.zsh`](.p10k.zsh) | 셸 환경, 단축키, 프롬프트 설정 |
| [`.wezterm.lua`](.wezterm.lua), [`alacritty.toml`](alacritty.toml) | 터미널 색상, 글꼴, 키 입력 설정 |
| [`tmux/tmux.conf`](tmux/tmux.conf) | tmux 창 이동, 복사 모드, 세션 키맵 |
| [`scripts/t`](scripts/t) | fzf로 디렉터리를 선택하고 tmux 세션 생성·전환 |
| [`.hammerspoon/`](.hammerspoon/) | macOS 창 관리와 한글 입력 상태 표시·전환 |
| [`autoHotKey.ahk`](autoHotKey.ahk) | Windows 키보드와 한글 입력 전환 |
| [`.gitconfig`](.gitconfig), [`.gitignore_global`](.gitignore_global) | 개인 Git 설정과 전역 제외 규칙 |
| [`pyrightconfig.json`](pyrightconfig.json) | Python 분석에서 제외할 디렉터리 설정 |
| [`install`](install), [`fish_package_install.fish`](fish_package_install.fish) | 설정 연결과 fish 플러그인 설치 스크립트 |

## 설정 적용 방식

각 호스트에 이 저장소를 받아 안정적인 경로에 두고, 프로그램의 설정 경로를 저장소 원본에 연결하는 것이 목적입니다.
심볼릭 링크·Windows junction 또는 원본을 읽는 loader를 사용합니다. 설정을 변경할 때는 저장소 원본을 수정하며, 변경사항이 이 체크아웃의 `git diff`에 남아 커밋할 수 있어야 합니다.
저장소 위치는 호스트마다 달라도 됩니다. 연결 스크립트는 현재 체크아웃 위치를 기준으로 경로를 설정하며, 저장소를 옮기면 연결을 다시 적용합니다.
설정은 각 프로그램의 재로드 또는 재시작 시 반영됩니다. 일상적인 설정 수정과 Git 기록은 실사용 체크아웃에서 진행하고, 실험적인 변경에만 별도 worktree를 사용합니다.

현재 `install`은 기존 사용자 설정을 `rm -rf`로 삭제한 뒤 링크를 생성합니다.
기존 설정을 백업하고 스크립트의 대상 경로를 검토하기 전에는 실행하지 마세요.
OS별 선택 설치나 자동 복구 기능은 없습니다.

설치 스크립트에는 다음과 같은 제약도 있습니다.

- `sh`로 선언되어 있지만 Bash 전용 `${BASH_SOURCE[0]}` 표현을 사용합니다.
- 일부 대상 디렉터리를 미리 만들지 않으며, Alacritty 설정의 삭제 경로와 링크 경로가 다릅니다.
- 추적되지 않는 `scripts/.project_path.example`을 링크 대상으로 참조합니다.
- WezTerm terminfo를 내려받고 fish 플러그인 설치 스크립트를 실행합니다.
- `.gitconfig`까지 교체하므로 개인 Git 식별 정보와 경로를 먼저 확인해야 합니다.

## Neovim

`nvim/init.lua`에서 `config.lazy`를 불러오고, `lazy.nvim`이 LazyVim과 `lua/plugins/`의 사용자 설정을 로드합니다.
플러그인 버전은 `nvim/lazy-lock.json`, 추가 기능은 `nvim/lazyvim.json`에 기록되어 있습니다.

주요 설정은 다음과 같습니다.

- PHP, Python, JSON, Markdown, SQL 언어 지원
- Copilot·CopilotChat 비활성화, 저장 시 자동 포맷 비활성화
- Telescope와 fzf 검색, Fugitive와 Merginal을 통한 Git 작업
- tmux와 Neovim 창 이동 연동, 복사 시 클립보드 동기화
- UTF-8/EUC-KR 파일 읽기와 기본 4칸 들여쓰기

설정 위치는 Neovim에서 `:echo stdpath('config')`로 확인합니다.

| 환경 | 기본 설정 디렉터리 |
| --- | --- |
| macOS / Linux / WSL | `~/.config/nvim` (`XDG_CONFIG_HOME` 설정 시 그 아래 `nvim`) |
| Windows 네이티브 | `%LOCALAPPDATA%\nvim` |

해당 디렉터리에 `nvim/`의 내용을 배치하면 됩니다. 기존 설정은 먼저 백업하세요.
**현재 설정의 Windows 네이티브 호환성은 검증되지 않았습니다.** 아래 OS별 제약을 함께 확인하세요.

필요한 도구는 사용하는 기능에 따라 다릅니다.

| 기능 | 관련 외부 도구 |
| --- | --- |
| Neovim과 플러그인 설치 | Neovim, Git, GitHub 접근 |
| 파일·텍스트 검색 | `fzf`, `fd`, `ripgrep` (`rg`) |
| 언어 서버 | Node.js 등 각 언어 도구의 실행 환경 |
| Treesitter 파서 | 플러그인 버전에 맞는 컴파일러와 빌드 환경 |
| tmux 이동 | tmux |
| 아이콘 표시 | 설정에 맞는 Nerd Font |

첫 실행에서는 플러그인이 다운로드될 수 있습니다.
설치 후 `:Lazy`, `:Mason`, `:checkhealth`로 상태를 확인하세요.
지원되는 Neovim 버전과 빌드 도구는 사용 중인 플러그인 버전을 기준으로 확인해야 합니다.

주요 사용자 키맵:

| 키 / 명령 | 동작 |
| --- | --- |
| `<leader>gg` | Fugitive Git 화면 |
| `<leader>ft` | 현재 파일 디렉터리에서 터미널 열기 |
| `<C-h/j/k/l>` | Neovim/tmux 창 이동 |
| `<F4>` | Merginal 화면 전환 |
| `<F8>` | 홈 디렉터리의 `bible.txt` 열기·닫기 |
| `<F9>` | 복사 시 OS 클립보드 동기화 전환 |

Copilot 자동 제안과 CopilotChat은 `enabled = false`로 로드하지 않습니다. 기존 프롬프트와 설정은 보존하지만 비활성화 상태에서는 `config`가 실행되지 않아 `:CreateCommit`과 `COMMIT_EDITMSG`의 AI 커밋 메시지 자동 호출도 등록되지 않습니다. 저장 시 자동 포맷은 기본적으로 꺼져 있으며 수동 포맷은 사용할 수 있습니다. 기존 `lazy-lock.json`의 Copilot 항목은 잠금 버전 보존을 위해 남겨 두며 활성화를 뜻하지 않습니다.

## 셸과 tmux

fish 설정은 `fzf.fish`, `fnm`, `fd` 등 외부 도구가 설치되어 있다고 가정합니다.
Homebrew/MacPorts 경로와 개인 pnpm 경로, SSH 호스트 단축키가 포함되어 있으므로 사용 환경에 맞게 확인하세요.
`fish_package_install.fish`에는 Fisher, fzf.fish, Tide, nvm.fish, bass 설치가 정의되어 있지만,
현재 `fish/config.fish`에서 사용하는 `fnm` 자체를 설치하지는 않습니다.

zsh 설정은 Oh My Zsh, Powerlevel10k, zsh-syntax-highlighting을 참조합니다.
`install`은 이 zsh 설정과 WezTerm 설정을 자동으로 연결하지 않습니다.

tmux prefix는 `<C-Space>`입니다. `<C-h/j/k/l>`로 pane을 이동하고 prefix 이후 `|`와 `-`로 분할합니다.
복사 모드의 `y`는 현재 macOS의 `pbcopy`를 사용합니다.

`scripts/t`는 Bash, fzf, tmux를 사용합니다.
인자로 디렉터리를 전달하거나 `~/.project_path`에 공백으로 구분한 검색 경로를 넣어 세션을 선택합니다.
현재 경로 처리에는 `eval`과 따옴표 없는 변수가 사용되므로 신뢰할 수 있는 경로만 사용하고 공백이 있는 경로는 별도 확인이 필요합니다.

## 운영체제별 범위와 현재 제약

- **macOS:** Hammerspoon, Homebrew/MacPorts 경로, `pbcopy` 등 macOS용 설정이 포함되어 있습니다.
- **Linux / WSL:** 셸·tmux·Neovim 설정을 활용할 수 있지만 클립보드, 외부 도구, 개인 경로를 조정해야 합니다.
- **Windows:** AutoHotkey 설정과 WezTerm의 WSL 연결 설정이 있습니다. Unix 설치 스크립트를 Windows 네이티브 설치에 사용할 수는 없습니다.

Neovim과 WezTerm은 현재 `HOME` 경로를 이용해 OS를 추측합니다.
WezTerm에는 `WSL:Ubuntu-22.04`와 `/home/locate`가 고정되어 있습니다.
WSL용 Neovim 옵션에는 마지막 개행을 유지하지 않는 설정도 포함되어 있습니다.
따라서 전체 저장소의 공통 OS 지원을 전제로 적용해서는 안 됩니다.

현재 CI와 OS별 설정의 자동 검증은 구성되어 있지 않습니다. 로컬 인증 도구는 `python3 -B -m unittest discover -s tests -v`로 검사할 수 있습니다.
`nvim/lazy-lock.json`은 `.gitignore`에 포함되어 있지만 이미 추적 중이므로 변경 사항은 Git에 계속 기록됩니다.


## 프로젝트 방향과 AI 협업

목표는 macOS와 Windows 네이티브 PowerShell에서 가능한 한 동일한 개발 환경과 작업 경험을 유지하는 것입니다. 기존 WSL 사용 경험을 참고하며, 네이티브 Linux는 미검증 환경입니다.

- [개발 환경의 평가와 방향](docs/environment-direction.md)
- [AI 협업 지침](AGENTS.md)
- [로컬 GitHub 인증과 작업 절차](docs/ai-workflow.md)

동작을 바꾸지 않는 README·분석·평가·계획 문서는 검증 후 `main`에 직접 커밋·push합니다. 설정·코드·설치 방식과 AI 지침·인증·권한 절차 변경은 PR로 제출합니다. 문서와 동작 변경이 섞인 경우에도 PR을 사용합니다.
