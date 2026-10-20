# 0005: Windows psmux의 SSH 원격 Vim Esc 전달 조사

- 상태: 리뷰 대기 (로컬 수정 후보 검증, draft PR #12)
- 요청·배경: Windows psmux에서 세로 분할 후 SSH로 원격 Vim을 열고 삽입 모드에서 Esc를 눌러도 종료되지 않으며 Ctrl+C로만 복귀한다.
- 시작일: 2026-10-07
- 기준: 최신 main `73bbe35`, `fix/psmux-ssh-escape`; 기존 사용자 `nvim/lazy-lock.json` 수정 보존. 작업 0004/PR #11은 별도 목표다.
- 실행 환경·범위: `windows-powershell`. psmux 입력 전달과 격리 테스트·사용 지침. macOS/WSL tmux 설정, 원격 계정·설정, 도구 설치·업데이트와 실사용 서버 적용 제외.
- 관련 ADR: [ADR 0003](../adr/0003-windows-psmux.md)에 따른 입력 어댑터 조사에서 재개했다. 2026-10-20 후속 Windows Terminal 전송·실험용 빌드 결정은 [ADR 0009](../adr/0009-psmux-escape-build.md)에 제안한다.
- 관련 PR: [#12](https://github.com/1ocate/dotfiles/pull/12) (draft)

## 분석과 미확인 사항

Windows psmux에는 Esc root binding이 있고 로컬 Neovim 삽입 모드에만 Ctrl+\ Ctrl+N 보정이 적용된다. SSH 뒤의 원격 Vim 모드는 Windows 로컬 marker로 알 수 없다. 일반 Escape 전달의 ConPTY 경로와 로컬 marker가 없는 편집기/SSH 입력을 검사한다. 사용자의 실제 원격 연결 정보나 서버 설정을 임의로 열거나 변경하지 않는다.

## 계획과 완료 조건

2026-10-20 KST 재개 계획: 사용자가 SSH 접속을 금지하고 원인 분석·수정을 요청했다. Windows 네이티브에서 기존 PR #12와 최신 main 32e4263을 격리 worktree에 통합한다. 실사용 SSH 자동완성 원본과 사용자 변경을 보존하며 SSH·원격 설정·실사용 mux 서버는 건드리지 않는다. 기존 3.3.8의 합성 modifier raw/events 두 사례 모두 Esc 0건 유실을 재현했다. 문자 없는 Shift/Control/Alt 이벤트가 pending Escape를 취소하는 upstream reader를 최소 patch하고, 임시 빌드 도구·산출물을 .local에 한정해 원본/수정 binary의 동일한 격리 transport 검사를 비교한다. 설치본 교체는 포함하지 않는다. v3.4.0 공식 소스에도 같은 무조건 cancel 경로가 남아 있어 단순 버전 갱신을 해결책으로 간주하지 않는다. dependency 패치·빌드 방식은 검증 후 별도 제안 ADR로 기록한다.

1. 최신 main, 기존 변경, 설치된 도구·원본 연결·승인 상태와 기존 작업 기록을 확인한다.
2. 별도 namespace/data 경로에서 실제 attached ConPTY 입력과 SSH형 raw 입력 소비자를 사용해 Escape 손실을 재현한다. 가능하면 연결 없이 Windows OpenSSH 클라이언트 입력 경로를 확인한다.
3. 재현 근거에 따라 Windows 입력 전달만 최소 수정하고 로컬 Neovim, 셸·터미널 및 분할 후 입력의 회귀를 검사한다.
4. 정적·실제 검사와 원격/GUI 미검증 범위를 기록하고 독립 리뷰 후 명시적 stage·커밋·push·PR 제출한다. 원본 파일 수정이 실행 중 서버 재로드를 뜻하지 않는다.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-07 KST (분 단위 미기록) | 사용자 보고 후 main fetch·설정과 기존 ConPTY 검사 분석, 하위 에이전트 읽기 전용 분석 분담 | main `73bbe35`, 사용자 lockfile 보존, Esc 보정은 로컬 nvim-insert marker에 한정 | 격리 입력 재현 |

## 검증 결과

미검증: 실제 원격 서버의 Vim, 물리 WezTerm/IME, macOS·WSL·Linux.

## 남은 일

원인 재현, 수정·검증·리뷰·PR 제출. 실사용 서버 재로드와 실제 원격 확인은 별도 적용 범위다.
## 재현과 수정 방향

- 2026-10-07 09:29 KST: 격리 attached ConPTY 검사에서 기본 raw ReadFile/Console.ReadKey/Event 소비자에는 Esc가 정상 전달됐다. WezTerm VT 입력에서 Esc 직후 문자 없는 Shift 이벤트를 동시 또는 5ms 간격으로 보내면 50ms pending Escape가 취소되어 후속 x만 도착했다. 실제 사용자 키/IME가 같은 이벤트를 만들었다고 확정하지 않는다.
- psmux v3.3.8 `ssh_input.rs`는 문자 0x1b를 pending 상태로 보관하지만 UnicodeChar=0인 VK 이벤트는 pending을 취소한 뒤 즉시 key event로 처리한다. 키 의미를 보존하는 명시적 VK_ESCAPE 입력을 WezTerm의 승인·psmux opt-in 분기에서 전달하는 방향을 검증한다. 원격 Vim을 추정해 SSH 전체 Esc를 Ctrl+\ Ctrl+N으로 바꾸지 않는다.
- 후보는 Win32 input sequence의 Vk=27, Sc=1, Uc=0, Kd=1, Cs=0, Rc=1이다. [Microsoft 입력 프로토콜](https://github.com/microsoft/terminal/blob/main/doc/specs/%234999%20-%20Improved%20keyboard%20handling%20in%20Conpty.md)을 참조한다. 수정 전 격리 psmux와 직접 ConPTY 소비자에서 일반 Esc/후속 문자 의미 보존을 검사한다.
- 관련 공통 파일 `.wezterm.lua`의 Windows 승인·도구 존재·opt-in 분기만 수정 후보이며 macOS/WSL/Linux 및 비활성화 경로는 유지한다. WezTerm은 원본을 자동 재로드할 수 있으므로 파일 수정 후 GUI 반영을 완전히 차단했다고 주장하지 않는다. 실행 중 psmux 서버 reload·원격 접속·설정 변경은 수행하지 않는다.

## 재현 결과와 미확인 경계

- 2026-10-07 09:34 KST: 기본 raw/Console.ReadKey/ReadConsoleInput 소비자 검사에서 일반 Esc 단독은 정상 전달됐다. 실제 사용자 서버의 Escape binding은 원본과 같고 원격 pane 전경은 ssh였으며 설정을 재로드하지 않았다.
- raw Esc와 문자 없는 modifier 이벤트 조합에서 입력 유실을 재현했다. 직접 ConPTY에서도 동시 조합은 유실되어 psmux의 50ms parser 대기만을 원인으로 확정할 수 없다. helper 제어 파일 기록 간격 5ms는 실제 물리 키 이벤트 도착 간격을 보증하지 않는다.
- Win32 VkEscape/Unicode0은 직접 ConPTY에서 단독·동시·지연 조합의 Esc 의미를 보존했으나 psmux 경유 stress에서 불안정했다. CSI-u와 modifyOtherKeys Esc는 psmux v3.3.8 경유에서 전달되지 않았다. 따라서 이 후보를 .wezterm.lua/tmux 원본에 적용하지 않았다. 앞 절의 방향은 검증 후 기각된 후보이며 구현 결과가 아니다.
- 테스트에서 발견한 합성 입력 유실과 사용자가 보고한 실제 WezTerm → SSH → 원격 Vim 문제를 동일 원인으로 확정하지 않는다. 원격 vim 기본 설정 재현 결과와 물리 키/IME 이벤트 확인이 남는다. 원격 host·인증 정보를 추측하거나 새로운 연결을 열지 않았다.

## 검사 명령과 해석

```powershell
# 기본 Esc 전달, 입력 의미와 cleanup 검증. 합성 modifier stress는 결과만 보고한다.
py -3 -B tests/psmux-escape.py --wezterm
# 알려진 합성 유실을 실패로 노출. 통과하지 않는 것이 현재 재현 근거다.
py -3 -B tests/psmux-escape.py --wezterm --require-all --case client-Escape-modifier --mode raw --mode events
# psmux 없이 ConPTY 자체와 대조. 테스트 compiler/helper/temp만 사용한다.
py -3 -B tests/psmux-escape.py --direct --encoded-escape --require-all --case client-Escape --case client-Escape-modifier --case client-Escape-modifier-delayed --mode raw --mode events
```

기본 검사의 PASS는 Esc 문제 해결을 의미하지 않는다. 이 도구는 실제 SSH·원격 Vim을 실행하지 않고 로컬 transport를 검사한다. 새로운 runtime fix가 선택되면 해당 입력 바이트를 기존 Neovim 기능 검사에도 연결해 회귀를 확인해야 한다.

## 검증 표

| 대상 | 환경·종류 | 근거 | 결과·한계 |
| --- | --- | --- | --- |
| main 73bbe35와 새 진단 코드 | windows-powershell 실제 격리 실행 | escape_probe 기본·WezTerm VT·직접 ConPTY·encoded 비교 | 일반 Esc 정상, 합성 stress 유실 재현. 후보 encoded는 psmux에서 미해결. 서버 종료·사용자 lockfile 바이트 보존 확인 |
| pinned 3.3.8 캐시 소스 | 읽기 전용 정적 분석 | ssh_escape_analysis: client/server/ssh_input 경로 | binding 재귀 없음; C-[/binding 제거는 같은 raw Esc 경로. CSI-u/mok 지원 없음. 다른 OS 실기기 테스트 아님 |

## 2026-10-07 당시 후속 작업

- 실제 원격 Vim에서 `vim -u NONE -i NONE` 재현 및 원격 tmux 사용 여부 확인. 결과에 따라 Vim 설정과 SSH/터미널 입력 경로를 나눈다.
- 실제 키/IME와 합성 modifier 이벤트의 일치 여부를 확인한 뒤 수정안을 선택한다. 현재 PR은 진단 코드·기록만 제출하며 draft로 유지한다.
- 임시 복귀는 Vim의 Ctrl+\ 다음 Ctrl+N이다. [Vim 공식 도움말](https://github.com/vim/vim/blob/master/runtime/doc/insert.txt)을 따른다. 실제 사용자 장비에서의 해당 chord 성공은 미확인이다.

## 2026-10-07 당시 조사 범위와 리뷰 반영

Win32 VkEscape 후보도 psmux VT 입력에서는 UnicodeChar=0x1b 이벤트로 변환됐고, 이어지는 문자 없는 Shift 이벤트가 pending Escape를 취소했다. 격리 trace에서 이 순서를 확인했다. 따라서 런타임 설정 변경 없이 진단 코드와 사용 문서만 제출한다.

독립 리뷰에서 cleanup 예외가 host 종료와 lockfile 확인을 건너뛸 수 있다는 점, 후속 x 검사가 단순 부분 문자열이라는 점을 발견했다. 중첩 finally로 종료와 lockfile 확인을 보장하도록 보강하고 raw/keys/events별 실제 x 입력을 검사하도록 수정했다. 원격 Vim과 GUI 실기기 검증은 남아 있으므로 draft PR로 제출한다.

대조 재검증 중 helper가 제어 파일을 읽는 짧은 구간에 Windows 공유 잠금으로 쓰기가 거부되는 현상도 발견했다. 제어 명령의 PermissionError에만 제한된 재시도를 추가했다. 입력 데이터 자체의 재전송은 하지 않는다.

## 제출 전 최종 검증

- 총괄 재실행: psmux WezTerm VT 일반 Esc raw/keys/events 3사례 PASS. 후속 x 입력, 테스트 서버 종료와 사용자 lockfile 바이트 보존 확인.
- 합성 modifier raw/events 2사례는 Esc 유실로 의도한 assertion 실패. cleanup은 완료됐다.
- 직접 ConPTY Win32 encoded 단독/동시/지연 raw/events 6사례 PASS. 제어 파일 공유 충돌 보강 후 재검증 결과다.
- Python AST 문법, C# helper 실제 컴파일, 상대 문서 링크와 변경 파일 diff 공백 검사 PASS.
- 독립 리뷰의 cleanup/x 판정/ADR 문구를 반영하고 최종 제한 재시도도 정적 재리뷰 완료. 실제 원격 Vim, 물리 WezTerm 키/IME, macOS·WSL·Linux는 미검증이다.

## 2026-10-20 수정 후보와 검증

이번 사용자는 SSH 접속을 금지했다. 실제 SSH·원격 Vim을 실행하지 않고 아래 로컬 결과만 근거로 수정했다. 조사 당시 사용 터미널 종류 확인 질문은 응답 대기 중이어서 기본 설정인 Windows Terminal과 WezTerm VT 경로를 나눠 후보를 준비했다. 이 단계에서는 실제 터미널·서버에 적용하지 않았으며, 후속 Windows Terminal 로컬 적용은 아래에 따로 기록한다.

| 입력과 대상 | 실제 로컬 격리 검사 결과 |
| --- | --- |
| 설치본 3.3.8, raw Esc+Shift, VT reader | raw/events 두 사례 모두 Esc 0건으로 재현 |
| modifier-only guard 수정본, raw Esc+Shift | 두 사례 계속 실패. trace에 해당 Esc가 아예 없어서 상위 ConPTY 유실도 확인 |
| 설치본 3.3.8, Win32 Esc+Shift, VT reader | 두 사례 Esc 0건. ConPTY 변환만으로 충분하지 않음 |
| 수정본, Win32 Esc, VT reader | 일반·Shift 동시/지연 raw/events 6사례 및 Control/Alt/좌우 modifier 16사례 모두 Esc 정확히 1건·후속 x 보존 |
| 설치본 3.3.8, Win32 Esc, native reader | 일반·Shift raw/events 4사례 통과 |
| psmux 없는 직접 ConPTY, Win32 Esc | 일반·Shift 동시/지연 raw/keys/events 9사례 통과 |
| 수정본 기본 입력의 로컬 Neovim | `tests/windows-psmux.py --binary <candidate>` 통과: 이동·삽입모드·Esc·Backspace·터미널 모드·세션 종료/lockfile 보존 |
| 설치본과 최종 Windows Terminal 원본 Esc 입력 | `tests/windows-psmux.py --encoded-escape` 통과. JSON BOM 처리 누락을 수정 후 재실행했고 실제 settings 바인딩을 읽음 |

수정 binary는 공식 3.3.8 archive SHA256 `4de52692b7f13f886d13b2d507df8fde36bfda80491eebf865d73ed416d571a3`를 검증한 소스에서 Rust/Cargo 1.90.0 GNU로 release 빌드했다. 산출물 SHA256은 `3a926c050c780858f66e981bc667218a1f9c9a2641bc23fa573f6ef5307bc198`다. 컴파일러·Cargo cache·빌드는 .local에만 준비했으며 설치 프로그램·전역 PATH·사용 중 binary를 바꾸지 않았다. 공식 [3.3.8](https://raw.githubusercontent.com/psmux/psmux/v3.3.8/src/ssh_input.rs) 및 [3.4.0](https://raw.githubusercontent.com/psmux/psmux/v3.4.0/src/ssh_input.rs) reader와 비교했다.

Windows Terminal 원본의 bare Esc는 Win32 VK_ESCAPE(Uc=0)로 보낸다. 전체 WT 탭에 적용되는 전송 정책이므로 mux 외 콘솔 프로그램의 직접 대조를 포함했다. AutoHotkey Esc Up은 그대로다. 실사용 설정의 조회 결과 이 worktree 원본과 연결되지 않은 `existing-directory`여서 자동 적용되지 않았다. 실제 연결된 체크아웃으로 반영하면 자동 reload될 수 있다. [ADR 0009](../adr/0009-psmux-escape-build.md)에 결정과 범위를 제안했다. ADR 0008은 열린 PR #19에서 이미 사용 중이라 번호를 재사용하지 않았다.

독립 Windows 정적 리뷰에서 rustup proxy가 누락 toolchain을 자동 설치할 수 있는 경계를 지적해 build 환경에 `RUSTUP_AUTO_INSTALL=0`을 추가했다. 원본/수정본의 같은 입력 대조는 실제 SSH 증상의 동일 원인을 확정하지 않는다. GUI 검색·선택 취소, 한글 조합·IME 및 다른 OS는 미검증이다. WezTerm source는 변경하지 않아 custom build와 Win32 Esc 조합의 실제 적용은 아직 자동화하지 않았다.

## 현재 남은 일

2026-10-20 KST 로컬 적용 요청: 사용자가 먼저 로컬에 적용하도록 명시하고 사용 터미널을 Windows Terminal로 확인했다. 현재 호스트의 유효한 windows-powershell 선택을 확인했다. 실제 stable Terminal settings는 저장소와 연결되지 않은 일반 파일이고 기존 bare Esc 바인딩이 없다. 현재 개인 프로필·다른 키를 유지하는 최소 실험 적용으로 Win32 Esc action과 keybinding만 추가한다. 쓰기 전 원본 backup, 동일한 원본 hash 재확인, 다른 JSON 값·주석/서식 보존 확인 후 적용한다. psmux 설치본·실행 중 세션·WezTerm은 바꾸지 않고 SSH는 연결하지 않는다. 기존 setup-state의 다른 호스트 기록은 보존하며 이번 호스트의 별도 .local/terminal-escape-state.json에 실제 결과와 물리 입력 확인 필요 상태를 남긴다.

2026-10-20 17:21 KST 로컬 적용 결과: stable Terminal의 기존 설정 파일을 같은 디렉터리에 backup하고, 검증한 `sendInput` Win32 Esc action 및 bare Esc keybinding만 추가했다. 적용 전 원본 bytes 재확인, backup 동일성, 적용 후 JSON 의미 비교와 bytes 일치, 재실행 시 추가 쓰기 없는 idempotent 확인을 통과했다. 개인 프로필·다른 단축키·기존 텍스트는 유지했다. 신규 설치·설정 디렉터리 연결·binary 교체·mux 재시작·SSH 접속은 없었다. backup 경로·hash와 검증 필요 상태는 위 로컬 상태 파일에 기록했다. 물리 Esc·IME·원격 증상 해결은 사용자 확인 전까지 미검증으로 유지한다.

Windows Terminal 로컬 적용 후 물리 입력 검증 및 PR 리뷰가 남았다. SSH 접속 없이 확인한 로컬 유실 경로의 수정 후보이며 원격 증상 해결 완료로 기록하지 않는다. 최신 main 통합 시 문서 두 파일의 충돌은 현재 지침과 기존 조사 내용을 모두 보존해 해결했다. 최종 상대 링크·Python 문법·diff 검사를 완료하고 기존 draft PR #12에 제출했다.
