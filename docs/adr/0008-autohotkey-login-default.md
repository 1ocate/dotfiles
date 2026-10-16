# ADR 0008: Windows AutoHotkey 로그인 등록 기본값

- 상태: 채택 (사용자의 이번 요청으로 선택, 코드 병합과 별개)
- 범위: windows-powershell
- 관련 작업: [작업 0008](../work/0008-autohotkey-login-default.md)

## 배경과 결정

사용자가 현재 PC의 로그인 등록과 다음 PC의 즉시 적용을 요청했다. 승인된 Windows 설치에서 AutoHotkey 로그인 바로가기를 기본 등록한다. 질문·명시 등록만 허용하던 [ADR 0002](0002-native-windows-adapters.md)의 로그인 등록 조항을 이 결정으로 대체한다. 나머지 원본 연결·환경 격리 결정은 유지한다.

별도 질문을 유지하면 새 PC에서 다시 누락될 수 있어 기본 등록을 선택했다. `-SkipAutoHotkeyStartup`으로 등록만 생략하고 `-SkipAutoHotkey`로 현재 실행과 기본 등록을 생략할 수 있다. 명시 `-RegisterAutoHotkeyStartup`은 현재 실행 생략과 조합할 수 있다. 생략 옵션은 기존 등록을 제거하지 않는다.

## 영향과 한계

최초 환경 승인은 계속 필요하다. Plan/Check는 변경하지 않으며 macOS·WSL·Linux는 대상이 아니다. 바로가기는 해당 호스트 체크아웃을 참조하고 기존 다른 바로가기는 백업한다. 저장소 이동 시 재연결해야 한다. 로그인 실기능은 다음 로그인 후 확인하며 신규 PC 전체 설치 검증과 구분한다.
