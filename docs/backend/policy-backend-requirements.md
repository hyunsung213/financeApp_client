# Policy 화면 Backend 요구사항

작성 배경: Policy/News 화면(Figma `FINAL_POLICY_SCREENS`, node 545:2995 - Main 238:4676, Detail 244:5144/246:5631, Calendar-add modal 248:6033)을 구현하면서 실제 backend 레포(`financeApp_backend`)의 `Policy`/`PolicyBookmark`/`PolicyCalendarEvent` 모델, `policyController.ts`, `policyService.ts`, `youthPolicyApiService.ts`를 직접 읽고 확인한 gap을 정리합니다. Frontend는 아래 모든 항목에 대해 값이 없을 때 UI가 깨지거나 화면이 사라지지 않도록 이미 nullable/fallback 처리를 해뒀습니다 - 이 문서는 backend가 각 필드를 실제로 채워주기 시작했을 때 바로 연결하기 위한 계약(contract) 정의입니다.

---

## 1. PolicyCalendarEvent CRUD (필수)

**현재 상태**: `PolicyCalendarEvent` 테이블/Sequelize 모델은 정의되어 있습니다 (`src/models/index.ts`: `id, userId, policyId, eventDate, note, createdAt`, `User`/`Policy`와의 association도 정의됨). 하지만 이를 다루는 Controller/Service/Route가 **전혀 없습니다** - `src/routes/policyRoutes.ts`, `src/controllers/policyController.ts`, `src/services/policyService.ts` 어디에도 참조가 없고, `src/seed.ts`에서 시드 정리 시 `destroy`만 호출합니다. 즉 이 테이블은 API로 생성/조회/삭제할 방법이 전혀 없는 죽은 테이블입니다.

**왜 필요한가**: Figma Detail 화면(248:6033)에 "내 캘린더에 추가하시겠습니까?" 확인 모달이 명시적으로 존재합니다. 사용자가 정책의 신청 기간을 자신의 Calendar에 추가하는 기능입니다.

**Frontend 연결 지점**: `lib/features/policy/widgets/policy_calendar_add_sheet.dart`의 `_confirm()` 메서드. 현재는 실제 저장 없이 "캘린더 추가 기능은 준비 중이에요." SnackBar만 표시합니다. API가 생기면 이 메서드 본문만 실제 API 호출로 교체하면 되고, 위젯/모달 구조는 다시 만들 필요가 없습니다.

**우선순위**: 필수 (이번 스코프에서 유일하게 "Figma에 명시된 기능인데 저장 자체가 불가능한" 항목)

**예상 API contract**:

```
POST /api/policies/:id/calendar-event
Body: { "eventDate": "2026-08-29" }   // 또는 시작/종료 둘 다 저장할지 결정 필요
Response: { "success": true, "data": { "id", "userId", "policyId", "eventDate", "note", "createdAt" } }

GET /api/policies/calendar-events
Response: { "success": true, "data": [ { ...PolicyCalendarEvent, "policy": {...} } ] }

DELETE /api/policies/:id/calendar-event
Response: { "success": true, "data": { "deleted": true } }
```

**Acceptance Criteria**:
- 정책 하나당 사용자가 중복 추가할 수 없거나(unique constraint), 중복 추가 시 명확한 응답을 준다.
- 생성된 이벤트가 Calendar 화면(`monthlyReportProvider`가 쓰는 `/api/reports/daily`와는 별개 데이터)에서 조회 가능한 형태로 반환된다.
- 삭제 후 재조회 시 목록에서 사라진다.

---

## 2. Policy 이미지/썸네일 필드 부재 (필수 논의, 구현은 선택)

**현재 상태**: `Policy` 모델(`src/models/index.ts`)에는 `id/title/provider/providerType/category/summary/description/ageMin/ageMax/region/applicationStartDate/applicationEndDate/applicationUrl/sourceUrl/dataCollectedAt`만 있고 이미지/썸네일 필드가 전혀 없습니다. **더 중요한 점**: 동기화 원본인 `youthPolicyApiService.ts`와 `policyService.ts`의 `mapPolicy()` 매핑 로직에도 이미지 관련 필드를 읽는 코드가 전혀 없습니다 - 즉 온통청년 Open API 응답 자체를 이 프로젝트가 이미지 필드로 매핑하고 있지 않다는 뜻입니다 (외부 API가 실제로 이미지 필드를 제공하는지 여부는 별도 확인이 필요합니다만, 현재 이 프로젝트의 동기화 코드는 그걸 시도조차 하지 않습니다).

**왜 필요한가**: Figma Featured Card(238:4984)와 List 카드(244:5045~)에 큰 사진 영역이 있습니다.

**Frontend 연결 지점**: `lib/features/policy/utils/policy_category_visual.dart` - 카테고리 기반 gradient + Material 아이콘으로 대체 구현했습니다. `imageUrl` 필드가 추가되면 `PolicyFeaturedCard`/`PolicyListCard`에서 이 유틸리티 대신 실제 이미지를 그리도록 교체하면 되고, 카드 레이아웃/비율은 그대로 유지됩니다.

**우선순위**: 논의 필요 - 외부 원본에 이미지 데이터가 없다면 backend가 단순 passthrough로 해결할 수 있는 문제가 아니라, 별도 이미지 소스(자체 카테고리 대표 이미지 라이브러리 등)를 구축해야 하는 별개 프로젝트가 됩니다.

**예상 API contract**: `Policy` 응답에 `imageUrl?: string | null` 추가.

**Acceptance Criteria**: `imageUrl`이 없는 기존 정책은 계속 `null`을 반환해 기존 UI(카테고리 비주얼 fallback)가 그대로 동작한다.

---

## 3. 지원 대상(eligibility) 구조화 필드 (선택)

**현재 상태**: `eligibility`라는 필드는 없습니다. 대신 `ageMin`, `ageMax`, `region`이 있습니다.

**왜 필요한가**: Figma Detail 화면(244:5301)의 "지원 대상" 섹션은 자유 서술형 텍스트("내년부터 청년이라면...")로 되어 있어, 나이/지역 조건만으로는 표현 못 하는 조건(소득 기준, 재직 여부 등)이 있을 수 있습니다.

**Frontend 연결 지점**: `lib/features/policy/screens/policy_detail_screen.dart`의 `_eligibilityText()` - 현재 `ageMin`/`ageMax`/`region`을 조합해 "만 19~34세 · 전국" 형태로 합성합니다. 값이 하나도 없으면 "-"를 표시하고, 임의의 문구를 만들지 않습니다.

**우선순위**: 선택 - 나이/지역 조합으로 상당 부분 커버되므로 필수는 아니지만, 원본 API에 서술형 자격 요건 필드가 있다면 매핑을 추가하는 것을 권장합니다.

**예상 API contract**: `Policy.eligibility?: string | null` (자유 서술형).

**Acceptance Criteria**: 필드가 채워지면 Detail 화면이 나이/지역 합성 텍스트 대신 이 필드를 그대로 표시한다 (우선순위: `eligibility` > 나이/지역 합성 > `-`).

---

## 4. 신청 방법(applicationMethod) 구조화 필드 (선택)

**현재 상태**: 대응하는 필드가 전혀 없습니다. `description`만 있습니다.

**왜 필요한가**: Figma Detail 화면(244:5311)의 "신청 방법" 섹션.

**Frontend 연결 지점**: `policy_detail_screen.dart`에서 현재 고정 안내 문구("자세한 신청 방법은 공식 홈페이지에서 확인할 수 있어요.")로 대체했습니다. 이는 데이터 조작이 아니라 missing-data 안내이며, 실제 신청 방법을 지어내지 않습니다.

**우선순위**: 선택 - 원본 API(온통청년)가 신청 방법 관련 필드(`plcyAplyMthdCn` 등 유사 필드)를 제공한다면 매핑 추가를 권장합니다.

**예상 API contract**: `Policy.applicationMethod?: string | null`.

**Acceptance Criteria**: 필드가 채워지면 고정 안내 문구 대신 실제 값을 표시한다.

---

## 5. Bookmark 상태 응답 개선 (선택 - Frontend에서 이미 우회함)

**현재 상태**: `GET /api/policies`, `GET /api/policies/recommended`, `GET /api/policies/:id` 어디도 로그인한 사용자 기준 `isBookmarked` 플래그를 내려주지 않습니다. `POST/DELETE /api/policies/:id/bookmark`, `GET /api/policies/bookmarks`는 정상 동작합니다.

**Frontend 연결 지점**: `lib/features/policy/providers/policy_provider.dart`의 `bookmarkedPolicyIdsProvider`가 `GET /api/policies/bookmarks` 결과에서 `policyId` Set을 만들어 List/Detail 어디서든 동일하게 bookmark 상태를 계산합니다. **현재 이 방식으로 정상 동작하므로 이 항목은 필수가 아닙니다.**

**왜 개선이 유용한가**: 정책 개수가 많아지면 매번 전체 북마크 목록을 따로 불러와 대조하는 대신, 리스트 응답 자체에 `isBookmarked`가 있으면 더 효율적입니다.

**우선순위**: 선택 (성능 최적화 목적)

**예상 API contract**: `GET /api/policies`, `/recommended`, `/:id` 각 policy 객체에 `isBookmarked: boolean` 추가 (인증된 사용자 기준).

**Acceptance Criteria**: 필드가 추가되면 프론트가 `bookmarkedPolicyIdsProvider` 대신 이 필드를 우선 사용하도록 최소 변경으로 전환 가능해야 한다 (현재 구조를 유지한 채 데이터 소스만 교체).

---

## 6. Category 메타데이터 endpoint (선택 - Frontend에서 이미 우회함)

**현재 상태**: `/api/policies?category=`로 필터링은 가능하지만, "현재 존재하는 category 고유값 목록"을 내려주는 endpoint는 없습니다.

**Frontend 연결 지점**: `lib/features/policy/widgets/policy_filter_chips.dart` - 현재 로드된 정책 리스트에서 `category` 고유값을 추출해 칩을 구성합니다 (`policy_screen.dart`의 `_PolicyList`). **정상 동작하므로 필수 아님.**

**우선순위**: 선택 - 정책 개수가 많아져 한 번에 전체를 불러오는 비용이 커지면, `GET /api/policies/categories` 같은 경량 endpoint가 유용해질 수 있습니다.

**예상 API contract**: `GET /api/policies/categories` → `{ "success": true, "data": ["주거", "일자리", "금융", ...] }`

**Acceptance Criteria**: 있으면 프론트가 전체 정책을 미리 불러오지 않고도 칩 목록을 구성할 수 있다.

---

## 추가로 확인한 기존 버그 (이번 요구사항과 별개, Frontend에서 이미 수정함)

작업 중 발견해서 frontend에서 바로 고친 버그입니다. Backend 변경은 필요 없지만, 백엔드 응답 계약을 다시 문서화할 때 참고하시라고 기록합니다.

- `GET /api/policies`는 `data`를 **배열**로 반환합니다 (`policyService.list()` → `Policy.findAll(...)`을 그대로 반환, `{items: [...]}` 래핑 없음). 기존 프론트 `PolicyApi.getPolicies()`는 `Future<Map<String, dynamic>>`으로 선언하고 `data['items']`를 읽고 있었는데, 실제로는 배열이라 실제 백엔드에 붙는 순간 타입 캐스팅 에러가 났을 것입니다. `Future<List<dynamic>>`로 수정했습니다.
- `GET /api/policies/bookmarks`는 `PolicyBookmark` row 배열을 반환합니다 (`id/userId/policyId/createdAt/policy`) - `Policy` 객체 배열이 아닙니다. 실제 정책 필드(`title`, `category` 등)는 각 row의 `policy` 하위에 있습니다. 기존 "관심 정책" 탭 코드는 이를 평평한 Policy 객체처럼 다뤄서 제목이 항상 "제목 없음"으로 보였을 것입니다. `PolicyBookmarksScreen`/`bookmarkedPolicyIdsProvider`에서 이 구조를 반영해 수정했습니다.

---

## 담당자 전달용 요약

**[요청 목적]** Policy/News 화면(Figma FINAL_POLICY_SCREENS) 완성을 위한 backend gap 정리

**[필수]**
- PolicyCalendarEvent CRUD API (모델은 이미 있음, Controller/Service/Route만 없음)

**[논의 필요]**
- Policy 이미지/썸네일 필드 - 원본 온통청년 API 매핑 코드에도 이미지 필드가 없어 단순 backend 작업으로 해결되지 않을 수 있음

**[선택 - 있으면 좋음, 없어도 현재 정상 동작]**
- eligibility 구조화 필드
- applicationMethod 구조화 필드
- policy 응답에 isBookmarked 포함 (프론트가 이미 `/bookmarks` 대조로 우회 중)
- category 목록 endpoint (프론트가 이미 클라이언트 추출로 우회 중)

**[참고 - 이미 frontend에서 수정한 기존 버그]**
- `GET /api/policies` 배열 응답을 Map으로 잘못 파싱하던 프론트 버그
- `/api/policies/bookmarks`의 `policy` 중첩 구조를 평평하게 다루던 프론트 버그

**[Frontend 연결 지점]** 위 각 항목의 "Frontend 연결 지점" 참고 - 전부 nullable/fallback으로 준비되어 있어 필드가 추가되는 즉시 UI 재작업 없이 연결됩니다.
