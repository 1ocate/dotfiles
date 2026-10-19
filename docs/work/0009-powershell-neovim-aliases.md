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

현재 장치의 별칭 연결·실행 검증과 독립 검토·문서 링크·diff 확인을 완료하고 PR로 제출한다. 병합은 사용자가 결정한다. 진행 중 별도 세션에서 추가한 command-completion 파일·작업 기록도 이번 PR에서 제외한다.
