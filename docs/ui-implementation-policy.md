# UI Implementation Policy

이 문서는 이 프로젝트(financeApp Frontend)에서 화면(UI/UX)을 구현할 때 지켜야 할 원칙을 정의한다.

적용 범위: Auth, Home, Calendar, Transaction, Report, Policy, My, Onboarding 및 향후 추가되는 모든 신규 화면.

이 문서는 `docs/development-work-policy.md`를 대체하지 않는다. `development-work-policy.md`는 Backend 연동 여부에 따른 기능 착수 기준(무엇을 언제 연결하는가)을 다루고, 이 문서는 화면의 geometry/layout이 무엇을 기준으로 얼마나 정확하게 구현되어야 하는가를 다룬다. 화면 작업을 시작하기 전에 두 문서를 함께 읽는다.

## 1. Source of Truth

Figma에 존재하는 화면은 해당 화면의 UI/UX structure에 대한 source of truth다.

구현자의 임의 판단으로 레이아웃을 재해석하거나 "더 나아 보이는" 대안 구조로 바꾸지 않는다. Figma와 다르게 구현해야 할 이유가 있다면(§7의 typo/의미 오류 수정 제외) 먼저 사용자에게 확인한다.

## 2. Figma 그대로 구현하는 범위

색상(color)과 page background를 제외한 아래 항목은 최대한 Figma 그대로 구현한다.

- 요소 위치
- 박스 위치와 크기
- padding / margin / gap
- alignment
- section/component 순서
- typography hierarchy
- input / button / chip / card 크기
- scroll 구조
- CTA 위치
- interaction / navigation flow

색상과 page background는 이 범위에서 제외되므로, 별도 지침(디자인 토큰, 다크모드 등)이 있는 경우 그 지침을 따른다. 그 외 항목은 임의로 압축하거나, 생략하거나, 다른 값으로 대체하지 않는다.

## 3. Figma에 없는 화면

Figma에 디자인이 없는 화면(신규 상태, 신규 플로우 등)은 자유 디자인하지 않는다.

대신 가장 유사한 기존 Figma 화면을 찾아 그 화면의 geometry, spacing, component, interaction pattern을 복제/조합/확장해서 구현한다.

- 어떤 화면을 참조 화면으로 삼았는지 판단이 애매하면 사용자에게 확인한다.
- 참조 화면이 여러 개로 조합되는 경우, 조합 기준(어느 화면에서 어느 부분을 가져왔는지)을 구현자가 인지하고 있어야 한다.

## 4. 결과물 기준

새로 만든 화면도 원래 같은 Figma 파일에 있었던 화면처럼 보여야 한다. 즉 완성된 화면만 보고 "이 화면은 Figma 시안이 없었다"는 것을 알아챌 수 없어야 한다.

## 5. 기존 로직 보존

Visual 구현 작업 중에는 기존 Provider / API / business logic / state / save logic을 명시적 요구 없이 변경하지 않는다.

레이아웃/스타일 변경과 로직 변경은 별개의 작업으로 취급한다. UI 구현 도중 로직 변경이 필요하다고 판단되면, 먼저 그 필요성을 사용자에게 설명하고 승인을 받은 뒤 진행한다.

## 6. Backend 미지원 UI

Figma에 UI가 있지만 Backend가 아직 지원하지 않으면 가짜 기능을 만들지 않는다.

이 항목은 `docs/development-work-policy.md`의 Feature Classification(§4) 및 Backend-Ready Frontend(§5) 기준을 그대로 따른다. 요약하면:

- UI 구조 자체는 Figma대로 구현한다.
- 값이 없으면 nullable/disabled/hidden으로 처리하고, production data를 조작해서 채우지 않는다.
- Backend가 나중에 값을 제공하면 UI 구조 변경 없이 바로 연결할 수 있는 상태를 유지한다.

## 7. Typo / 의미 오류 수정

Figma의 명백한 typo나 의미 오류(예: 맞춤법 오류, 논리적으로 모순된 문구, 값이 뒤바뀐 라벨)는 의미상 올바르게 수정한다.

수정한 경우 무엇을, 왜 수정했는지 기록한다(커밋 메시지 또는 작업 보고에 명시). 임의로 문구의 톤이나 의미 자체를 바꾸는 것은 이 항목에 해당하지 않으며, 그런 변경이 필요하면 사용자에게 먼저 확인한다.

## 8. Responsive 구현 방식

Responsive 구현은 Figma의 absolute coordinate(px 좌표)를 기기 크기별로 복사하는 방식으로 하지 않는다.

대신 Figma의 geometry(비율, 상대적 크기, 정렬 기준)와 hierarchy(어떤 요소가 어떤 요소를 기준으로 배치되는지)를 유지하는 방식으로 구현한다. Flutter 기준으로는 고정 px 절대 배치보다 Flex/Expanded, padding/gap 기반 레이아웃, 상대적 크기 계산을 우선한다.

## 9. 구현 후 QA

실제 구현 후에는 Android/Web에서 렌더링한 화면을 확인하고 다음을 QA한다.

- overflow
- bottom navigation과의 겹침(overlap)
- keyboard 노출 시 레이아웃
- loading / error / empty 상태

QA를 거치지 않은 상태에서 화면 구현을 완료로 보고하지 않는다.

## 10. 재설계 금지

이미 사용자와 최종 확정된 화면은 별도 요청 없이 다시 재설계하지 않는다.

리팩토링, 코드 정리, 다른 화면 작업 도중 발견한 개선 아이디어가 있어도 확정된 화면의 구조를 임의로 바꾸지 않는다. 개선이 필요하다고 판단되면 먼저 제안하고, 사용자의 명시적 승인 후에 진행한다.
