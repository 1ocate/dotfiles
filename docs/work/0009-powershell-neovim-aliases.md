# 0009: PowerShell의 vi·vim을 Neovim에 연결

- 상태: 리뷰 대기
- 요청·배경: 현재 PowerShell에서 `vi`·`vim`으로 Neovim을 실행할 수 없어 별칭 연결과 PR 제출을 요청했다.
- 시작일: 2026-10-19
- 기준: origin/main `2678b2f`, `fix/powershell-neovim-aliases`
- 실행 환경: windows-powershell
- 적용 범위·비대상: Windows PowerShell 5.1·PowerShell 7의 별칭 원본, 프로필 loader, Windows 설치 자동 호출, 현재 호스트 적용과 검증. 기존 Windows Terminal 폰트 변경·Neovim 설정·lockfile·키맵·다른 OS 설정은 제외한다.
- 관련 ADR: [ADR 0002](../adr/0002-native-windows-adapters.md)의 저장소 원본·프로필 loader·환경 격리 방식을 따르는 작은 기능 추가이며 새로운 구조 결정은 없다.
- 관련 PR: [PR #20](https://github.com/1ocate/dotfiles/pull/20)

## 분석과 미확인 사항

기존 Windows 설치는 Neovim 설치·설정 junction을 준비하지만 `vi`·`vim` 별칭을 등록하지 않는다. 현재 호스트의 두 사용자 프로필에도 별칭 설정이 없다. 유효한 windows-powershell 선택과 같은 호스트의 setup-state, Neovim 설정 junction을 읽기 전용으로 확인했다. 기존 `windows-terminal/settings.json` 사용자 변경은 보존하고 PR에서 제외한다.

## 계획과 완료 조건

1. 승인된 현재 호스트의 Windows PowerShell에서만 동작하는 별칭 원본을 추가한다. 실제 `nvim` 실행 파일이 있으면 `vi`·`vim`이 같은 실행 파일과 인자를 사용하고, 없으면 기존 별칭을 보존한다.
2. 두 사용자 프로필을 백업한 뒤 원본 loader만 추가하는 단독 진입점을 만든다. Plan/Check는 읽기 전용이고 재실행은 중복 추가·백업을 만들지 않는다. 전체 Windows 설치의 Plan/Check/적용에서도 호출한다.
3. 임시 프로필에서 승인·환경 격리·인코딩·백업·재실행을 검증하고, PowerShell 5.1·7에서 실제 Neovim의 격리 headless 실행과 인자 전달을 확인한다.
4. 사용자가 요청한 현재 장치의 프로필 loader를 연결하고 새 프로세스의 명령 해석을 확인한다. 장비별 적용 결과는 `.local/setup-state.json`에 따로 기록한다.
5. 통합 diff 독립 검토, 공백·문서 링크 검증 후 변경 파일만 커밋·push하여 한국어 PR을 제출한다.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-19 KST | 요청 범위와 기존 프로필 연결 구조 조사, 최신 main fetch·기존 사용자 diff 확인 | `2678b2f` 일치, 별칭 원본·자동 호출·현재 프로필 설정 모두 없음 | 구현·격리 검증 |
| 2026-10-19 KST | 별칭 원본·단독 연결기·전체 설치 자동 호출과 사용 지침 추가 | 현재 호스트 승인과 실제 실행 파일을 확인하며 두 프로필의 loader·backup·진행 상태를 관리 | 5.1·7 검증 |
| 2026-10-19 KST | 독립 리뷰의 무 BOM ANSI 프로필 손상 가능성 수정 | 모호한 인코딩은 쓰기 전에 거부하고 기존 프로필은 append만 수행. UTF-16/UTF-8 BOM과 ASCII 원문 바이트 보존 및 CP949/UTF-8 무 BOM 거부 회귀 검사 추가 | 실제 호스트 적용 |
| 2026-10-19 KST | 요청한 현재 호스트의 두 프로필을 백업하고 별칭 loader만 추가 | 새 사용자 프로필 프로세스 PS5.1·7에서 두 별칭 해석과 실제 격리 Neovim 실행 통과. Terminal·Neovim junction·lockfile·키맵은 변경하지 않음 | 최종 diff·PR |
| 2026-10-19 KST | 검증한 8개 파일만 `04b2f6e`로 커밋·SSH push하고 draft PR 제출 | [PR #20](https://github.com/1ocate/dotfiles/pull/20). 현재 호스트의 두 PowerShell 버전 연결 확인, GUI·신규 장비 전체 설치·다른 OS 미검증 범위 명시 | 사용자 리뷰·병합 판단 |

## 검증 결과

대상은 `2678b2f` 이후 별칭 관련 미커밋 diff다. 테스트 Neovim 실행은 `--headless -u NONE -i NONE -n`을 사용해 사용자 설정·플러그인·swap·shada를 사용하지 않았다.

| 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- |
| Windows PowerShell 5.1·PowerShell 7, 임시 프로필·모의 승인 어댑터와 실제 Neovim | `tests/powershell-aliases.ps1` | Plan/Check 무변경, 타 호스트 진행 기록 거부, 백업·인코딩·타 component 보존, 재실행, Unicode·공백·작은따옴표 경로, 실제 `vi`/`vim` 파일 인자 전달 통과. 설치기의 Python 승인 어댑터만 모의하며 런타임은 실제 fixture JSON을 읽음 |
| 동일 환경, 런타임 격리 | 같은 테스트의 승인 누락·손상·거절·문자열 승인·타 호스트·WSL·스키마 불일치·비 Windows·실행 파일 누락·ReadOnly 별칭 | 기존 별칭 보존, 경고 및 정상 환경의 재로드 통과. 다른 OS 실기기 검증은 아님 |
| Windows PowerShell 5.1·PowerShell 7, Windows 설치 정적·모의 검사 | `tests/windows-terminal-setup.ps1` | 기본/명시 터미널의 Plan과 필수 도구 검사, 별칭 Plan/Check/적용 세 호출의 AST 검사 통과. 전체 패키지 설치는 실행하지 않음 |
| Windows PowerShell 5.1, 기존 설치 회귀 | `tests/autohotkey-startup.ps1` | 기존 로그인 선택 분기·구문 통과, 설치·시작프로그램 변경 없음 |
| 현재 Windows 호스트, 실제 프로필 연결·새 프로세스 실행 | `scripts/setup-powershell-aliases.ps1`, `.local/verify-powershell-aliases.ps1` | 유효한 공통 승인 확인 후 PS5.1·7 loader 연결. 사용자 프로필을 읽은 새 5.1.26100.9711·7.6.7에서 vi/vim 모두 실제 Neovim 실행 통과. 결과·backup은 호스트 `.local/setup-state.json`에 별도 보존 |
| 통합 diff, 독립 정적 리뷰 | 별칭·설치기·테스트·문서 및 기존 변경 보존 검토 | 인코딩 지적 수정 후 추가 차단 문제 없음. 리뷰 역할이 실기기 검증을 대신하지 않음 |
| 통합 diff, 정적 검사 | PowerShell 5개 파일 AST, 변경 문서 3개의 상대 링크 대상, `git diff --check` | 구문·링크 대상·공백 검사 통과. 웹 문서·다른 OS 실행을 검증한 것은 아님 |

macOS·WSL·네이티브 Linux 실기기, GUI 편집·IME와 깨끗한 장비의 전체 설치는 미검증이다. 이번 변경은 Windows 별칭·프로필 연결 범위이며 해당 환경의 공통 설정이나 키 입력을 수정하지 않는다.

## 남은 일과 종료 근거

2026-10-21 KST PR #21 충돌 해결 계획: 사용자 요청으로 최신 origin/main d304474를 격리 worktree에 통합했다. 기준 PR head a17da2d, 실행 환경 windows-powershell이며 기존 사용자 체크아웃·설정 적용은 변경하지 않는다. 충돌은 ADR 목록에서 별칭 ADR 0008과 main의 Esc ADR 0009가 같은 위치에 추가된 부분이다. 두 결정을 모두 보존한다. 열린 PR #19도 ADR 0008을 쓰므로 별칭 ADR을 0010으로 옮기고 관련 링크를 갱신한다. 새 정책 결정이나 별칭 동작 변경은 없다. 통합 뒤 별칭·설치 경로 회귀, 문서 링크·공백·독립 리뷰를 확인하고 같은 PR 브랜치에 일반 push한다. PR 병합은 수행하지 않는다.

2026-10-21 KST 통합 검증: Windows PowerShell 5.1·PowerShell 7에서 `tests/powershell-aliases.ps1`, PowerShell 7에서 `tests/windows-terminal-setup.ps1`을 실행해 통과했다. 검사 범위는 임시 프로필·상태 보존·host/선택 독립·인코딩/백업/재실행과 실제 격리 Neovim 인자 전달, 설치기 Plan/별칭 자동 호출·터미널 분리다. 사용자 프로필 적용이나 실제 설치를 다시 실행한 것은 아니다. 기존 macOS·WSL·Linux 실기기 미검증 범위도 유지한다.

독립 정적 리뷰에서 main Esc 변경 보존, 기존 PR head 대비 별칭 코드·테스트 무변경, ADR 0010 링크 일치와 사용자 lockfile 미포함을 확인했고 차단 문제는 없었다. 상대 문서 링크·공백 검사를 통과했으며 충돌 표시는 제거했다. 같은 PR #21의 브랜치를 갱신하며 실제 PR 병합은 사용자에게 남긴다.

### 머지 후 적용 안내 보완

- 범위 변경·계획(2026-10-20 KST): 사용자가 장비 이름 없는 Windows PowerShell 공통 적용을 요청했다. [ADR 0010](../adr/0010-powershell-alias-platform-scope.md)에 따라 별칭의 승인·호스트 의존을 제거하고 연결 기록을 `.local/powershell-aliases.json`으로 분리한다. 기존 전체 설치 기록은 보존한다. Windows 5.1·7 격리 검사, 비 Windows 미적용, 호스트·선택 파일과 무관한 적용, 실제 사용자 프로필 연결·새 세션 검증 후 PR #21을 구현 중심으로 갱신한다. 이전 상태 초기화 확인 요청은 이 새 방식으로 대체한다.

- 요청·분석: 2026-10-20 KST, PR #20은 `32e4263`으로 병합됐지만 기존 장비에서 필요한 후속 연결 작업을 쉽게 찾기 어렵다는 피드백을 받았다. 기존 사용 지침에 명령은 있으나 병합·pull과 장비별 적용의 차이가 명확하지 않았다.
- 기준·범위: origin/main `32e4263`, `docs/neovim-alias-post-merge`, windows-powershell. README와 Windows 사용 지침에 적용 대상·일회 연결·새 탭 검증·상태 불일치 오류를 명시한다. 기존 ADR 0002의 연결 방식 설명이며 새 결정은 없다. 사용자 lockfile과 미추적 파일은 제외한다.
- 계획: 안내와 이 기록을 보완하고 실제 연결기와 문서 내용을 대조한 뒤 공백·상대 링크를 확인해 문서 PR로 제출한다. 사용자의 추가 요청에 따라 실제 별칭 연결도 시도하되 장비별 승인·상태 검사를 따른다.
- 진행: 현재 호스트의 PowerShell 승인은 유효하나 setup-state의 호스트가 달라 연결기가 프로필 변경 전에 중단했다. 과거 적용 검증 기록은 당시 결과로 보존하며 현재 장비의 적용 완료를 뜻하지 않는다. 기존 로컬 기록 보존 후 새 기록 시작 여부를 사용자에게 확인 중이다.
- 검증·한계: 실제 Windows 연결기에서 상태 불일치 오류를 재현했다. 별칭 적용·새 셸 실행 검증은 아직 완료하지 않았다. 문서 변경은 설치나 다른 OS 동작을 바꾸지 않는다.
- 제출: 문서 상대 링크 대상·`git diff --check`와 연결기 코드 대조를 통과했다. 안내 변경은 `a0650d9`로 제출했으며 [draft PR #21](https://github.com/1ocate/dotfiles/pull/21)에서 검토한다. 실제 장비 적용은 위 확인에 대한 답변 후 재개한다.

위 항목은 당시 중단 상태를 보존한다. 이후 사용자의 플랫폼 기준 적용 요청으로 기존 setup-state 초기화 대신 별칭 전용 기록 분리를 구현했다.

| 시각(시간대 포함) | 수행·근거 | 결과·다음 일 |
| --- | --- | --- |
| 2026-10-20 KST | PR #21 후속 미커밋 diff, Windows PowerShell 5.1·7에서 `tests/powershell-aliases.ps1` 실행 | 환경 파일 누락·손상·승인 거절·다른 장비·WSL 선택과 무관한 별칭 적용, 비 Windows 제외, Neovim 누락·ReadOnly 보존, 실제 파일 인자 전달, 인코딩·백업·반복 실행 통과. 새 상태의 host 필드 부재와 기존 setup-state 바이트 보존 확인 |
| 2026-10-20 KST | Windows 5.1에서 `tests/windows-terminal-setup.ps1`, 독립 읽기 전용 diff 검토 | 전체 설치 Plan/Check/Apply 별칭 자동 호출·환경 격리 회귀 검사 통과, 리뷰 차단 문제 없음 |
| 2026-10-20 KST | 사용자가 요청한 실제 장비에서 별칭 전용 연결기와 `-Check` 실행 | 두 프로필 백업·연결 성공, 기존 setup-state 바이트 보존, 장비 이름 없는 별도 상태 생성 |
| 2026-10-20 KST | 새 사용자 프로필을 읽은 PowerShell 5.1.26100.9711·7.6.7에서 `.local/verify-alias-platform.ps1` 실행 | vi/vim 해석과 실제 Neovim `--headless -u NONE -i NONE -n` 실행 통과. 기존 사용자 세션에는 새 탭 또는 원본 dot-source 필요. GUI·다른 OS 실기기·신규 전체 설치는 미검증 |

실제 별칭 적용과 검증은 완료했다. 코드·문서 통합 결과는 PR #21 리뷰·병합 대기이며 기존 lockfile·폰트·로그는 제출에서 제외한다.

현재 장치의 별칭 연결·실행 검증과 독립 검토·문서 링크·diff 확인을 완료하고 PR로 제출한다. 병합은 사용자가 결정한다. 진행 중 별도 세션에서 추가한 command-completion 파일·작업 기록도 이번 PR에서 제외한다.
