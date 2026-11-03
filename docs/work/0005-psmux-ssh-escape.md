# 0005: Windows psmux의 SSH 원격 Vim Esc 전달 조사

- 상태: 진행 중 (2026-11-03 psmux 3.4.0 업그레이드 적용·격리 검증, PR 리뷰 대기; 과거 조사 제출은 draft PR #12)
- 요청·배경: Windows psmux에서 세로 분할 후 SSH로 원격 Vim을 열고 삽입 모드에서 Esc를 눌러도 종료되지 않으며 Ctrl+C로만 복귀한다.
- 시작일: 2026-10-07
- 기준: 최신 main `73bbe35`, `fix/psmux-ssh-escape`; 기존 사용자 `nvim/lazy-lock.json` 수정 보존. 작업 0004/PR #11은 별도 목표다.
- 실행 환경·범위: `windows-powershell`. psmux 입력 전달과 격리 테스트·사용 지침. macOS/WSL tmux 설정, 원격 계정·설정, 도구 설치·업데이트와 실사용 서버 적용 제외.
- 관련 ADR: [ADR 0003](../adr/0003-windows-psmux.md)에 따른 입력 어댑터 조사에서 재개했다. 2026-10-20 후속 Windows Terminal 전송·실험용 빌드 결정은 [ADR 0009](../adr/0009-psmux-escape-build.md)에 제안한다.
- 관련 PR: [#12](https://github.com/1ocate/dotfiles/pull/12) (draft), [#30](https://github.com/1ocate/dotfiles/pull/30) (3.4.0 업그레이드, draft)

## 분석과 미확인 사항

2026-11-03 KST 재개: 기준 main `c6b271a`, `fix/psmux-search-escape`, windows-powershell.
사용자는 mux의 휠이 PowerShell 이력 이동/Codex 문자 입력으로 동작하고, 로컬 Neovim `/` 검색에서도 Esc로 나올 수 없다고 보고했다.
기존 사용자 문서·lockfile·폰트 파일 변경을 보존한다. 실제 Terminal Esc 계약 검사와 단독 encoded Esc raw/events 격리 검사는 통과했으나 검색 모드 검증은 없었다.
계획은 attached ConPTY 검사에 `/`, `?`, `:` 취소와 검색 확정 보존을 추가해 raw/encoded 경로를 비교하고, 재현 근거에 한정해 기존 ADR 0003/0009의 Windows 어댑터를 보완하는 것이다.
실사용 서버 재로드·연결·설치·SSH와 다른 OS 적용은 제외한다. 휠 원인은 아직 전경 판정/외부 마우스 모드 후보이며 ESC와 같은 원인으로 확정하지 않는다.
GitHub CLI가 현재 PATH에서 발견되지 않아 열린 PR 상태 조회는 실행하지 못했다. 로컬 검증과 PR 본문 준비까지 진행한다.

추가 보고: 작업 폴더를 지정한 세션이 사용자 홈에서 열린다. `Invoke-DotfilesMux`의 신규 `-c` 전달과 기존 세션 재사용을 구분한다.
격리된 실제 기본 셸/현재 프로필 세션과 명시 pwsh 세션 모두 한글·공백 작업 폴더의 실제 `Get-Location`이 지정 경로와 일치했다.
기존 세션은 위치를 재설정하지 않는 구현이며 사용자가 어떤 생성 경로를 사용했는지는 확인 대기다.

검증 진행: `python -X utf8 -B tests/windows-psmux.py --encoded-escape`는 기존 headless navigator의 Ctrl-h 외부 pane 이동 단계에서 실패해 새 검색 assertion까지 도달하지 못했다.
이를 검색 ESC 실패 재현으로 간주하지 않는다. 별도의 `tests/psmux-search-escape.py`로 attached-client 검색 취소 검사를 분리한다.

검색 전용 검사는 plain Neovim과 기존 LazyVim/Noice를 오프라인 로드한 구성 모두에서 raw/Windows Terminal encoded Esc로 `/`, `?`, `:` 취소가 통과했다.
Enter 검색 확정과 Ctrl+C 취소, 격리 서버 종료·사용자 lockfile 바이트 보존도 확인했다. 키를 한 덩어리로 보내면 psmux 붙여넣기 감지가 개입하므로 최종 검사는 키별 200ms 입력으로 분리한다(80ms는 host의 100ms 폴링에서 병합될 수 있어 보강).
기존 통합 검사에 잠시 추가한 중복 검색 검사는 제거하고 전용 검사만 유지한다. 물리 키보드·IME 증상은 아직 재현하지 못했다.
실제 Neovim의 읽기 전용 RPC 조회에서는 mode=n, 검색 Esc 별도 키맵 없음, timeoutlen=300/ttimeoutlen=50이었다. 실제 설정 junction도 저장소 원본을 가리킨다.
사용자는 Ctrl+C로 검색을 닫을 수 있음을 확인했다. 물리 ESC/IME 구분을 위해 ESC/Ctrl+C 종류와 모드만 임시 관찰하고 일반 문자·검색어는 기록하지 않는다. 관찰은 120초 뒤 자동 종료하며 실제 키 결과는 사용자 응답 대기다.
독립 리뷰는 실제 stdpath와 고정 사전 검사 경로 차이로 bootstrap 가능성을 지적했고 다운로드 차단 가드를 보강한다. 현재 사용자 설정·설치 binary·실사용 세션은 수정하지 않았다.

독립 리뷰 후 최종 검사: 실제 stdpath lazy 존재를 init 이전에 검증하고 없으면 cquit 2로 종료한다. NVIM_APPNAME/XDG_DATA_HOME이 다른 missing-lazy 환경에서 종료 코드 2·init sentinel 미실행·bootstrap 디렉터리 미생성을 확인했다.
상태/캐시/로그는 임시 경로에 두고 기존 설치 데이터만 참조한다. Ex 취소는 sentinel 미실행, Enter 확정은 다른 패턴 `another`와 커서 `[2,0]`으로 강화했다.
최종 plain raw/full Noice encoded 검사와 AST·대상 diff 공백 검사 통과, 독립 재리뷰 차단 문제 없음. 강화 전 plain encoded/full raw도 통과했으나 강화 후 네 조합 모두 재실행했다고 주장하지 않는다.
사용자는 영문·한글 모두 검색 Esc가 실패한다고 확인했다. 5분 임시 제어키 관찰을 새로 시작했으나 중간 조회는 전체 입력 개수 0으로 실제 물리키 결과를 판단할 수 없었다. 사용자 검사 응답 대기이며 해결 완료로 표시하지 않는다.

실사용 후속 관찰: 사용자는 mux 안에서만 한영 모두 검색 Esc가 실패하며, 현재 창의 두 번째 세션/pane에서도 발생한다고 확인했다.
관찰 중 총 입력 44/mode=c이나 제어키 Esc 기록이 없는 상태였고, 같은 Neovim 검색줄에 API Esc 1회를 전달한 비교에서는 Esc(mode=c) 기록과 mode=n 복귀를 확인했다.
이는 실제 사용자 증상과 격리 검사 결과가 다르다는 근거이며 모든 물리 Esc가 어떤 단계에서 유실되는지 확정한 trace는 아니다.
이후 psmux CLI로 Esc 전달을 비교하는 두 명령이 사용자에 의해 중단됐고 부분 실행 가능성이 있다. 사용자는 의도하지 않은 Esc 동작을 보고했다.
실사용 세션에 진단 입력을 보낸 것이 영향을 줄 수 있음을 설명하고 즉시 중단했다. 임시 on_key 관찰과 진단 변수를 RPC로 해제했으며 이후 실사용 세션의 키 전송·reload·재연결은 수행하지 않는다.
추가 재현은 격리 세션에서만 진행한다. 런타임 수정·해결 완료를 주장하지 않는다.

공식 upstream [#588](https://github.com/psmux/psmux/issues/588)은 `send-keys C-<letter>` 이후 ConPTY가 Win32 입력 모드로 latch되어 단독 ESC를 보류하는 결함을 설명한다.
현재 OS build 26200에서 `python -B tests/psmux-search-escape.py --latch-control-key`로 검색줄 준비 뒤 `send-keys C-a`를 보내면 mode=c가 유지되어 ESC 취소 assertion이 실패했다. cleanup과 lockfile 보존은 통과했다.
처음의 fresh-pane 성공과 이 선행 Ctrl 입력 후 실패를 구분한다. 이 결과는 현재 Ctrl+h/j/k/l 어댑터의 같은 send-keys C-* 경로와 일치하지만 모든 실제 키 경로를 trace한 것은 아니다.
휠의 raw SGR 문자 입력과 명령 이력 이동은 공식 [#598](https://github.com/psmux/psmux/issues/598)·[#597](https://github.com/psmux/psmux/issues/597)과 일치한다.
세 수정은 [v3.4.0](https://github.com/psmux/psmux/releases/tag/v3.4.0)에 포함되나 이후 [#860](https://github.com/psmux/psmux/issues/860) 등 입력 회귀 수정이 이어져 단순 버전 변경으로 해결을 보증하지 않는다. 설치본은 변경하지 않았다.

최종 비교: 원본의 `--latch-control-key` raw/encoded 모두 검색 모드 유지로 실패했고 cleanup/lockfile 보존은 통과했다. `--config`로 private 설정의 ESC fallback만 Win32 encoded `send-keys -H`로 바꾸면 raw+latch의 `/ ? :` 취소·Enter 확정·Ctrl+C는 통과했다.
이 private 경로에서는 기존 foreground marker ownership guard가 작동하지 않으므로 production 어댑터 전체 검증으로 보지 않는다.
독립 소스 검토에서 이 우회를 전체 root fallback에 적용하면 다른 앱의 프로토콜·popup/copy-search·synchronized input 의미가 바뀔 수 있음을 확인해 런타임 수정 후보로 채택하지 않았다.
진단의 결론은 새 pane baseline만으로 성공을 판단하면 안 되며, Ctrl/방향키 이후 ESC·마우스 등록·raw 입력 앱의 회귀를 함께 검증한 upstream 수정본이 필요하다는 것이다.
이번 요청에서는 재현 검사와 원인 기록을 제출하며 실제 psmux 업데이트·설정 연결·실사용 세션 재시작은 수행하지 않는다. 작업 폴더 문제는 신규 세션 정상/기존 세션 재사용 구분까지만 확인했으며 사용자 생성 경로가 미확인이다.

### 2026-11-03 다른 장치 적용 명세

업그레이드 검토 요청: 사용자가 psmux 업그레이드 고려를 요청했다. 공식 3.4.0 공개 portable 후보를 체크섬 검증해 `.local/`에만 준비하고 선택 가능한 `--binary`로 기존 3.3.8과 같은 격리 검사를 비교한다.
설치본 교체·PATH·프로필·설정 버전 변경·실사용 세션 재시작은 승인 범위에 포함하지 않는다. #588/#597/#598 수정 포함 여부와 출시 후 #845/#860 회귀를 구분하며 후보 실패 시 버전만 올리지 않는다.
완료 조건은 후보별 ESC baseline/Ctrl 선행·Noice 검색 취소·raw key reader·마우스/작업 폴더 검사와 미검증 범위를 기록하는 것이다. 아직 버전 선택 결정을 하지 않아 새 ADR은 작성하지 않는다.

공식 portable 3.4.0 (`20aa1d7`, 2026-10-13)을 공개 릴리스 asset digest와 대조했다. ZIP SHA256 `a66b6be7c13c6fa0dc3660a267b9e34eaa91a4eb7f07fbd55a0468018bd0f721` 일치, `.local/` 후보 디렉터리에만 전개했다.
같은 원본 config의 `--binary` 후보 검사에서 Ctrl-A 선행 후 raw/encoded 및 full Noice encoded 검색 검사 세 조합 모두 통과했다. 기존 3.3.8은 같은 선행 Ctrl 조건에서 실패했다.
기존 raw/events reader의 encoded ESC 단독·동시 modifier·지연 modifier 6사례도 후보에서 통과했다. 실제 keydown의 VK27/char0x1b와 후속 일반 x 입력을 확인했다.
마우스 미등록 fullscreen raw reader에 같은 SGR wheel up/down을 보내면 3.3.8은 raw 보고 두 개를 입력으로 받았고 후보는 0바이트였다. 두 버전 모두 후속 x 입력은 정상 도착했다.
이는 물리 휠·장시간 등록 회복·실제 Codex 기능 검증은 아니다. 지정 한글·공백 폴더에서 후보 기본 프로필 셸/명시 pwsh 세션의 실제 Get-Location 일치도 확인했다.
확장 navigator 검사에서는 후보의 headless 8검사와 초기 attached pane 이동은 통과했으나 삽입 모드 준비 단계가 실패했다. fixture 문제인지 후보 회귀인지 추가 확인 전 전체 통과로 기록하지 않는다.
모든 검사는 별도 데이터 경로/세션이며 종료와 lockfile 보존을 확인했다. 실제 3.3.8 설치·PATH·프로필·실사용 세션은 유지했다.

사용자가 이후 3.4.0 실제 업그레이드를 명시 요청했다. 기존 host 일치 windows-powershell 승인과 psmux 활성화를 확인했다. 설치본을 버전별로 보존하고 새 기본 데이터 root를 분리하며, 기존 pane은 실제 서버 PID의 실행 경로를 기준으로 유지한다([ADR 0013](../adr/0013-psmux-upgrade-isolation.md)).
구현 순서는 공통 Windows pin/loader·설치 스크립트 갱신 → 모의/격리 검사 → 검증된 portable의 새 버전 경로 설치 → 기존 loader 보존·PATH/feature 갱신 → 새 외부 PowerShell과 새 서버 버전 확인 → 로컬 상태 갱신이다. 기존 세션 종료·실사용 키 전송은 하지 않는다.

2026-11-03 KST 적용 결과: `%LOCALAPPDATA%\Programs\psmux\3.4.0`에 portable을 설치했고 두 실행 파일이 `3.4.0 (20aa1d7)`을 보고한다. 기존 두 프로필 loader는 그대로 재사용해 프로필 hash가 적용 전 백업과 같다.
사용자 PATH는 3.4.0을 3.3.8 앞에 두고 변경 전 값을 `.local/`에 보관했다. `setup-psmux.ps1 -Check`, 새 외부 PowerShell의 `Get-DotfilesMuxStatus`(Ready, Pinned/Active 3.4.0, 데이터 `%LOCALAPPDATA%\psmux\3.4.0`)와 새 서버 버전 확인을 통과했다.
이후 사용자가 기존 세션 정리를 명시 요청해 3.3.8 실행 파일의 `kill-server`로 옛 기본 데이터 경로의 `main`·프로젝트 세션을 종료했다. 3.3.8 설치본과 옛 데이터 경로는 복구용으로 남겼다.

격리 검사(3.4.0 설치본, 임시 데이터 경로, lockfile 보존 확인): `psmux-search-escape.py` plain과 `--latch-control-key --encoded-escape --full-config`, `windows-psmux.py` 기본·`--full-config`, `psmux-version-routing.ps1`(PowerShell 7·5.1), `psmux-runtime.ps1`(PowerShell 7), `environment-isolation.lua`(origin/main baseline)를 통과했다.
`environment-isolation.lua`의 실행 파일 mock이 3.3.8 경로에 남아 이 장치의 실제 3.4.0 파일을 읽는 문제를 발견해 3.4.0 경로로 고쳤다. `psmux-runtime.ps1`의 5.1 실행은 한글 경로 literal 인코딩으로 실패하며 origin/main에서도 같은 실패를 확인해 이번 변경과 분리한다.
`psmux-escape.py --encoded-escape`(Windows Terminal 경로)는 일반 단독 ESC와 modifier stress 30/30이 도착했다. 실패는 인코딩 ESC 뒤 raw `\x1b`를 보내는 `client-double-Escape`(두 번째가 다음 키와 함께 도착)와 ESC 두 레코드를 보내는 `client-Escape-unicode0`의 기대값 1로, 검사 조합의 구조적 기대값 문제이며 3.4.0 회귀로 판단하지 않는다.
`--wezterm` 전체 실행은 raw·encoded 모두 앞선 modifier stress 이후 keys/events 단독 ESC가 유실됐다. 같은 사례만 실행하면 3.4.0·3.3.8 모두 통과하고, 3.3.8 전체 실행도 동일하게 실패해 3.4.0 회귀가 아닌 기존 WezTerm VT 경로의 순서 의존 현상으로 기록한다. 주 터미널(Windows Terminal) 경로와 분리한다.

적용 후 사용자가 새 탭의 `mux`에서 `Session 'main' uses another configuration`을 보고했다. 격리 3.4.0 서버 대조로 다음 동작 차이를 확인하고 수정했다.
- 세션 `show-environment`에 `PSMUX_CONFIG_FILE`이 없고 서버 전역(`show-environment -g`)에만 있다. 세션 값이 없을 때만 전역 값을 읽도록 했다. 다른 원본·marker 없음은 계속 거절한다.
- CLI 인수의 감싼 따옴표를 3.3.8은 한 단계 벗기지만 3.4.0은 그대로 저장해 prefix+F/D가 깨진 명령을 실행한다. 3.4.0 CLI는 `\;`·`;`에서 명령을 나눠 reload 연쇄도 `source-file`만 남는다. F/D/reload 바인딩을 임시 conf 파일로 쓰고 `source-file`로 읽은 뒤 삭제하도록 바꿨다. 두 버전에서 저장 결과가 같음을 확인했다.
- 3.4.0은 서버가 없을 때 `list-sessions`가 오류로 끝나고, 대기 중인 셸 pane의 `pane_current_command`를 oh-my-posh로 보고할 수 있다. 검사 정리 확인과 취소 pane 판정만 이에 맞췄다. psmux.conf 분기는 nvim-insert·vim/fzf 이름만 보므로 셸 pane 동작은 같다.
수정 후 `windows-psmux-projects.py`(F 선택·취소, D, reload, 다른 원본 거절)와 `windows-psmux-project-latency.py`(reload 후 F/D 경로 유지·F 실행)가 3.4.0에서 통과했다. `psmux-version-routing.ps1`에 전역 marker 채택·다른 원본 거절·바인딩 파일 내용/삭제 모의 검사를 추가했다. 검사 harness 시작 단계의 일시적 접근 거부 1회는 재실행으로 통과했다.

2026-11-03 KST 후속 요청: 사용자가 `mux` 유지 필요성 재검토와 prefix+F의 느린 fzf 표시 개선 가능성 확인을 요청했다.
측정(외부 PowerShell, 3회): 프로필 없는 pwsh 297~331ms, 프로필 pwsh 1895~2433ms, runtime만 읽은 pwsh 720~750ms, 프로젝트 11개 열거 4~26ms, fzf 시작 16~22ms. 지연의 대부분은 F 창이 읽는 사용자 프로필이다.
psmux 원본 확인 결과 `display-popup` 명령은 `pwsh -NoProfile -Command`로 실행되고 서버 전역 환경을 받는다. F/D를 원본 설정의 popup으로 옮기고 `scripts/psmux-project-popup.ps1`이 runtime의 `Invoke-DotfilesProject`를 사용하게 했다([ADR 0015](../adr/0015-psmux-project-popup.md)).
검증 중 일부 바인딩만 담은 파일의 `source-file`이 3.3.8·3.4.0 모두 설정의 C-h·Esc·h/j/k/l·F/D 등 사용자 바인딩을 기본값으로 초기화함을 확인했다. 앞 커밋의 바인딩 파일 방식은 이 회귀를 일으켜 실사용 세션 5개에서 root C-h 바인딩이 없어진 것을 읽기 전용으로 확인했다.
`mux`는 이제 바인딩을 바꾸지 않고 `@dotfiles_config`에 원본 경로만 기록하며, `r`은 원본 설정의 `source-file -F '#{@dotfiles_config}'`로 둔다. popup에는 `TMUX`가 없어 popup을 연 세션의 port로 `switch-client`를 보낸다.
격리 3.4.0 결과: F→fzf 908/1058/1063ms(이전 1964ms), 프로젝트 F 선택·전환, 취소 시 popup만 닫히고 창 수 유지, D, reload 후 prefix·F/D popup·root C-h 유지, 다른 원본 거절 통과. 사용자 정의 `t`는 F/D에서 더 이상 읽지 않는다(현재 프로필에는 없음).
사용자가 세션을 직접 닫고 다시 연 뒤 기능은 동작하나 속도가 비슷하다고 보고했다. 읽기 전용 확인 결과 `main`은 변경 전부터 열려 있던 탭의 옛 `mux` 함수로 만들어져 F가 프로필 새 창 방식이고 root C-h도 없었다. 새 `WORK` 세션만 popup F였다.
추가로 폴더 열거·fzf를 `powershell/project-picker.ps1`로 분리해 popup에서 runtime 로드(첫 JSON 파싱 약 0.2초 포함) 전에 실행하게 했다. 격리 3.4.0에서 F→fzf 757/755/754ms, 프로젝트 F 선택·취소·D·reload·다른 원본 거절과 mock(7/5.1)·runtime 검사를 다시 통과했다.

다른 장치 적용 명세(windows-powershell, psmux 활성화 장치만): 이 PR은 psmux pin을 3.4.0으로 바꾸고 새 셸의 기본 데이터 경로를 버전별로 분리한다. macOS·WSL·Linux는 적용 대상이 아니다.
1. 로컬 변경 보존·main 갱신 후 `.local/environment.json`의 host 일치 windows-powershell 승인과 `.local/psmux.json` 활성화를 확인한다. 승인이 없으면 적용하지 않는다.
2. `pwsh -NoProfile -File .\scripts\setup-psmux.ps1 -Check`로 현재 상태를 읽고, 사용자 승인 후 기존 설치 명령 `powershell -NoProfile -File .\scripts\setup-windows.ps1 -ApprovePowerShell -WithPsmux`로 3.4.0을 SHA256 검증·설치한다. 기존 3.3.8 설치본·프로필 loader는 보존되고 PATH는 3.4.0이 앞에 온다.
3. mux 밖의 새 PowerShell 탭에서 `Get-DotfilesMuxStatus`가 Ready·ActiveVersion 3.4.0인지 확인하고 `mux`로 새 세션을 연다. 기존 3.3.8 세션은 자동 종료되지 않으며 정리는 사용자가 요청할 때만 `windows-setup.md`의 옛 경로로 수행한다.
4. 장치 결과는 해당 장치 `.local/setup-state.json`의 psmux 구성요소에만 기록한다.

아래 두 문단은 이전 검색 ESC 진단 검사 커밋 당시의 명세다. 그 커밋 자체는 런타임 동작을 바꾸지 않았다.
기존 psmux 3.3.8·Neovim·Windows .NET 컴파일러가 있는 장치에서 `python -B tests/psmux-search-escape.py`로 plain 검사,
`--encoded-escape`로 Terminal 원본 인코딩, `--full-config`로 이미 설치된 LazyVim/Noice를 검사한다. `--latch-control-key`는 3.3.8의 알려진 실패를 재현하며 종료 코드 1이 예상된다. `--config`는 기존 private 후보 파일만 읽는다. 도구가 없으면 설치하지 않고 중단한다.
private PSMUX_DATA_DIR에서만 세션을 만들고 종료하며 물리 키·IME·다른 OS 성공을 보증하지 않는다. 조사 결과는 해당 장치 로컬 기록과 이 작업 기록의 검증 한계로 구분한다.

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

2026-11-03 업그레이드 후: 새 탭 3.4.0 세션에서 물리 키 Esc·검색 취소·휠·IME와 실제 Codex 사용을 사용자가 확인한다. upstream 입력 회귀(#845/#860) 수정 버전은 별도 검토한다. 다른 Windows 장치는 아래 적용 명세에 따른다.
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

2026-10-21 KST 마무리 계획: 사용자가 동작을 확인하고 Windows에서 기본 적용을 유지하도록 요청했다. Windows 네이티브의 Windows Terminal 기본 설정에 한정해 필수 Esc 키/문자 보존 검사기를 설치 어댑터의 Plan/Check/연결 전에 호출한다. Uc=0·누락·중복 바인딩이 있으면 실제 설정 변경 전에 중단하도록 검증한다. 원본 키맵은 JSON 한 곳에 유지하고 검사기는 필수 계약만 확인한다. WezTerm·다른 OS에 검증 결과를 일반화하지 않는다. 사용자의 성공 보고는 사용자 기능 확인으로 기록하며 에이전트가 SSH 접속을 수행한 것으로 쓰지 않는다. 작업 완료 후 열린 PR의 중복·우선순위·남은 확인을 정리한다.

2026-10-21 KST 기본 경로 검증: PowerShell 7에서 `tests/windows-terminal.ps1` 통과(누락·Uc=0·중복 거절, legacy/modern 수용, 설정 보존·승인/호스트 차단·junction/재실행). `tests/windows-terminal-setup.ps1`도 통과해 기본 Windows Terminal 호출과 명시적 WezTerm 분리, Plan 무변경을 확인했다. 실제 사용자 설정을 이 검사로 다시 연결하지 않았고 현재 로컬 수정은 유지했다. 사용자 정상 확인에 따라 Esc 구성요소 로컬 상태만 완료로 기록하며 전체 설치나 다른 호스트 진행 기록은 변경하지 않는다.

2026-10-21 KST 재개: 사용자가 mux와 무관하게 발생하며 영어 전환은 되지만 Vim 모드가 유지된다고 보고했다. 현재 Terminal의 Win32 Esc action/keybinding은 유지되고 AutoHotkey도 실행 중임을 읽기 전용 확인했다. 앞선 합성 ConPTY 결과는 물리 입력과 동일한 원인으로 확정할 수 없다. 원격/로컬 Vim 구분과 초기 영문 상태 결과는 아직 미확인이다. SSH 접속 없이 별도 Terminal 진단 탭에서 Esc·Ctrl+[의 실제 ConsoleKey/KeyChar만 제한적으로 측정한다. 일반 문자·다른 창 입력은 기록하지 않으며 새로운 영구 바인딩 변경 전에 실제 이벤트를 확인한다.

2026-10-21 KST 실제 키 진단: 사용자가 진단 탭에서 입력한 두 Escape는 `ConsoleKey=Escape, KeyChar=0`, Ctrl+[는 `KeyChar=27`로 관측됐다. 기존 Uc=0 보정의 raw 전달/키 이름 검사만으로 문자 의미까지 검증했다고 볼 수 없음을 확인했다. Win32 Uc=27 후보와 문자값 0x1b 단언을 추가하고 직접 ConPTY·로컬 Neovim 회귀 후, 승인된 기존 로컬 보정의 Uc 필드만 0→27로 수정한다. 기존 설정 bytes·backup을 보존하고 실제 키 재확인을 요청한다. 이 관측만으로 최초 원격 증상의 원인까지 확정하지 않는다.

2026-10-21 09:53 KST 수정·적용: Uc=27 후보는 직접 ConPTY 및 기존 psmux native 경로에서 일반/Shift 동시 입력 raw/keys/events 각 6사례를 통과했다. 실제 `0x1b` 문자와 Escape 키를 함께 검증하도록 `--require-escape-character`를 추가했으며 독립 리뷰를 반영해 event의 vk=27·char=1B·keydown이 같은 레코드인지 단언한다. 기존 `tests/windows-psmux.py --encoded-escape` 통합 검사도 통과했다. 현재 Terminal settings의 해당 Uc 값만 수정하고 기존 bytes 보존·backup·재실행 확인을 완료했다. 이후 물리 키 재확인용 새 탭을 열었고 실제 Vim 모드 전환 결과는 사용자 확인 대기다. SSH 접속·서버 변경은 없다.

2026-10-21 KST 수정 후 물리 입력: 별도 실제 Windows Terminal 탭에서 Escape 두 번 모두 `ConsoleKey=Escape, KeyChar=27`, Ctrl+[도 문자값 27로 관측됐다. 수정 전 0/0/27과 달리 실제 Esc 문자 전달까지 확인했다. 일반 문자 기록·SSH 접속은 없었다. 최종 same-record 단언의 직접 ConPTY modifier/events 검사도 통과했다(첫 실행은 임시 helper 실행 단계의 Windows 접근 거부로 시작 실패, 1회 재시도 통과). 로컬 상태 파일에 수정 후 실제 control-key 결과와 Vim 모드 전환 확인 필요 상태를 갱신했다.

2026-10-20 KST 로컬 적용 요청: 사용자가 먼저 로컬에 적용하도록 명시하고 사용 터미널을 Windows Terminal로 확인했다. 현재 호스트의 유효한 windows-powershell 선택을 확인했다. 실제 stable Terminal settings는 저장소와 연결되지 않은 일반 파일이고 기존 bare Esc 바인딩이 없다. 현재 개인 프로필·다른 키를 유지하는 최소 실험 적용으로 Win32 Esc action과 keybinding만 추가한다. 쓰기 전 원본 backup, 동일한 원본 hash 재확인, 다른 JSON 값·주석/서식 보존 확인 후 적용한다. psmux 설치본·실행 중 세션·WezTerm은 바꾸지 않고 SSH는 연결하지 않는다. 기존 setup-state의 다른 호스트 기록은 보존하며 이번 호스트의 별도 .local/terminal-escape-state.json에 실제 결과와 물리 입력 확인 필요 상태를 남긴다.

2026-10-20 17:21 KST 로컬 적용 결과: stable Terminal의 기존 설정 파일을 같은 디렉터리에 backup하고, 검증한 `sendInput` Win32 Esc action 및 bare Esc keybinding만 추가했다. 적용 전 원본 bytes 재확인, backup 동일성, 적용 후 JSON 의미 비교와 bytes 일치, 재실행 시 추가 쓰기 없는 idempotent 확인을 통과했다. 개인 프로필·다른 단축키·기존 텍스트는 유지했다. 신규 설치·설정 디렉터리 연결·binary 교체·mux 재시작·SSH 접속은 없었다. backup 경로·hash와 검증 필요 상태는 위 로컬 상태 파일에 기록했다. 물리 Esc·IME·원격 증상 해결은 사용자 확인 전까지 미검증으로 유지한다.

Windows Terminal 로컬 적용·실제 키 문자27 및 사용자 정상 동작 확인까지 완료했다. PR 리뷰와 GUI 검색·선택/IME 세부 검증은 남았다. 사용자의 확인을 에이전트의 SSH 접속 검증으로 확대하지 않는다. 최신 main 통합 시 문서 두 파일의 충돌은 현재 지침과 기존 조사 내용을 모두 보존해 해결했다. 최종 상대 링크·Python 문법·diff 검사를 완료하고 기존 draft PR #12에 제출했다.
