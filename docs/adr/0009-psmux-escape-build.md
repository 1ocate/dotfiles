# 0009: Windows Esc 전달과 psmux의 modifier 유실 보정

- 상태: 제안
- 범위: windows-powershell의 선택 기능 psmux, [작업 0005](../work/0005-psmux-ssh-escape.md)
- 기존 결정: [ADR 0003](0003-windows-psmux.md)의 버전 고정 및 기본 설치는 유지한다.
- 선행 결정: [ADR 0005](0005-terminal-esc-ime.md)의 AutoHotkey IME 제어는 유지하며, 터미널 Esc 전송 바인딩을 두지 않는 선택을 변경하는 제안이다.

## 문제와 선택

psmux 3.3.8의 VT reader는 문자 없는 modifier 이벤트에서도 pending Esc를 취소한다.
SSH 설정이나 원격 Vim 상태를 추정해 모든 Esc를 Ctrl+\\ Ctrl+N으로 바꾸면 다른 원격 프로그램을 망가뜨릴 수 있다.
Win32/CSI-u 입력 변환은 과거 격리 검사에서 해결하지 못했다. 공식 3.4.0에도 같은 취소 경로가 남아 있다.

ConPTY에 raw Esc와 modifier 이벤트를 한 번에 쓰면 psmux에 도착하기 전에도 Esc가 사라졌다.
Windows Terminal의 기본 설정 원본에는 Esc를 Win32 VK_ESCAPE(Uc=27)로 전달하는 `sendInput` 바인딩을 둔다.
최초 Uc=0 후보는 물리 Console.ReadKey 검사에서 Escape 키지만 문자값은 0으로 관측됐다. 키와 실제 0x1b 문자를 함께 유지하도록 2026-10-21 Uc=27로 수정했다.
이는 Windows Terminal 전체 탭에 적용되는 키 전송 정책이며 mux/SSH/Vim 상태를 추측하지 않는다.
직접 ConPTY raw/Console.ReadKey/events 검사와 기존 psmux의 로컬 Neovim 회귀를 통과했다.
Esc의 의미는 한 번 유지하고 AutoHotkey의 Esc Up 영문 전환은 별도로 유지한다.
이번 수정은 실사용 설정에 연결하지 않은 격리 worktree에서만 수행했다. 실사용 settings 연결·복사는 하지 않는다.
향후 연결된 원본 체크아웃에 반영하면 Windows Terminal이 자동 reload할 수 있으므로 원본 반영과 실제 적용을 분리해 확인한다.
Windows Terminal GUI 검색·선택 취소와 한글 조합 중 Esc는 아직 실기기 검증하지 않았다.

WezTerm VT 경로는 Win32 Esc만으로 부족하므로 기존 설치본을 대체하지 않는 명시적 소스 빌드 도구도 제공한다.
공식 3.3.8 source archive와 변경 대상 파일의 SHA256을 고정하고, 문자 없는 Shift/Control/Alt만 무시하도록 수정한다.
의미 있는 VK·문자·paste·마우스 경로는 유지한다. build는 .local 아래 별도 산출물만 만들고 전역 PATH·프로필·실사용 서버는 수정하지 않는다.
Rust/Cargo와 GNU linker는 빌드 검증용 선택 의존성이며 기본 설치 의존성으로 추가하지 않는다.
기본 실행에 custom binary를 자동 선택하지 않는다. 실제 장비 적용·연결은 별도 요청과 검증이 필요하다.

WezTerm 원본의 자동 로드 Esc 바인딩은 변경하지 않는다. 수정 binary와 Win32 Esc를 함께 지정한 격리 검증만 제공하며, 물리 터미널 적용은 아직 실험 범위다.

## 검증과 재검토

동일한 격리 ConPTY 검사에서 원본 실패·수정본 성공을 확인하고, 일반 Esc·modifier·후속 문자·로컬 Neovim 입력 회귀를 확인한다.
실제 SSH 연결 및 물리 터미널/IME 확인은 이 검사를 대신하지 않는다. upstream에서 수정된 공식 릴리즈가 나오면 custom build를 제거하고 검증된 릴리즈 고정을 검토한다.
