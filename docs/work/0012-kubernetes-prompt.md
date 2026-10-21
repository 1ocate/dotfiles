# 0012: PowerShell 프롬프트의 현재 Kubernetes 클러스터

- 상태: 리뷰 대기
- 요청: fzf 선택 목록이 아니라 프롬프트에 현재 Kubernetes 클러스터를 표시한다.
- 기준: main 4122d9c, feat/kubernetes-prompt
- 실행 환경·범위: windows-powershell, PowerShell 7의 powershell/prompt.omp.json 원본. 기존 프로필·streaming·테마와 다른 환경은 유지한다.
- 관련 결정: ADR 0002의 단일 원본·기존 loader 방식에 따른 작은 세그먼트 추가로 새 ADR은 없다.
- 계획: 로컬 kubeconfig 파싱 세그먼트 → 가상 설정으로 실제 oh-my-posh 렌더 → 누락/기본 namespace/context 전환 검사 → 문서·리뷰·PR.
- PR: https://github.com/1ocate/dotfiles/pull/23
- 표시: ☸ cluster:namespace. ARN/경로는 마지막 클러스터 이름만 표시한다. 설정이 없으면 세그먼트만 숨긴다.
- 비대상: 클러스터 접속, 자격증명 출력/배포, context 변경, Kubernetes 도구 설치, PowerShell 5.1·macOS/WSL/Linux 테마 변경.

## 분석과 진행

2026-10-21 KST: 기존 프롬프트에 Kubernetes 세그먼트가 없고, PowerShell 7 프로필이 저장소 테마를 참조하는 것을 확인했다. 현재 도구는 oh-my-posh 31.8.0이며 kubectl도 설치돼 있다. 공식 kubectl segment의 parse_kubeconfig와 Cluster/Namespace 필드를 사용한다. 개인 kubeconfig는 테스트에서 읽거나 출력하지 않고 가상 파일만 사용한다. 기존 SSH 작업 브랜치와 사용자 변경을 보존하려고 별도 worktree에서 준비한다.

## 검증과 남은 일

2026-10-21 KST 표시 축약 요청: 사용자가 표시가 너무 길어 이름만 요청했다. 현재 세그먼트의 namespace 표시를 제거하고 .Cluster의 마지막 slash 뒤 이름만 표시한다. 단순 이름은 그대로 두고 ARN 형식의 가상 cluster를 추가해 계정·리전·경로 prefix가 노출되지 않는지 실제 렌더로 검증한다. 최초 cluster:namespace 검증은 당시 결과로 아래에 보존한다.

최종 축약 템플릿으로 Kubernetes 렌더 검사와 기존 프로필 검사 모두 재통과했다. 일반 이름 보존·ARN prefix 제거·namespace 미표시·현재 context 전환·설정 부재/오류·kubectl 미호출을 확인했다. 현재 체크아웃의 테마 원본에도 동일한 축약을 반영했다.

2026-10-21 KST: `py -3 -B tests/kubernetes-prompt.py` 통과. 실제 oh-my-posh 31.8.0에 가상 KUBECONFIG만 전달해 실제 Cluster/Namespace, default, context 전환, 누락/잘못된 파일을 검사했다. 가상 kubectl 실행 시 marker를 남기도록 해 미호출을 확인했고, kubectl 파일이 없는 빈 PATH에서도 표시를 확인했다. `pwsh -NoProfile -File tests/prompt-profile.ps1`도 통과해 기존 streaming·프로필·사용자 테마/인코딩 보존을 확인했다.

독립 정적 리뷰에서 기능 차단 문제는 없었고 내장 테마에 streaming만 추가했다는 기존 사용 문구를 현재 Kubernetes 추가와 맞게 갱신했다. 현재 사용자의 기존 프로필이 현재 체크아웃의 테마 원본을 참조함을 확인하고, 원본에 기존 변경이 없을 때만 backup 후 같은 세그먼트를 반영했다. 프로필 초기화·연결·도구 설치나 개인 kubeconfig 읽기/변경은 수행하지 않았다. 적용 상태는 `.local/kubernetes-prompt-state.json`에 검증 필요로 남긴다.

최종 로컬 확인에서는 요청한 현재 대상을 확인하기 위해 세그먼트만 격리 렌더하고, 실제 로컬 kubeconfig에서 현재 클러스터 표시가 생성됨을 확인했다. PATH를 비워 kubectl 실행을 막았고 클러스터명·namespace·인증 정보는 출력·기록하지 않았다. 클러스터 API 접속이나 context 변경은 없다. 가상 설정 검사와 이 실제 로컬 읽기 확인을 구분한다.

PR 리뷰와 새 PowerShell 탭의 GUI 확인이 남았다. macOS·WSL·Linux 실기기 및 클러스터 연결 상태 확인은 범위 밖이다.

2026-10-21 KST 후속 요청: 짧은 클러스터 이름은 유지하면서 namespace를 다시 표시한다. cluster:namespace 형식으로 템플릿·가상 렌더 검사·사용 문서를 갱신하고 현재 체크아웃 원본에도 반영한다. namespace가 비어 있으면 default를 표시하는 기존 세그먼트 동작을 검사한다.

후속 검증: 실제 렌더에서 빈 Namespace 필드가 빈 문자열로 전달됨을 확인해 템플릿에 default fallback을 명시했다. Kubernetes 가상 렌더 검사와 프로필 회귀 검사는 통과했으며 실제 클러스터에 접속하지 않았다.

2026-10-21 KST 충돌 해결 요청: 최신 main 196622f의 SSH 완성과 Ctrl+R 히스토리 기능을 보존하며 PR #23을 통합한다. 작업 목록/Windows 사용 문서의 충돌을 양쪽 기능이 남도록 정리한 뒤 Kubernetes 렌더·프롬프트·히스토리 회귀 검사와 diff 검토를 수행한다.

충돌 해결 결과: docs/work/README.md의 추가 행 충돌을 0011·0012·0013 순서로 모두 보존해 해결했다. Windows 사용 문서는 양쪽 설명이 자동 통합됐다. py -3 -B tests/kubernetes-prompt.py, pwsh -NoProfile -File tests/prompt-profile.ps1, pwsh -NoProfile -File tests/history-fzf.ps1 및 staged/working diff --check가 통과했다. 최신 main 대비 변경이 Kubernetes 관련 5개 파일 범위임을 검토했다. GitHub PR 브랜치에 통합 커밋을 push하고 병합 가능 상태를 확인한다. 실제 클러스터 접속·사용 환경 변경·main 병합은 수행하지 않았다.
