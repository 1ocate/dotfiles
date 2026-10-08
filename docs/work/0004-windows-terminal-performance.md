# 0004: Windows 터미널 지연 분석과 대안 평가

- 상태: 리뷰 대기
- 요청·배경: 터미널이 둔하게 느껴지는 원인을 확인하고 개선안, Windows 전용 터미널과 공통 설정 유지 방법을 제시한다.
- 시작일: 2026-10-07
- 기준: 최신 main `73bbe35`; 실사용 설정은 `d96f2e7`에서 확인했으며 main과 관련 구현 차이가 없다. 브랜치 `docs/windows-terminal-performance`.
- 실행 환경: `windows-powershell`; 현재 호스트의 유효한 선택과 구성요소 진행 기록 확인.
- 적용 범위·비대상: Windows 읽기 전용 진단과 평가 문서. 설치, 프로필·링크·렌더러 적용, lockfile 수정, 기존 세션 종료는 제외한다. macOS·WSL의 기존 동작을 유지하며 네이티브 Linux는 미검증이다.
- 관련 ADR: [ADR 0002](../adr/0002-native-windows-adapters.md), [ADR 0003](../adr/0003-windows-psmux.md). 이번 결과는 비교·개선 제안이며 공통 터미널 변경을 채택하지 않으므로 새 ADR은 작성하지 않는다.
- 관련 PR: [PR #11](https://github.com/1ocate/dotfiles/pull/11)

## 분석과 미확인 사항

2026-10-08 재개: 프로젝트 선택부터 세션 시작까지의 지연 개선 가능성을 요청했다. 실행 환경은 windows-powershell, 최신 main은 1f1bf3d, 측정할 실사용 원본은 PR #16의 85a4896이다. 사용자가 세션 전환이 현재 정상이라고 보고했으나 간헐 실패의 원인은 미확정이다. 실사용 체크아웃과 사용자 lockfile·폰트를 유지하고 문서 PR #11의 별도 worktree에서 분석 기록을 갱신한다. 실제 사용자 프로필·원본 연결·세션·설치는 변경하지 않는다.

분석 계획: (1) 프로필 유무의 자식 셸 시작과 Git completion/Oh My Posh/mux loader 비용을 반복 측정한다. (2) private PSMUX_DATA_DIR와 숨겨진 ConPTY helper에서 원본 F→fzf 관측, 선택→신규 세션 연결, 기존 세션 재사용을 분리한다. 사람의 선택 대기와 폴링 CLI 비용을 표시한다. (3) 임시 자식 셸에서 mux loader만 사용하는 경로를 비교해 개선 여지를 판단한다. 사용자 t override·prompt·취소 후 셸 보존·승인 및 원본 config 판별을 빼는 실험을 기능 동등한 구현으로 취급하지 않는다. (4) 결과·대안·남은 검증을 같은 문서 PR에 제출한다. 이번 범위는 평가이며 runtime 최적화나 새 구조 결정의 채택은 포함하지 않는다.

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
| 4b2b479 및 PR 연결 기록 diff | Windows 문서 검증 | 로컬 링크 검사, git diff --check, 독립 리뷰 | 통과. 문서 네 파일만 커밋, 기존 사용자 lockfile 변경 제외. 기본 prompt 5회 비교값도 평가 표에 기록 |
| 미커밋 문서 diff | Windows 정적 리뷰 | windows_reviewer: 터미널/psmux/AHK 키 경계와 공식 sendInput 문서 검토 | Ctrl+h, Ctrl+Space, Ctrl+Backspace, Ctrl+V와 IME 이전 제약 반영. 다른 OS 및 GUI 실기기 테스트 아님 |

## 남은 일과 종료 근거

분석 문서·재현 명령 작성과 로컬 검증 완료. PR #11 제출 완료, 병합은 사용자 리뷰를 기다린다. GUI 성능 비교와 실제 설정 적용은 후속 요청 범위이며 이 분석 PR의 완료 조건으로 오인하지 않는다.

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


## 프로젝트 실행 지연 재평가

2026-10-08 KST: 사용자 보고상 세션 전환은 현재 정상이며, 다음 목표로 fzf 선택부터 세션 시작까지의 지연 개선 가능성을 조사했다. main 1f1bf3d와 PR #16 85a4896을 구분했다. 실사용 원본을 전환하지 않기 위해 기존 문서 PR #11 branch를 .local/performance-review worktree에서 최신 main과 통합했다. 작업 목록 충돌은 0004와 0006을 모두 보존했다. 현재 source checkout의 사용자 lockfile·폰트는 수정/stage하지 않았다.

실제 windows-powershell 측정: py -3 -B .local/mux-shell-latency.py에서 새 자식 셸의 bare/full-profile/mux-only+Ready 각 5회와 구성요소 각 5회를 측정했다. 원본 함수는 현재 호스트의 Ready를 확인했다. bare 246.9ms, full-profile 2188.2ms, mux-only 778.7ms; git completion 870.3ms, OMP init 862.1ms, mux loader 214.4ms, 첫 prompt 405.6ms 중앙값. components는 각 새 NoProfile child에서 git/OMP/mux/prompt 순서로 측정하며 전체 startup과 단순 합산하지 않는다. root 성능 실행은 순차 진행했다. 하위 ConPTY probe의 초기 시도는 startup에서 실패해 유효한 동시 성능 표본을 얻지 못했다.

py -3 -B .local/mux-native-latency.py는 고유 temp registry에서 latency-0..4 세션의 new-session/has-session/show-environment/bind-key r source-file을 반복했다. 중앙값 135.2/39.3/38.0/36.1ms. new-session 반환은 실제 interactive prompt 준비 완료가 아니다. 생성한 이름만 kill-session으로 종료했다. pwsh -NoLogo -NoProfile -File .local/mux-directory-latency.ps1은 현재 roots 파일·루트와 바로 아래 폴더 생성(후보 2개) 및 fzf --filter를 반복하여 중앙값 5.6/19.3ms였다. 첫 목록 생성은 41.1ms이며 대규모·원격 경로에 일반화하지 않는다.

재현 구간: 기존 측정 재현 방법의 bare/profile 명령을 각 5회 실행하며 mux-only는 새 NoProfile child에서 현재 checkout powershell/psmux.ps1을 dot-source한 뒤 Get-DotfilesMuxStatus.Status가 Ready인지 확인했다. 디렉터리 생성은 Invoke-DotfilesProject의 동일 roots/Test-Path/Get-Item/Get-ChildItem/Sort-Object 구간, fzf 비교는 생성한 배열을 fzf --filter '^'에 전달했다. native 검사는 새 절대 temp PSMUX_DATA_DIR를 사용하고 TMUX/TMUX_PANE/PSMUX_* 라우팅 변수를 제거한 자식에서 -f 원본 conf new-session -d -s <자체 이름> -c <checkout>, has-session -t =<이름>, -t <이름> show-environment, -t <이름> bind-key r source-file <원본>을 Stopwatch와 동등한 perf_counter로 감쌌다. scratch probe는 실사용 설정 원본으로 설치하거나 commit하지 않는다.

판단: fzf 자체보다 프로필 초기화가 큰 개선 후보다. lazy Git completion/OMP init 시점 조정의 개선 여지를 제시하되 실제 기능 보존·첫 Tab/첫 prompt·사용자 t override·취소 셸·h/Esc·한글 경로·신규/기존 세션 통합은 후속 runtime 구현에서 검증해야 한다. 이번 요청은 가능성 평가이며 런타임/사용자 프로필/원본 연결은 바꾸지 않았다. 새 구조 결정의 채택은 하지 않는다.


2026-10-08 KST 통합 리뷰·한계: independent_reviewer는 수치·비동등 비교·전체 흐름 미측정의 구분이 적절함을 확인했으나 과거 문서의 Windows Terminal JSON/fragment 도입 및 WezTerm 전용 Esc 설명이 통합 main과 불일치한다고 지적했다. 현재 settings.json+junction 구현, Windows Terminal 일반 pwsh 후 mux 실행, AHK 실행 시 두 터미널 Esc 처리로 갱신했다. latency_probe의 ConPTY 측정은 4회 모두 공개 고정 오류 Could not create the psmux session. 이후 main attach timeout으로 성공 시간 표본 0이었다. 임시 registry와 helper의 생성·정리만 확인했고 실패를 런타임 해결 또는 GUI 성능 근거로 사용하지 않는다. 최초 원시 출력 진단은 auto-review가 개인 경로·프로필 노출 위험으로 거부했으므로 공개 오류 문자열/성공 bool만 추출한 안전한 진단으로 대체했다. 사용자 설정이나 인증 전문은 출력하지 않았다. root diff에는 기존 lockfile·폰트만 남으며 네 변경 문서의 상대 링크/충돌 표식·diff-check를 검증했다. PR #11에 이번 평가를 제출하고 실제 최적화·새 pane prompt/물리 GUI 시간 비교는 후속 작업이다.
