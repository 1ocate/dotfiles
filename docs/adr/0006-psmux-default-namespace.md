# 0006: Windows psmux는 기본 namespace와 원본 설정 식별을 사용

- 상태: 제안
- 작성일: 2026-10-08
- 범위: windows-powershell
- 관련 작업: [작업 0003](../work/0003-windows-psmux.md), 후속 검증·구현 PR #16
- 선행 결정: [ADR 0003](0003-windows-psmux.md)의 named 서버 선택·보정 적용 범위를 보완한다. 채택 전에는 기존 ADR 상태를 대체됨으로 변경하지 않는다.

기본 namespace와 named namespace의 실제 클라이언트 비교에서 pinned 3.3.8은 named 대상 전환만 실패했다. named 선택은 최초 구현에 있었고 이후 h/Esc 보정의 원인이 아니다. 초기 ADR에는 namespace 대안 비교가 없으며 적용 범위와 다른 실행을 분리하는 역할은 코드에서 확인된다.

named namespace 유지와 upstream 포크 대신 기본 namespace를 사용한다. mux/t는 유지하고 -f로 이 체크아웃 tmux/psmux.conf를 읽는다. 보정 대상을 Windows 승인·활성화, 공식 psmux TMUX 기본 형식, PSMUX_SESSION, PSMUX_CONFIG_FILE과 DOTFILES_ROOT의 원본 경로 동일성으로 구분한다. 명령 이름이나 기본 namespace만으로 모든 psmux에 보정을 적용하지 않는다. 다른 원본으로 시작된 기존 동일명 세션은 덮어쓰지 않고 별도 세션 이름 또는 해당 사용자 설정 검토를 안내한다.

Ctrl+h의 Alt+h 운반과 M-h 연결, Ctrl+l, OSC133 foreground/insert marker, Esc의 Ctrl+\\ Ctrl+N 보정과 기존 prompt 상태 보존은 유지한다. F는 기존 t 선택을 실행하고 D는 저장소 경로를 t에 전달한다. 설치 스크립트에 런타임 키맵을 복제하지 않는다. macOS/WSL/Linux 경로는 변경하지 않는다.

Neovim junction, WezTerm/PowerShell loader, psmux -f 원본 참조를 유지한다. Windows Terminal도 directory junction을 통해 저장소를 참조하고 기존 설정을 백업한다. 설정 사본이나 양방향 동기화를 새 기본 방식으로 만들지 않는다. 기존 named 세션은 새 실행으로 자동 이전하지 않으며 종료는 작업 내용과 사용자 요청 범위를 확인해 별도로 처리한다. bare kill-server는 금지한다.

완료 조건은 실제 원본 wrapper/launcher, t 직접 경로·fzf 선택/취소·세션 전환/복귀, F/D 실제 dispatcher, Neovim 내부/외부 이동·insert/Esc·Backspace·prompt, 승인/다른 원본 negative 검사와 원본 연결 확인이다. 실제 ConPTY 검증과 물리 터미널/IME·다른 OS 실기기를 구분한다.

전체 흐름 검사에서 비ASCII 프로젝트 이름의 반복 underscore도 예약 namespace 구분자로 해석됨을 확인했다. 생성 이름은 반복 underscore를 하나로 줄이고 모두 비ASCII인 경우 project와 경로 해시를 사용하며 명시적인 __ 이름은 거부한다. 이를 세션 전환 검증에 포함한다.
