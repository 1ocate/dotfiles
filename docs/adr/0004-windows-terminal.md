# 0004: Windows 네이티브의 주 터미널과 설정 원본 연결

- 상태: 제안
- 작성일: 2026-10-07
- 적용 범위: windows-powershell
- 관련 작업·PR: [작업 0006](../work/0006-windows-terminal.md), [draft PR #13](https://github.com/1ocate/dotfiles/pull/13)
- 채택 근거: 사용자가 Windows에서는 Windows Terminal을 사용하도록 세팅하는 방향을 명시했다. 구현 PR의 병합과 실사용 적용은 별도로 기록한다.
- 대체 관계: ADR 0002의 Windows 기본 터미널 선택만 변경하는 후속 결정. Neovim·psmux 원본 및 macOS/WSL 구성은 유지한다.

## 배경과 대안

Windows 설치는 WezTerm을 필수로 설치·연결한다. 사용자는 PC 세팅 중 Windows Terminal에서 tmux를 직접 실행했고 기본 초록색 상태바와 키맵을 보고했다. 별도 mux 함수는 저장소 psmux 설정을 읽지만 호스트 불일치 때 조용히 등록을 중단했다. 호스트별 로컬 승인 기록은 명시적 요청으로 백업·복구했다.

Windows Terminal을 Windows의 주 터미널로 삼고 PowerShell·Neovim·psmux 원본은 공유한다. WezTerm은 기존 사용자를 위한 명시적 선택으로 남긴다. Windows Terminal은 기존 PowerShell 사용자 프로필을 보존하여 PowerShell 탭에서 mux를 명시적으로 실행한다. psmux는 선택 기능이며 설치·자동 시작을 강제하지 않는다.

## 설정 연결 선택

Windows 전용 JSON 원본을 저장소 `windows-terminal/`에 두고 Windows Terminal의 설정 디렉터리를 junction으로 연결한다. Windows Terminal의 fragment는 프로필·색상만 지원하고 키맵·기본 프로필을 연결하지 못한다. 파일 심볼릭 링크는 현재 회사 PC의 권한으로 생성할 수 없음을 검증했다. 정책·Developer Mode·관리자 권한을 자동 변경하지 않는다. hardlink는 Git의 파일 교체 이후 연결이 끊길 수 있어 사용하지 않는다. 독립 복사본과 양방향 동기화도 만들지 않는다.

디렉터리 junction은 파일 심볼릭 링크 권한이 필요 없고 Git checkout·설정 UI의 파일 교체도 원본 디렉터리에서 처리한다. 기존 설정 디렉터리 전체를 별도 sibling backup으로 이동하여 사용자 설정·runtime state를 보존한다. 삭제하거나 공유 설정으로 자동 복제하지 않는다. 원본 디렉터리에는 Windows Terminal이 새 상태·캐시를 생성할 수 있으므로 `.gitignore`는 settings.json과 자체 ignore 파일을 제외한 모든 항목을 제외한다. Git stage는 관리할 파일만 명시하고 설정 UI가 생성한 개인 프로필·계정 정보를 diff에서 검토한다. 해당 checkout은 한 호스트·한 Terminal channel의 원본으로 사용한다.

junction 생성 실패 시 기존 디렉터리를 이동하기 전에 중단하고, 교체 실패 시 백업을 복원한다. 같은 연결은 유지한다. 실행 중인 Windows Terminal을 강제 종료·재시작하지 않으며 연결 시 모든 창을 닫고 별도 PowerShell에서 실행하도록 안내한다. UI 저장 후 원본 diff와 연결을 점검한다.

## 키 입력과 영향

Windows Terminal 폰트는 사용자가 지정한 `MesloLGMDZNerdFontMono-Regular.ttf`의 실제 패밀리를 사용한다. Windows 설치는 파일명·패밀리·upstream commit·SHA-256을 저장소 manifest에 기록하여 지정 변형을 준비하고 검증한다. 폰트 바이너리는 저장소에 포함하지 않고 upstream에서 받는다. 기존 임의 Meslo 파일의 존재를 지정 변형 설치의 근거로 사용하지 않는다. 설치는 Windows 사용자 범위로 제한하며, 이 구현·결정은 실사용 폰트 설치 승인이 아니다. macOS/WSL의 기존 폰트 선택은 유지한다.


Windows Terminal의 기본 키 전송을 우선하고 Ctrl+Space는 psmux prefix에 전달한다. Ctrl+V는 Neovim Visual Block을 위해 터미널 붙여넣기에서 해제하고 Ctrl+Shift+V를 사용한다. WezTerm의 Ctrl+h→Alt+h 전송을 다른 터미널에 무조건 복제하지 않는다. Ctrl+h는 실제 입력 경로를 검증하고 Alt+h 대체 동작과 미검증 범위를 기록한다. Windows Esc 영어 전환은 기존 WezTerm 범위를 유지하고 Windows Terminal Esc는 변환하지 않는다. SSH 원격 Vim Esc 문제는 열린 PR #12의 별도 조사이며 이 결정의 해결 근거가 아니다.

OS 기본 터미널 선택은 Windows 시스템 설정이며 settings.json의 속성이 아니다. 레지스트리·기본 앱을 자동 변경하지 않고 사용자 안내로 구분한다. macOS/WSL/Linux 설치와 기존 공통 Neovim·tmux 설정을 바꾸지 않는다. 깨끗한 새 장비 설치와 GUI/IME 실검증 전에는 재현성 완료로 표시하지 않는다.

근거: [설정 경로](https://learn.microsoft.com/en-us/windows/terminal/install), [fragment 제약](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions), [전역 단축키](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions), [OS 기본 터미널](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/startup).

## 계획 변경 근거

2026-10-07 KST: 파일 심볼릭 링크의 실제 생성이 Win32 1314로 거부되고 기존 설정이 보존된 것을 확인했다. 추가 권한을 요구하지 않고 source directory junction과 runtime Git 제외로 변경했다. 실제 임시 대상 검증은 작업 0006에 기록한다.
