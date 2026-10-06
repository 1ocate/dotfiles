# 0003: Windows PowerShell에서 psmux로 Neovim과 pane 이동 연결

- 상태: 제안
- 작성일: 2026-10-06
- 적용 범위: windows-powershell
- 관련 작업·PR: [작업 0003](../work/0003-windows-psmux.md), [PR #10](https://github.com/1ocate/dotfiles/pull/10)
- 채택 근거: 미결정. 로컬 적용 요청과 PR 병합을 구분한다.
- 대체 관계: 없음. [ADR 0002](0002-native-windows-adapters.md)의 Windows 어댑터 확장이다.

## 배경과 대안

회사 Windows는 WSL을 사용할 수 없다. 기존 tmux.conf의 Unix ps/grep, pbcopy와 Bash 프로젝트 선택기를 그대로 적용할 수 없다. WezTerm pane만 사용하면 현재 TMUX 기반 Neovim navigator와 세션 흐름을 다시 구현해야 한다. psmux v3.3.8은 네이티브 ConPTY, TMUX 환경, tmux.exe를 제공하며 선행 로컬 headless 검사에서 현재 navigator의 내부/외부 이동·zoom·두 세션 라우팅이 통과했다.

## 결정과 이유

선택 기능으로 psmux v3.3.8을 사용자 프로그램 경로에 준비하고 Windows 전용 원본 `tmux/psmux.conf`를 명시적으로 읽는다. 환경 승인과 호스트별 활성화 기록이 있을 때 WezTerm에서 저장소 launcher를 실행한다. 도구가 없으면 PowerShell로 돌아간다. macOS/WSL tmux와 Neovim 공통 설정 원본은 유지한다.

Windows 전경 프로그램은 psmux의 pane_current_command로 검사한다. Neovim/fzf에는 Ctrl+h/j/k/l을 전달하고 셸에서는 pane을 이동한다. 현재 Neovim navigator를 유지하며 tmux.exe PATH를 준비한다. psmux의 가장 깊은 자식 프로세스 검사로 LSP가 Neovim을 가리는 문제를 실검증했다. 승인된 Windows의 dotfiles pane에서만 Neovim은 OSC 133 실행·종료 표시를 보내고 셸 prompt는 이전 명령 상태를 초기화한다. 기존 prompt 내용과 오류 상태를 먼저 평가해 보존한다. 프로젝트 세션은 PowerShell 함수에서 공백·한글 경로를 개별 인수로 전달한다. Unix 프로젝트 목록을 eval하지 않는다.

## 영향과 재검토 조건

설치와 profile loader·사용자 PATH 변경은 명시적 적용 요청에서만 실행하고 기존 설정을 백업한다. 기본 Windows 설치에서 psmux를 강제하지 않는다. 이름 있는 서버를 사용하며 bare kill-server를 실행하지 않는다. 재부팅 후 프로세스 복원은 제공하지 않는다.

전체 LazyVim GUI·IME와 headless 검증을 구분한다. 전경 프로그램 감지 실패, 키 충돌, 릴리스의 라우팅 의미 변경이 발견되면 어댑터와 버전을 재검토한다.

근거: [v3.3.8 공식 릴리스](https://github.com/psmux/psmux/releases/tag/v3.3.8), [전경 프로그램 해석](https://github.com/psmux/psmux/blob/v3.3.8/src/format.rs), [OSC 133 처리](https://github.com/psmux/psmux/blob/v3.3.8/crates/vt100-psmux/src/perform.rs).
