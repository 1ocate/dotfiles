# 0012: PowerShell 프롬프트의 현재 Kubernetes 클러스터

- 상태: 진행 중
- 요청: fzf 선택 목록이 아니라 프롬프트에 현재 Kubernetes 클러스터를 표시한다.
- 기준: main 4122d9c, feat/kubernetes-prompt
- 실행 환경·범위: windows-powershell, PowerShell 7의 powershell/prompt.omp.json 원본. 기존 프로필·streaming·테마와 다른 환경은 유지한다.
- 관련 결정: ADR 0002의 단일 원본·기존 loader 방식에 따른 작은 세그먼트 추가로 새 ADR은 없다.
- 계획: 로컬 kubeconfig 파싱 세그먼트 → 가상 설정으로 실제 oh-my-posh 렌더 → 누락/기본 namespace/context 전환 검사 → 문서·리뷰·PR.
- 표시: ☸ cluster:namespace. namespace가 생략되면 default. 설정이 없으면 세그먼트만 숨긴다.
- 비대상: 클러스터 접속, 자격증명 출력/배포, context 변경, Kubernetes 도구 설치, PowerShell 5.1·macOS/WSL/Linux 테마 변경.

## 분석과 진행

2026-10-21 KST: 기존 프롬프트에 Kubernetes 세그먼트가 없고, PowerShell 7 프로필이 저장소 테마를 참조하는 것을 확인했다. 현재 도구는 oh-my-posh 31.8.0이며 kubectl도 설치돼 있다. 공식 kubectl segment의 parse_kubeconfig와 Cluster/Namespace 필드를 사용한다. 개인 kubeconfig는 테스트에서 읽거나 출력하지 않고 가상 파일만 사용한다. 기존 SSH 작업 브랜치와 사용자 변경을 보존하려고 별도 worktree에서 준비한다.

## 검증과 남은 일

2026-10-21 KST: `py -3 -B tests/kubernetes-prompt.py` 통과. 실제 oh-my-posh 31.8.0에 가상 KUBECONFIG만 전달해 실제 Cluster/Namespace, default, context 전환, 누락/잘못된 파일을 검사했다. 가상 kubectl 실행 시 marker를 남기도록 해 미호출을 확인했고, kubectl 파일이 없는 빈 PATH에서도 표시를 확인했다. `pwsh -NoProfile -File tests/prompt-profile.ps1`도 통과해 기존 streaming·프로필·사용자 테마/인코딩 보존을 확인했다.

독립 정적 리뷰에서 기능 차단 문제는 없었고 내장 테마에 streaming만 추가했다는 기존 사용 문구를 현재 Kubernetes 추가와 맞게 갱신했다. 현재 사용자의 기존 프로필이 현재 체크아웃의 테마 원본을 참조함을 확인하고, 원본에 기존 변경이 없을 때만 backup 후 같은 세그먼트를 반영했다. 프로필 초기화·연결·도구 설치나 개인 kubeconfig 읽기/변경은 수행하지 않았다. 적용 상태는 `.local/kubernetes-prompt-state.json`에 검증 필요로 남긴다.

최종 로컬 확인에서는 요청한 현재 대상을 확인하기 위해 세그먼트만 격리 렌더하고, 실제 로컬 kubeconfig에서 현재 클러스터 표시가 생성됨을 확인했다. PATH를 비워 kubectl 실행을 막았고 클러스터명·namespace·인증 정보는 출력·기록하지 않았다. 클러스터 API 접속이나 context 변경은 없다. 가상 설정 검사와 이 실제 로컬 읽기 확인을 구분한다.

PR 제출과 새 PowerShell 탭의 GUI 확인이 남았다. macOS·WSL·Linux 실기기 및 클러스터 연결 상태 확인은 범위 밖이다.
