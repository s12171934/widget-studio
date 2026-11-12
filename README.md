---
title: widget-studio
created: 2026-11-12
updated: 2026-11-12
tags: [type/설계, agent/claude-b93be0c6-4094-4ff5-bba4-98c3ab3e7f1f]
source: ai
status: active
---

> 아이폰 홈 화면 위젯을 직접 디자인하는 iOS 앱이다. 앱에서 문구·시계·D-day·사진 템플릿으로 디자인을 만들고, 홈 화면의 「위젯 스튜디오」 위젯에서 보여 줄 디자인을 고른다.

## 기능

- 템플릿 — 문구(제목·보조 문구), 시계(요일·날짜·시각, 분마다 갱신), D-day(목표일까지 `D-n`·`D-DAY`·`D+n`, 자정마다 갱신), 사진(배경 사진 + 어둡게 정도 + 캡션).
- 꾸미기 — 배경 단색·그라데이션(팔레트 + 색 고르기), 글자 색, 글꼴(기본·둥근·명조·고정폭), 정렬(왼쪽·가운데).
- 미리보기 — 편집기에서 작게·중간·크게 크기로 실제 위젯과 같은 뷰를 그린다.
- 위젯 — 작게·중간·크게. 길게 눌러 「위젯 편집」→「디자인」에서 앱의 디자인을 고른다(App Intent 구성). 고르지 않으면 첫 디자인을 보여 준다. 위젯을 누르면 그 디자인 편집기가 열린다.
- 목록 — 길게 눌러 복제·삭제. 첫 실행 때 예시 디자인 3개를 넣는다.

## 구성

- `src/Shared/` — 디자인 모델(`WidgetDesign`), App Group 저장소(`DesignStore`), 앱과 위젯이 함께 쓰는 렌더링 뷰.
- `src/App/` — SwiftUI 앱(목록·편집기·사용법).
- `src/Widget/` — WidgetKit 확장(디자인 선택 인텐트, 타임라인).
- `project.yml` — xcodegen 명세. `WidgetStudio.xcodeproj` 는 생성물이라 저장소에 넣지 않는다.
- 상세: [[docs/기능 명세|기능 명세]]

## 설치·기동

- 요구 사항 — Xcode(iOS 17 이상 SDK), `xcodegen`(`brew install xcodegen`).
- `bin/widget-studio gen` — Xcode 프로젝트 생성. 실기기 설치는 이 프로젝트를 Xcode 로 열어 서명 팀을 고르고 실행한다(앱과 확장 모두 App Group `group.io.github.s12171934.widgetstudio` 사용 — 팀에 맞게 번들 ID·그룹을 바꿀 수 있다).
- `bin/widget-studio build` — 시뮬레이터용 빌드(`.build/`).
- `bin/widget-studio run [기기 이름]` — 빌드 → 시뮬레이터 부팅·설치·실행(기본 `iPhone 17`).

## 공개 면

- `bin/widget-studio` — 위 세 명령이 전부다. `exports/` 는 없다.
