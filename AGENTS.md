# DungeonBreaker 작업 지침

## 프로젝트 개요

던전깨기(DungeonBreaker)는 Roblox Studio에서 개발하는 3인칭 로그라이크 액션 RPG다.

## 개발 환경

Luau를 사용하며 VS Code와 Roblox Studio는 Rojo로 동기화한다.

## 프로젝트 구조

- 작업 전에 `default.project.json`과 관련 소스 경로를 확인한다.
- 현재 `src/server`는 `ServerScriptService.Server`, `src/client`는 `StarterPlayer.StarterPlayerScripts.Client`, `src/shared`는 `ReplicatedStorage.Shared`에 연결된다.
- 기존 구조와 같은 역할의 코드를 활용하고, 작업과 무관한 파일은 수정하거나 삭제하지 않는다.

## 서버 처리

- 던전 생성과 입장·복귀 이동은 서버가 관리한다.
- 이동 전에는 서버에서 플레이어의 생존 여부, 상호작용 거리, 현재 구역을 검증한다.
- 이동 상태는 플레이어별로 관리하여 연속 입력으로 이동이 중복되지 않게 한다.

## 작업 결과 안내

- 생성하거나 수정한 파일의 경로와 역할을 안내한다.
- Roblox Studio에서 따라 할 수 있는 테스트 순서와 정상 결과를 알려 준다.
- 직접 확인한 결과와 추가 확인이 필요한 항목을 구분해서 안내한다.
