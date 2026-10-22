# 0016: 장치 통합 읽기 전용 점검

- 상태: 진행 중
- 요청: 다른 장치의 Codex가 적용 전 상태를 한 번에 확인하도록 통합 읽기 전용 점검부터 구현한다.
- 시작일: 2026-10-22
- 기준: main a0d3ee0, feat/device-status
- 실행 환경: windows-powershell; common 점검 로직과 Windows 전용 프로필/터미널 조사 분리
- 범위: 기존 environment.py의 플랫폼/선택/Neovim·WezTerm 검사 재사용, 새 device-status CLI와 JSON/텍스트 출력, 테스트·사용 문서
- 비대상: 설치/적용/상태 파일 자동 갱신, 프로필 실행, 도구 버전 명령, Git fetch/pull, SSH/클러스터 접속, 비밀 파일 읽기
- 관련 ADR: [ADR 0011](../adr/0011-codex-device-application.md), [ADR 0012](../adr/0012-readonly-device-inventory.md)

## 분석과 계획

기존 environment.py는 환경 선택과 두 앱 연결을 검사하지만 PowerShell loader/Windows Terminal/구성요소 로컬 기록을 한 번에 보고하지 않는다. 도구 존재·정적 참조·기록상 완료를 기능 검증과 구분해야 한다. root 사용자 변경과 병합된 PR #25의 로컬 원본 변경을 보존하려고 별도 worktree를 사용한다.

순수 파일·플랫폼·실행 파일 검색 기반 인벤토리를 작성한다. Windows Documents는 OS API로 찾고 프로필은 실행하지 않는다. 알 수 없는 프로필 표현식은 추측하지 않는다. Windows 전용 경로는 다른 환경에서 조사하지 않는다. 로컬 기록은 허용한 파일의 필요한 필드만 해석하고 값/인증 전문을 출력하지 않는다. 환경/호스트 불일치·기록 손상은 별도 표시하며 다른 검사를 계속한다.

테스트는 네 환경의 분기·기록 누락/오류/다른 호스트·잘못된 loader·개인 코드 보존·아무 파일도 쓰지 않음·외부 실행 없음·JSON/텍스트 출력을 검증한다. 현재 Windows의 실제 점검은 root 원본을 대상으로 읽기 전용 수행한다. macOS/WSL/Linux는 모의 검사와 실기기 검증을 구분한다.

## 다른 장치 적용 명세

- 구성요소: device-status, common (Windows 추가 검사 포함). 선택적 진단 도구이며 런타임 loader에 추가하지 않는다.
- 의존성: 기존 Python 3.10 이상. 추가 패키지 없음.
- 종류/적용: 원본 갱신만. py -3 -B scripts/device-status.py 또는 Unix python3 -B scripts/device-status.py로 실행한다.
- 검증: --json의 점검 상태·검증 한계와 실제 경로/파일 유무 대조. 존재/참조 발견을 기능 완료로 기록하지 않는다.
- 복구/기록: 진단은 쓰기를 하지 않아 복구/새 상태 저장이 불필요하다. 기록 자동 갱신·적용 계획/실행은 후속 단계다.

## 검증과 남은 일

구현·자동 검사·현재 Windows 실제 점검·OS/독립 리뷰·PR 제출이 남았다.

2026-10-22 KST 구현·검증: wrapper는 bytecode 쓰기도 막고 새 구현은 플랫폼/파일/PATH만 조사한다. Windows root 체크아웃을 --repo로 지정한 실제 점검에서 34개 항목(present 17, reference-found 10, missing 3, mismatch 2, unknown 2)을 출력했다. root의 장치 진행 기록 불일치와 Terminal 독립 설정을 서로 구분했으며 프로필 내용·기록 전문은 출력하지 않았다. 이 결과를 기능 완료나 설정 적용으로 기록하지 않는다.

Windows 리뷰의 문자열 내부 <# 오판을 quote-aware block comment 탐지로 고치고 테스트를 보강했다. PS5.1/7 Documents 리디렉션·loader/UTF16·WT 별도 채널·host-free aliases·foreign setupstate·mux 선택, 네 환경의 분리, 파일 쓰기/외부 실행 금지 등 가상 검사 16개와 기존 환경등록 검사 8개가 통과했다. WT 링크는 Path.resolve 모의이며 새 junction을 만들지 않았다. Windows/ macOS 역할의 정적 리뷰에서 환경 격리·검사 부작용 차단 문제는 없었다. WezTerm 맞춤 경로 미조사 한계도 사용 문서에 추가했다. macOS/WSL/Linux 실기기, 실제 profile/GUI 동작은 미검증이다.


최종 검증: 새 인벤토리 16개+기존 환경 8개(24개) 통과, Python AST와 문서 상대 링크/앵커 107개 통과. 실제 Windows CLI 전후 환경선택/진행/프로필/원본 8개 파일의 해시가 같고 bytecode 디렉터리도 새로 만들지 않았다. 독립 리뷰가 지적한 네트워크 공유 경로 한계를 문서·출력에 반영해 명시적 네트워크 요청 없음과 파일 공유 접근 가능성을 구분했다. 상태쓰기·외부실행·기능완료 오판의 다른 차단 문제는 없었다. 자동 적용과 로컬 기록 갱신은 후속 범위로 남긴다.
