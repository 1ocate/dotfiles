# 0004: Windows 터미널 지연 분석과 대안 평가

- 상태: 리뷰 대기
- 요청·배경: 터미널이 둔하게 느껴지는 원인을 확인하고 개선안, Windows 전용 터미널과 공통 설정 유지 방법을 제시한다.
- 시작일: 2026-10-07
- 기준: 최신 main `73bbe35`; 실사용 설정은 `d96f2e7`에서 확인했으며 main과 관련 구현 차이가 없다. 브랜치 `docs/windows-terminal-performance`.
- 실행 환경: `windows-powershell`; 현재 호스트의 유효한 선택과 구성요소 진행 기록 확인.
- 적용 범위·비대상: Windows 읽기 전용 진단과 평가 문서. 설치, 프로필·링크·렌더러 적용, lockfile 수정, 기존 세션 종료는 제외한다. macOS·WSL의 기존 동작을 유지하며 네이티브 Linux는 미검증이다.
- 관련 ADR: [ADR 0002](../adr/0002-native-windows-adapters.md), [ADR 0003](../adr/0003-windows-psmux.md). 이번 결과는 비교·개선 제안이며 공통 터미널 변경을 채택하지 않으므로 새 ADR은 작성하지 않는다.
- 관련 PR: 준비 중

## 분석과 미확인 사항

현재 WezTerm은 네이티브 PowerShell과 선택 기능 psmux를 시작한다. 로컬 프로필에는 Git completion, Oh My Posh, psmux 원본 로더가 있다. 렌더링, 프로필 초기화, prompt, psmux 입력 경로를 구분해야 한다. 실제 타이핑·스크롤 지연, GPU 사용과 물리 키/IME 반응은 headless 명령으로 확정할 수 없다.

## 계획과 완료 조건

1. 최신 main, 기존 사용자 diff, 원본 연결과 로컬 선택·적용 상태를 읽기 전용으로 확인한다.
2. 셸 시작·prompt 시간을 반복 측정하고 설정의 지연 후보를 정적 분석한다. 사용자 프로필의 통상 실행은 진단으로만 수행한다.
3. Windows Terminal·Alacritty를 공식 문서와 비교하고 동일 작업 흐름의 어댑터 경계를 제시한다.
4. 개선 우선순위, 실제 확인과 미검증 범위를 평가 문서에 기록한다. 문서 링크·diff 검증 후 커밋·push·PR로 제출한다.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-07 KST (분 단위 미기록) | 지연 원인과 현재 작업을 구분하기 위해 저장소·상태·설정 분석, Windows 리뷰 분담, main fetch | 기존 `nvim/lazy-lock.json` 변경 보존. main에 PR #10 병합 확인. 도구 호출 대기와 실제 명령 실행 시간은 별개이므로 대기 시간을 셸 성능 근거로 쓰지 않음 | 반복 측정과 개선안 문서 작성 |
| 2026-10-07 09:01 KST | 프로필·prompt 반복 측정, 원본 연결·공식 문서 확인, Windows/독립 리뷰 통합 | 프로필 유무 약 2.22초 차이와 prompt 약 0.29초 확인. sandbox 실패값 제외. JSON escape 수정 및 Alt+Space 충돌 반영. 로컬 문서 링크·공백 검사 통과 | 문서만 커밋·push·PR 제출; GUI 비교·적용은 후속 요청 |

## 검증 결과

측정 표본과 한계의 원본은 [평가 문서](../windows-terminal-performance.md)에 둔다.

| 대상 커밋 또는 diff | 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- | --- |
| `73bbe35` 설정과 기존 호스트 프로필 | windows-powershell 실제 실행 | pwsh 프로필 유무 5회, prompt 저장소 안/밖 각 5회, 초기화 구성요소 분리, Oh My Posh debug/version | bare 중앙값 227.4ms, profile 2443.0ms, repo prompt 293.2ms. GUI/ConPTY 렌더링 지연은 미측정 |
| 같은 설정 | windows-powershell 읽기 전용 | Neovim junction, WezTerm loader, 도구 버전, 로컬 선택·구성요소 상태 | 현재 체크아웃 연결 확인. 설치·연결·세션 생성/종료 없음 |
| 미커밋 문서 diff | Windows 정적 리뷰 | windows_reviewer: 터미널/psmux/AHK 키 경계와 공식 sendInput 문서 검토 | Ctrl+h, Ctrl+Space, Ctrl+Backspace, Ctrl+V와 IME 이전 제약 반영. 다른 OS 및 GUI 실기기 테스트 아님 |

## 남은 일과 종료 근거

분석 문서·재현 명령 작성과 로컬 검증 완료. PR 제출·병합 상태를 확인한다. GUI 성능 비교와 실제 설정 적용은 후속 요청 범위이며 이 분석 PR의 완료 조건으로 오인하지 않는다.

## 측정 재현 방법

현재 사용자 프로필은 통상 실행되며 자체 코드의 부작용이 있을 수 있으므로 내용을 먼저 읽고 진단 범위에서 실행한다. 아래 `$probeShell`은 `Get-Command pwsh`로 얻는 실제 설치 경로다. 실제 측정도 같은 Stopwatch 방식으로 자식 프로세스 시작부터 종료까지 시간을 쟀다.

```powershell
$probeShell = (Get-Command pwsh).Source
foreach ($probeMode in @('bare', 'profile')) {
    1..5 | ForEach-Object {
        $probeWatch = [Diagnostics.Stopwatch]::StartNew()
        if ($probeMode -eq 'bare') {
            & $probeShell -NoLogo -NoProfile -Command 'exit 0'
        } else {
            & $probeShell -NoLogo -Command 'exit 0'
        }
        $probeWatch.Stop()
        '{0}: {1:N1} ms' -f $probeMode, $probeWatch.Elapsed.TotalMilliseconds
    }
}
& $probeShell -NoLogo -Command '1..5 | ForEach-Object { $s = [Diagnostics.Stopwatch]::StartNew(); $null = prompt; $s.Stop(); $s.Elapsed.TotalMilliseconds }'
```

저장소 밖 비교는 마지막 자식 셸 명령 앞에 `Set-Location $env:TEMP;`를 추가했다. 구성요소는 새 `-NoProfile` 셸에서 `. ./powershell/git-completion.ps1`, `oh-my-posh init pwsh --eval | Invoke-Expression`, `. ./powershell/psmux.ps1`을 순서대로 각각 Stopwatch로 측정했다. `oh-my-posh debug` 출력은 세그먼트 시간만 추려 기록했고 prompt·개인 경로 전체는 공개 기록에 복제하지 않았다.
