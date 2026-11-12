---
title: widget-studio
created: 2026-11-12
updated: 2026-11-12
tags: [type/설계, agent/claude-b93be0c6-4094-4ff5-bba4-98c3ab3e7f1f]
source: ai
status: active
---

> 아이폰 홈 화면 위젯을 직접 디자인하는 iOS 앱이다. 앱에서 문구·시계·D-day·사진·GIF 템플릿으로 디자인을 만들고, 홈 화면의 「위젯 스튜디오」 위젯에서 보여 줄 디자인을 고른다.

## 기능

- 템플릿 — 문구(제목·보조 문구), 시계(요일·날짜·시각, 분마다 갱신), D-day(목표일까지 `D-n`·`D-DAY`·`D+n`, 자정마다 갱신), 사진(배경 사진 + 어둡게 정도 + 캡션).
- GIF — 내장 프리셋 8종에서 고르거나 사진 보관함·파일에서 가져온다(12MB·300프레임 이하). 앱을 열지 않아도 홈 화면에서 반복 재생한다. 위젯에는 원본 전체에서 뽑은 16장면을 2초 루프로 표시하며, 위젯을 누르면 원본을 앱에서 재생한다. 앱에서 일시 정지·재생할 수 있고, 디자인을 길게 눌러 재생·복제·삭제할 수 있다. 가져온 GIF는 저장을 눌렀을 때 보관한다.
- GIF 찾기 — 편집기의 「GIF 검색·다운로드」에서 검색어를 넣어 Pixabay·GIPHY·Tenor 검색 페이지를 연다. 사이트에서 파일을 저장한 뒤 「다운로드한 GIF 불러오기」로 가져온다. 사진 보관함에 저장한 파일은 사진 보관함 버튼으로 선택한다.
- 꾸미기 — 배경 단색·그라데이션(팔레트 + 색 고르기), 글자 색, 글꼴(기본·둥근·명조·고정폭), 정렬(왼쪽·가운데).
- 크기별 화면 — 사진·GIF 편집기에서 작게·중간·크게마다 채우기/전체 보기, 확대(100~300%), 가로·세로 위치를 따로 저장한다. 해당 크기의 미리보기에서 표시 범위를 확인하고 초기화할 수 있다.
- 앱 아이콘 — 유리 위젯 타일을 조합한 Liquid Glass 테마 아이콘을 쓴다.
- 미리보기 — 편집기에서 작게·중간·크게 크기로 실제 위젯과 같은 뷰를 그린다.
- 위젯 — 작게·중간·크게. 길게 눌러 「위젯 편집」→「디자인」에서 앱의 디자인을 고른다(App Intent 구성). 고르지 않으면 첫 디자인을 보여 준다. 위젯을 누르면 GIF는 재생 화면을, 나머지는 디자인 편집기를 연다.
- 목록 — 길게 눌러 복제·삭제. 첫 실행 때 예시 디자인 3개를 넣는다.
- Liquid Glass — 앱은 배경화면(노을·바다·꽃) 위에 유리 층을 쌓는다. 하단 + 유리 방울이 템플릿 방울로 녹아 펼쳐지고, 크기 선택기는 선택 표시가 유리로 옮겨 다니며, 색 견본은 색을 입힌 유리 방울이다.
- 투명(유리) 위젯 — 위젯의 모습은 iOS 홈 화면 설정만 따른다. 홈 화면 「편집 > 사용자화」에서 클리어·틴트를 고르면 시스템이 위젯 배경을 Liquid Glass 로 바꾸고, 위젯은 시각·D-day 숫자·제목을 강조 그룹(`widgetAccentable`)으로, 나머지를 흐린 글자로 그리며, 사진은 채도를 뺀 강조색 층으로 남긴다. iOS 에는 위젯 하나만 투명하게 하는 API 가 없다(폴더·아이콘은 홈 화면이 직접 그려서 유리가 되지만, 위젯은 확장이 그린 결과를 받아 붙이며 배경화면을 볼 수 없다).

## 구성

- `src/Shared/` — 디자인 모델(`WidgetDesign`), 공유 저장소(`DesignStore`), GIF 검증·프레임 추출(`GIFAsset`·`GIFWidgetFrames`), 크기별 이미지 배치(`WidgetImageLayout`), 앱과 위젯이 함께 쓰는 렌더링 뷰.
- `src/App/` — SwiftUI 앱(목록·편집기·사용법).
- `src/Widget/` — WidgetKit 확장(디자인 선택 인텐트, 타임라인).
- `project.yml` — xcodegen 명세. `WidgetStudio.xcodeproj` 는 생성물이라 저장소에 넣지 않는다.
- 상세: [[docs/기능 명세|기능 명세]]

## 설치·기동

- 요구 사항 — Xcode 26 이상(iOS 26 SDK, Liquid Glass), 기기 iOS 26 이상, `xcodegen`(`brew install xcodegen`).
- `bin/widget-studio gen` — 작은 타이머 마스크 글꼴을 로컬 Swift 도구로 생성한 뒤 Xcode 프로젝트를 만든다. 글꼴과 프로젝트는 `.build/`·생성물에만 둔다.
- `bin/widget-studio build` — 시뮬레이터용 빌드(`.build/`).
- `bin/widget-studio run [기기 이름]` — 빌드 → 시뮬레이터 부팅·설치·실행(기본 `iPhone 17`).
- `TEAM=<팀 ID> bin/widget-studio device [UDID]` — 케이블·Wi-Fi 로 페어링된 아이폰에 서명·설치·실행. 팀 ID 는 Xcode 설정 > Accounts 에서 보며 저장소에 넣지 않는다. 무료 Apple ID 의 Personal Team 으로 충분하고, 설치는 7일 동안 유효해서 그 뒤에는 다시 돌린다. 처음 설치한 기기에서 실행이 막히면 설정 > 일반 > VPN 및 기기 관리에서 개발자를 신뢰한다.
- 저장소 공유 — 실기기는 키체인 공유 그룹(`<팀 접두어>io.github.s12171934.widgetstudio.shared`)을, 시뮬레이터는 App Group 을 쓴다. 무료 팀은 App Group 을 쓸 수 없어서다.
- GIF 원본 — 앱의 Application Support에 저장한다. 위젯에는 대표 PNG와 긴 변 220px 이하의 PNG 16장만 공유하고 원본 GIF를 디코딩하지 않는다. 이전 버전의 GIF도 앱을 열면 원본을 보존한 채 위젯 장면을 자동으로 준비한다.

## GIF 표시 범위

- 프리셋 — 「프리셋에서 고르기」에서 미리 보고 선택한다. 앱이 직접 그리는 8가지 장면을 네트워크 없이 GIF로 생성하며, 처음 만드는 디자인의 이름도 선택한 프리셋 이름으로 채운다.
- 검색 링크 — [Pixabay GIF](https://pixabay.com/gifs/), [GIPHY](https://giphy.com/), [Tenor](https://tenor.com/)를 브라우저로 연다. 검색어를 URL에 반영하며 외부 GIF를 앱에 내장하거나 검색 API·계정 키를 사용하지 않는다.
- 홈 화면 — 프리셋·가져온 GIF 모두 앱을 열지 않고 반복 재생한다. 원본의 시간 간격을 반영해 전체에서 16장면을 추출하고 2초마다 반복하므로, 원본 길이에 따라 속도가 달라지고 미세한 동작은 생략될 수 있다. 실제 갱신 주기는 iOS가 결정한다.
- 구현 — GIF 파일 자체를 재생하는 대신 보통 `Image` 16장에 시스템 `Text(..., style: .timer)` 마스크를 적용한다. 마스크 글꼴 하나만 확장 번들에 포함한다. 앱 타이머·잦은 타임라인 갱신·비공개 API를 쓰지 않는다. [타이머·글꼴 기법 원본](https://github.com/NAOYA-MAEDA-DEV/WidgetKitAnimation)을 참고했으며 해당 코드의 MIT 고지는 소스에 보존한다.
- 앱 — 원래 프레임 간격으로 반복 재생한다. 화면을 닫거나 앱이 비활성 상태가 되면 재생을 멈춘다. 재생 프레임은 긴 변 600px 이하로 추출하고 캐시 한도를 24MiB로 둔다.
- 홈 화면 모드 — GIF의 각 장면도 사진과 같이 iOS 모드를 따른다. 클리어·틴트에서는 시스템 유리 위에 채도를 뺀 강조색 이미지로 표시한다.

## 검증

- 프로젝트 생성 — `bin/widget-studio gen`.
- 단위 테스트 — `xcodebuild test -project WidgetStudio.xcodeproj -scheme WidgetStudio -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:WidgetStudioTests`.
- 화면 테스트 — iPhone 17 시뮬레이터 사진 보관함에 GIF를 최신 항목으로 넣은 뒤 `-only-testing:WidgetStudioUITests -parallel-testing-enabled NO`로 실행한다. 사진 가져오기·장면 변화·일시 정지·저장·홈 화면 위젯 디자인 선택·탭 후 원본 재생과 프리셋 선택·검색 화면·다운로드 파일 선택기 연결을 확인한다.

- 실기기 홈 재생 — 기존 GIF와 홈 위젯이 있는 기기에서 `-only-testing:WidgetStudioUITests/GIFHomeDeviceTests`로 앱이 전면에 없는 상태의 장면 변화를 확인한다.

## 공개 면

- `bin/widget-studio` — 프로젝트 생성·빌드·시뮬레이터 실행·실기기 설치 진입점이다. `exports/` 는 없다.
