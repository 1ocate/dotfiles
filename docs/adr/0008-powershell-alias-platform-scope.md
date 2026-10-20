# 0008: PowerShell 편집기 별칭을 플랫폼 기준으로 적용

- 상태: 채택
- 작성일: 2026-10-20
- 적용 범위: windows-powershell의 vi·vim 별칭
- 채택 근거: 사용자가 장비 이름을 저장·비교하지 않고 Windows PowerShell 환경이면 적용하도록 명시적으로 요청했다.
- 관련 작업: [작업 0009](../work/0009-powershell-neovim-aliases.md)
- 관련 PR: [PR #21](https://github.com/1ocate/dotfiles/pull/21)

## 문제와 대안

별칭 연결이 전체 설치 진행 기록의 호스트 이름을 검사하여 Windows PowerShell에서 실행해도 실패했다. 기존 승인·호스트 검사를 유지하면 단순 편집기 별칭이 특정 장비에 종속된다. 전체 환경 등록과 모든 설치기의 상태 형식을 변경하면 별칭 요청을 넘어 다른 기능의 승인·진행 기록까지 바뀐다.

## 결정과 영향

별칭은 Windows 네이티브 PowerShell에서 실행 가능한 `nvim`이 있으면 적용한다. 공통 환경 선택 파일·승인·장비 이름을 읽거나 요구하지 않는다. 비 Windows에서는 적용하지 않고 Neovim 누락이나 보호된 별칭은 기존 동작을 보존한다. Global 별칭 범위는 현재 PowerShell 세션이며, 관리자·모든 사용자 범위 설치를 뜻하지 않는다.

연결기는 현재 사용자의 PowerShell 5.1·7 프로필을 백업 후 저장소 원본을 읽도록 연결한다. 결과는 `.local/powershell-aliases.json`에 장비 이름 없이 저장한다. 전체 설치기의 `.local/setup-state.json`은 읽거나 변경하지 않으며 기존 다른 구성요소의 완료 상태를 승계하지 않는다. 전체 Windows 설치의 별도 승인 검사와 다른 기능의 호스트 정책은 이 결정의 범위 밖이다.

기존 [ADR 0002](0002-native-windows-adapters.md)의 원본·loader 방식은 유지하며, 별칭에 대해서만 환경 승인·호스트 검사 대신 플랫폼 검사를 사용한다. 다른 셸이나 시스템 전체 명령까지 동일 별칭을 제공할 필요가 생기면 별도 검토한다.
