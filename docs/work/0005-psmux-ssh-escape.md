# 0005: Windows psmux의 SSH 원격 Vim Esc 전달 조사

- 상태: 진단 완료, 실제 원격 확인·수정 미완료 (draft 제출)
- 요청·배경: Windows psmux에서 세로 분할 후 SSH로 원격 Vim을 열고 삽입 모드에서 Esc를 눌러도 종료되지 않으며 Ctrl+C로만 복귀한다.
- 시작일: 2026-10-07
- 기준: 최신 main `73bbe35`, `fix/psmux-ssh-escape`; 기존 사용자 `nvim/lazy-lock.json` 수정 보존. 작업 0004/PR #11은 별도 목표다.
- 실행 환경·범위: `windows-powershell`. psmux 입력 전달과 격리 테스트·사용 지침. macOS/WSL tmux 설정, 원격 계정·설정, 도구 설치·업데이트와 실사용 서버 적용 제외.
- 관련 ADR: [ADR 0003](../adr/0003-windows-psmux.md)에 따른 입력 어댑터 문제 조사. 새 공통 구조 결정 없음.
- 관련 PR: [#12](https://github.com/1ocate/dotfiles/pull/12) (draft)

## 분석과 미확인 사항

Windows psmux에는 Esc root binding이 있고 로컬 Neovim 삽입 모드에만 Ctrl+\ Ctrl+N 보정이 적용된다. SSH 뒤의 원격 Vim 모드는 Windows 로컬 marker로 알 수 없다. 일반 Escape 전달의 ConPTY 경로와 로컬 marker가 없는 편집기/SSH 입력을 검사한다. 사용자의 실제 원격 연결 정보나 서버 설정을 임의로 열거나 변경하지 않는다.

## 계획과 완료 조건

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

## 후속 작업

- 실제 원격 Vim에서 `vim -u NONE -i NONE` 재현 및 원격 tmux 사용 여부 확인. 결과에 따라 Vim 설정과 SSH/터미널 입력 경로를 나눈다.
- 실제 키/IME와 합성 modifier 이벤트의 일치 여부를 확인한 뒤 수정안을 선택한다. 현재 PR은 진단 코드·기록만 제출하며 draft로 유지한다.
- 임시 복귀는 Vim의 Ctrl+\ 다음 Ctrl+N이다. [Vim 공식 도움말](https://github.com/vim/vim/blob/master/runtime/doc/insert.txt)을 따른다. 실제 사용자 장비에서의 해당 chord 성공은 미확인이다.

## 최종 조사 범위와 리뷰 반영

Win32 VkEscape 후보도 psmux VT 입력에서는 UnicodeChar=0x1b 이벤트로 변환됐고, 이어지는 문자 없는 Shift 이벤트가 pending Escape를 취소했다. 격리 trace에서 이 순서를 확인했다. 따라서 런타임 설정 변경 없이 진단 코드와 사용 문서만 제출한다.

독립 리뷰에서 cleanup 예외가 host 종료와 lockfile 확인을 건너뛸 수 있다는 점, 후속 x 검사가 단순 부분 문자열이라는 점을 발견했다. 중첩 finally로 종료와 lockfile 확인을 보장하도록 보강하고 raw/keys/events별 실제 x 입력을 검사하도록 수정했다. 원격 Vim과 GUI 실기기 검증은 남아 있으므로 draft PR로 제출한다.

대조 재검증 중 helper가 제어 파일을 읽는 짧은 구간에 Windows 공유 잠금으로 쓰기가 거부되는 현상도 발견했다. 제어 명령의 PermissionError에만 제한된 재시도를 추가했다. 입력 데이터 자체의 재전송은 하지 않는다.

## 제출 전 최종 검증

- 총괄 재실행: psmux WezTerm VT 일반 Esc raw/keys/events 3사례 PASS. 후속 x 입력, 테스트 서버 종료와 사용자 lockfile 바이트 보존 확인.
- 합성 modifier raw/events 2사례는 Esc 유실로 의도한 assertion 실패. cleanup은 완료됐다.
- 직접 ConPTY Win32 encoded 단독/동시/지연 raw/events 6사례 PASS. 제어 파일 공유 충돌 보강 후 재검증 결과다.
- Python AST 문법, C# helper 실제 컴파일, 상대 문서 링크와 변경 파일 diff 공백 검사 PASS.
- 독립 리뷰의 cleanup/x 판정/ADR 문구를 반영하고 최종 제한 재시도도 정적 재리뷰 완료. 실제 원격 Vim, 물리 WezTerm 키/IME, macOS·WSL·Linux는 미검증이다.
