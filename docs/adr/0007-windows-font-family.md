# 0007: Windows 기본 글꼴의 비-Mono 패밀리 선택

- 상태: 제안
- 작성일: 2026-10-16
- 적용 범위: windows-powershell
- 관련 작업: [작업 0006](../work/0006-windows-terminal.md)
- 대체 제안: [ADR 0004](0004-windows-terminal.md)의 Mono 글꼴 선택 부분. 터미널 연결·키 입력·다른 OS 정책은 유지한다.

## 배경과 선택

사용자는 아이콘 크기를 기존처럼 유지하기 위해 `MesloLGMDZ Nerd Font`를 기본 사용하고 이후 설치에도 재현하길 요청했다. 기존 Mono 변형은 아이콘을 한 칸에 맞추므로 비-Mono 변형과 아이콘 폭이 다를 수 있다. 전체 글자 크기를 키우면 본문까지 바뀌므로 기본 패밀리를 비-Mono로 선택한다.

고정 upstream commit의 `MesloLGMDZNerdFont-Regular.ttf`를 사용하고 manifest의 family·full name·filename·SHA-256을 함께 변경한다. Windows Terminal과 Windows 네이티브 WezTerm은 이 패밀리를 우선한다. 기존 Mono 파일이나 등록은 삭제·교체하지 않으며 별도 이름으로 공존한다. Windows 사용자 범위 설치·충돌 시 중단·SkipFonts·읽기 전용 Plan/Check 원칙은 유지한다. macOS/WSL/Linux 글꼴과 셸 테마는 변경하지 않는다.

## 근거와 한계

2026-10-16 대화에서 사용자가 비-Mono 기본 선택과 향후 설치 재현을 요청했다. 이는 코드 변경 근거이며 이 ADR의 제안 상태는 PR 병합 시 정리한다. 실제 설치·사용자 설정 연결·merge 승인은 별개다. 고정 원본 다운로드의 hash/name table 확인과 모의 검사는 GUI 아이콘 표시나 신규 장비 전체 설치를 보증하지 않는다. 한 칸 아이콘 정렬이 필요한 앱에서 문제가 확인되면 Mono 선택을 재검토한다.
