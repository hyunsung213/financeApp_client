# AI 작업 기록

이 파일은 AI와 함께 진행하는 모든 작업의 "할 일(To Do)"과 "한 일(Done)"을 실시간으로 기록하고 관리한다.
새로운 작업 요청이 들어오면 우선 이 파일을 확인한 후, 작업을 진행하며 To Do와 Done을 갱신한다.

---

## To Do

### 1. 워크플로우 규칙
- [x] **작업 완료 후 앱 자동 반영 방식 확정**: `flutter run` 터미널에 Shift+R(hot restart) 키 입력을 자동으로 보내는 방법을 시도했으나, 이 환경(Windows + git-bash)에서는 FIFO를 통한 stdin 흉내가 네이티브 `flutter.bat`/`dart.exe` 프로세스까지 전달되지 않아 동작하지 않음을 확인함. 대안으로 **작업이 끝날 때마다 `flutter run` 프로세스를 종료 후 재실행**하는 방식으로 최신 코드를 자동 반영하기로 함 (hot restart 대비 다소 느리지만 확실하게 동작).

### 2. 금융 알림 수집 및 파싱 고도화
- [ ] 백엔드 파싱 연동 및 자동 거래(Transaction) 생성 흐름 테스트
- [ ] 금융앱 추가 시 Allowlist 확장 및 패턴 검증

### 3. 캘린더 페이지 & 거래 입력 흐름 — 디자인 시안 대비 수정사항
디자인 시안: 캘린더 메인 / 거래 내역 팝업 / 관심 정책 팝업 / 수기 거래 입력 / 카테고리 선택 (5개 화면)

**A. 캘린더 메인 (`lib/features/calendar/screens/calendar_screen.dart`)**
- [x] 날짜 셀에 정책 마감 임박 배지 표시 (예: "정책 D-5", "정책 D-Day") — 관심(북마크) 정책의 `applicationEndDate`가 그 날짜와 일치하면 배지 렌더링. `daysLeft`는 "오늘" 기준 계산
- [x] 소비 사용률 게이지 링을 단색에서 그라데이션(연한 초록→`AppColors.primary`, 초과 시 연한 주황→빨강)으로 변경 — `_GradientRingPainter` 커스텀 페인터 추가
- [x] 지출이 0원인 날은 회색 게이지 링 자체를 그리지 않도록 변경 (`hasSpending` 가드 추가, 기존엔 지출 0이어도 항상 회색 원이 그려졌음)
- [ ] 헤더 아래 카테고리 아이콘 행 추가 여부 확인 (목업엔 있으나 필터인지 범례인지 불명확)
- [ ] 월간 요약 카드(무지출 일수/수입/지출)가 실제 데이터 아닌 하드코딩된 고정값 — `calendar_screen.dart:164-183`을 실제 월간 리포트 데이터와 연동 필요
- [ ] FAB 아이콘을 `+`에서 연필(수기입력) 아이콘으로 변경할지 확인

**B. 거래 내역 팝업 (`lib/features/calendar/widgets/day_detail_sheet.dart`)**
- [ ] 거래 항목 아이콘이 전부 동일(영수증) → 홈 화면처럼 `categoryIconFor`로 카테고리별 아이콘 적용
- [ ] 목업은 요약 없이 리스트+확인 버튼 1개, 현재는 요약 섹션+버튼 2개(거래추가/전체보기) — 디자인 단순화 여부 확인 필요

**C. 관심 정책 팝업**
- [x] "관심 정책" 섹션이 실제로는 추천 정책(`recommendedPoliciesProvider`)을 보여주고 있던 버그 수정 — 실제 북마크한 정책(`bookmarkedPoliciesProvider`)을 보여주도록 교체하고, 1건만이 아니라 북마크한 정책 전체를 리스트로 표시
- [x] **후속 수정**: "정책" 목업(Frame 116/119/129/131)에서 북마크(관심)와 "캘린더에 추가"가 서로 다른 명확한 기능임이 드러남 → 캘린더 배지/"관심 정책" 섹션의 데이터 소스를 `bookmarkedPoliciesProvider`에서 신규 `policyCalendarEventsProvider`(실제 "캘린더에 추가" API)로 교체. 또한 `PolicyApi.getBookmarks()`가 `{bookmarkId, bookmarkedAt, policy:{...}}` 형태로 정책을 중첩 반환하는데 기존 코드는 이를 평평한 정책 객체로 잘못 가정하고 있던 버그도 함께 발견·수정 (id/title 등이 항상 null이었을 것)
- [ ] 목업은 탭 시 지원대상/지원내용/신청기간/신청방법/문의처가 담긴 별도 상세 팝업이 뜨는데, 현재는 바로 `/policy/:id` 상세 페이지로 이동 — 2단계 팝업 흐름 추가 여부 확인 (→ 이번 정책 화면 재구현으로 상세 페이지 자체가 이 내용을 다 보여주도록 구현되어 실질적으로 해결됨)

**D. 수기 거래 입력 (`lib/features/transaction/screens/add_transaction_screen.dart`)**
- [ ] 목업은 풀스크린 페이지(뒤로가기+타이틀+알림), 현재는 바텀시트 모달 — 화면 전환 방식 변경 여부 확인
- [ ] 거래유형 탭: 목업 3개(저축/지출/수입) vs 현재 4개(지출/저축/투자/수입) — "투자" 탭 유지 여부 확인
- [ ] 소비평가: 목업 3개(아쉬운/평범한/만족한) vs 현재 4개(좋음/보통/아쉬움/나쁨) — 라벨/개수 통일 필요
- [ ] 날짜에 시간 선택 추가 (목업: "2026년 8월 17일 17:00", 현재는 날짜만 선택 가능)
- [ ] 금액 입력 필드가 목업 캡처에 안 보임 — 실제로 제거된 건지 스크롤 밖이라 안 보이는 건지 확인 필요

**E. 카테고리 선택 화면 (`lib/features/transaction/widgets/category_picker_screen.dart`)**
- [ ] 목업은 항목 선택(하이라이트) 후 "다음"/"저장" 버튼으로 확정하는 2단계 확인 방식, 현재는 탭 즉시 다음 단계로 이동 — 인터랙션 모델 변경 여부 확인

### 4. 리포트 페이지 — 디자인 시안 대비 수정사항
디자인 시안: 월 선택 팝업 / 리포트 메인 / 카테고리별 지출 상세 / 소비 흐름 비교 / 주별 총 지출 비교 / 월별 총 지출 비교 / 최근 거래내역·거래상세 (7개 화면)

**A. 리포트 메인 화면 (`lib/features/report/screens/report_screen.dart`)**
- [x] 요약 카드 "지난달보다 8% 적게"가 목업 문자열이던 것을 실제 `getSummary()`(이번 달)+`getMonthly()`(지난달) 비교로 계산하도록 수정. 지난달 데이터가 없으면 "비교할 수 없어요"로 표시(가짜 % 노출 안 함)
- [x] `_buildAreaChart`의 지난달 라인이 하드코딩 배열이던 것을 실제 지난달 `getDaily()` 결과로 교체, x축 라벨/오늘 표시도 보고 있는 달 기준으로 동적 계산 (기존엔 8월 17일 기준으로 하드코딩돼 있었음)
- [x] `_buildCategoryLegend`의 "외 6건"을 실제 `categories.length - 4`로 계산, 카테고리 없을 때는 목업 도넛 대신 "지출 내역이 없어요" 표시
- [x] "이번 달 리포트 요약" 인사이트 카드 3개 추가: 전월 대비 %, 최다지출 카테고리, 최다지출 요일 — 전부 실제 `getSummary`/`getMonthly`/`getCategories`/`getDaily` 데이터로 계산 (백엔드에 별도 인사이트 API 없음, 프론트에서 원시 데이터로 직접 계산)
- [x] 소비 흐름/카테고리별 지출 카드의 "더보기"에 탭 핸들러 연결 (아래 신규 화면으로 이동)
- [x] 월 선택 바텀시트 추가 (1~12월 그리드, 목업과 동일)
- [x] **실제 발견한 버그 수정**: `summary['totalSpent']`를 읽고 있었는데 백엔드 응답 필드는 `expense`였음 (필드명 불일치로 항상 0원 표시됐을 것) → `expense`로 수정
- [x] **실제 발견한 버그 수정**: 카테고리 응답 필드가 `name`이 아니라 `category`였음 (필드명 불일치로 항상 목업 이름("식비/교통비/카페/카드")이 표시되고 있었을 것) → `category`로 수정
- [x] **실제 발견한 중대 버그 수정**: `ReportApi.getDaily()`가 `Future<List<dynamic>>`로 선언돼 있었는데 백엔드는 `{period, summary, daily}` 형태의 객체를 반환함 → 호출 시마다 타입 캐스팅 런타임 에러가 발생해 캘린더/리포트의 일별 데이터가 항상 조용히 실패하고 있었을 것. `Future<Map<String, dynamic>>`로 수정하고 호출부(리포트/캘린더) 전부 갱신

**B. 카테고리 별 지출 상세 화면 (`category_report_detail_screen.dart`, 신규 구현 완료)**
- [x] 카테고리별 전체 목록 + 전체 대비 비중 막대바 + 거래 건수 화면 구현
- [x] **budget-vs-actual(예산 대비 사용액) 막대바는 구현하지 않음** — 백엔드 스키마 확인 결과 카테고리별 예산 데이터 자체가 존재하지 않음(`BudgetCycleAllocation`은 카테고리가 아닌 spendability(LOCKED/RESERVED/FLEXIBLE) 단위로만 예산을 가짐). 가짜 예산 숫자를 만들지 않기 위해 "전체 지출 대비 비중"(실제 `percentage` 필드)으로 대체함. 카테고리별 예산 기능을 원하면 백엔드에 카테고리-예산 매핑 데이터 모델 추가가 먼저 필요함 (아래 API 요구사항 참고)

**C+D. 소비 흐름 비교 / 주별·월별 총 지출 비교 (`monthly_comparison_screen.dart`, 신규 구현 완료)**
- [x] 화면 하나로 통합 구현(목업은 별도 화면들이지만 진입 동선이 불명확해서 "더보기" 하나로 묶음): 이번달 vs 지난달 총지출 막대그래프+통계(차이/변화율), 주차별(1~5주) 막대그래프+표, "N주차 지출이 가장 많았어요" 인사이트 — 전부 실제 `getMonthly()`/`getDaily()` 데이터로 계산
- [x] `getPace()`는 이 용도가 아님을 확인 — 백엔드 코드 확인 결과 `pace()`는 현재 예산 주기의 잔여 한도 계산용이고 `previous` 필드는 항상 `null`(미구현)이라 월별 비교에 쓸 수 없음. 대신 `getMonthly()`(전체 월별 합계 배열)로 대체 구현함

**E. 최근 거래내역 전체 / 거래 상세**
- 캘린더 리뷰 때 다룬 화면과 동일 패턴, 리포트 페이지 고유 이슈 아님 (참고용, 미착수)

**남은 것**
- [ ] 카테고리별 예산 설정 기능 자체가 없음 (마이페이지의 예산 배분은 spendability 단위) — 필요하면 백엔드 스키마 변경부터 논의 필요
- [ ] 시뮬레이터에서 실기기 확인 완료(에뮬레이터), 다양한 달(지난달 데이터 없는 경우 등) 엣지케이스는 육안 확인 못 함

### 5. 정책(청년정책) 페이지 — 디자인 시안 구현 + 하단 네비 "뉴스" → "정책"
디자인 시안: 정책 목록(Frame 116) / 정책 상세(Frame 119, 129) / 캘린더 추가 확인 팝업(Frame 131)

**완료**
- [x] 하단 네비게이션 4번째 탭을 "뉴스"(placeholder, 삭제함)에서 "정책"으로 교체 — `lib/core/router.dart`, 아이콘은 방패(`Icons.shield_outlined`)
- [x] 정책 목록 화면 전면 재구현(`lib/features/policy/screens/policy_screen.dart`) — 기존 3탭(추천/전체검색/관심정책) 구조를 목업처럼 카테고리 필터 칩 + 첫 항목 히어로 카드 + 나머지 리스트 카드로 통합. 카테고리 칩은 실제 정책 목록에서 뽑아낸 고유 카테고리 값 사용(하드코딩 아님)
- [x] 정책 상세 화면 전면 재구현(`lib/features/policy/screens/policy_detail_screen.dart`) — 히어로 영역(뒤로가기/카테고리뱃지/D-day뱃지/캘린더추가·북마크 아이콘) + 지원대상·주요내용·신청방법 카드 + "공식 홈페이지 보러가기" CTA(`url_launcher`로 실제 URL 오픈)
- [x] "내 캘린더에 추가하시겠습니까?" 확인 바텀시트 구현(Frame 131) — 추가 시 실제 백엔드에 저장, 캘린더 페이지에 "정책 D-N" 배지로 반영됨을 에뮬레이터에서 실제 확인함
- [x] **백엔드에 없던 기능을 새로 구현함**: `PolicyCalendarEvent` 테이블/모델은 이미 존재했지만(`seed.ts`에서만 참조) 이를 사용하는 API 자체가 없었음 → `financeBackend`에 `POST/DELETE /api/policies/:id/calendar`, `GET /api/policies/calendar` 엔드포인트를 기존 북마크 패턴과 동일하게 신규 추가 (`policyService.ts`, `policyController.ts`, `policyRoutes.ts`, `validators/schemas.ts`)
- [x] **실제 발견한 버그 수정**: `PolicyApi.getPolicies()`가 `Future<Map<String,dynamic>>`로 선언돼 있었는데 백엔드는 배열을 반환함 → 호출할 때마다 타입 캐스팅 런타임 에러가 나서 "전체 검색" 탭이 항상 깨져 있었을 것. `Future<List<dynamic>>`로 수정
- [x] **DB 스키마 동기화**: 다른(동시 진행 중인) 백엔드 세션이 `Policy` 모델에 `presentation`(JSONB, AI/폴백 생성 카드 문구 — badgeText/headline/summary/targetText/benefitText/applicationText/categoryText/deadlineLabel) 필드를 추가했는데 실제 DB 컬럼이 없어서 `/api/policies`가 500 에러였음 → 사용자 확인 후 `sequelize.sync({alter:true})`로 1회성 동기화 (기존 데이터 손실 없음, 컬럼 추가만)
- [x] 북마크/캘린더 아이콘 상태를 실제 데이터로 표시 (에뮬레이터에서 북마크·캘린더 추가·D-day 배지까지 전 과정 실제 동작 확인 완료)
- [x] **라우팅 버그 수정**: `/policy/:id`를 셸(하단 네비) 브랜치 하위에 뒀더니 상세 화면 하단 CTA 버튼이 플로팅 네비게이션 바에 가려짐 → 상세 화면을 셸 밖의 최상위 라우트로 분리(마이페이지가 처음에 그랬던 것과 동일 패턴)

**의도적으로 스킵/단순화한 것**
- 정책 이미지: 백엔드에 이미지 필드가 없어 실제 사진 대신 그라데이션+문서 아이콘 placeholder 사용 (가짜 이미지 URL을 만들지 않음)
- 기존 "추천 정책"(나이/지역 기반) 및 프로필 입력 폼 UI는 목업에 없어서 화면에서 제거함 — 관련 provider(`recommendedPoliciesProvider`, `profileProvider`)와 백엔드 API는 그대로 남겨둠(마이페이지에서 계속 invalidate 호출 중이라 삭제하지 않음)
- 캘린더 추가 시 날짜는 `applicationEndDate`(없으면 시작일, 그마저 없으면 오늘)로 단순화 — `PolicyCalendarEvent`가 단일 `eventDate`만 저장하는 구조라 기간 전체를 표현할 수 없음

### 6. 마이페이지 — 디자인 시안 대비 전면 재구조화 필요
디자인 시안(12개 화면): 설정 메인 목록 / 월급 주기 설정 / 카테고리 관리·추가 / 알림 설정·공통 알림 시간·항목별 개별 시간 / 백업 및 데이터 관리 / 앱 설정 / 앱 정보 / AI 소비 분석(준비중)

**구조 자체가 다름**: 현재는 프로필카드+월급/재정+예산배분+청년정책프로필+알림수집카드+저장버튼 하나로 끝나는 **단일 롱폼 화면**(`my_page_screen.dart`). 목업은 **설정 메뉴 목록 화면 + 하위 화면 7~8개**로 완전히 다른 구조(각 행 탭 → 전용 화면 이동). 지금까지의 화면들처럼 부분 수정이 아니라 전면 재구축이 필요함.

각 하위 화면별로 실제 데이터로 구현 가능한지 확인한 결과:

**A. 설정 메인 목록 — ✅ 구현 완료**
- [x] 계정 관리 / 월급 주기 설정 / 카테고리 관리 / 알림 설정 / 백업 및 데이터 관리 / 앱 설정 / AI 소비 분석 / 앱 정보 리스트 + 로그아웃 (`my_page_screen.dart` 전면 교체). 아직 실제 화면이 없는 행(계정관리/카테고리관리/알림설정 세부/백업/앱설정)은 공용 `ComingSoonScreen`으로 연결해 죽은 링크가 없도록 함

**B. 월급 주기 설정 — ✅ 구현 완료 (월급일 기준으로 스코프 조정)**
- [x] 월급일/월 시작일을 `UserFinanceSetting.salaryDay`/`reportingStartDay` 실 데이터로 구현 (`salary_cycle_settings_screen.dart`)
- [x] "월급 주기"(매달/2주/1주/기타) 탭은 시각적으로만 배치하고 "매달"만 활성화, 나머지는 비활성+"준비 중" 안내 문구로 처리 — 백엔드에 격주/주급 개념이 없어서 실제로 동작하는 것처럼 보이게 만들지 않음(사용자 확인: 월급일 기준으로만 구현하기로 함)
- [x] 미리보기 카드(D-day/기간/남은금액/사용률)를 홈 화면과 동일한 `homeDataProvider`로 실 데이터 연동
- [x] 기존 마이페이지에 있던 월급 금액/예산 배분율/청년정책 프로필(나이·지역) 입력을 그대로 이 화면으로 이전 — 목업엔 이 필드들이 안 보였지만 갈 곳이 없어서 삭제하지 않고 유지함
- [x] 기존 "금융 알림 자동 수집" 카드(안드로이드 알림 접근 권한 + 수집 내역 조회 시트)는 "알림 설정" 메뉴로 이전(`notification_settings_screen.dart`) — 실제 동작하는 기존 기능이라 삭제하지 않음, 목업의 스케줄링 기능은 준비중 안내로 대체
- [ ] 미리보기 카드(D-day/기간/남은금액/사용률)는 홈 화면과 동일 로직(`homeDataProvider`) 재사용하면 실 데이터로 구현 가능

**C. 카테고리 관리 / 카테고리 추가 — ⚠️ 부분 가능**
- [ ] 카테고리 목록(지출/수입 탭)은 `GET /api/categories`로 실 데이터 구현 가능, 생성도 `POST /api/categories`로 가능(이미 `category_api.dart`에 있음)
- [ ] **수정·삭제·순서변경(드래그) API가 백엔드에 없음** — `categoryRoutes.ts`엔 목록조회/생성만 있고 수정·삭제 라우트 자체가 없음
- [ ] **아이콘 선택·색상 선택이 백엔드에 저장될 곳이 없음** — `Category` 모델에 icon/color 컬럼 자체가 없음(지금은 카테고리 이름으로 아이콘을 추측하는 `categoryIconFor` 클라이언트 로직만 있음). 사용자가 직접 아이콘/색을 고르는 기능을 만들려면 스키마에 필드 추가가 선행되어야 함

**D. 알림 설정 / 공통 알림 시간 / 항목별 개별 시간 — ❌ 완전 신규 기능**
- [ ] 지금 앱엔 "안드로이드 알림 접근 권한"(금융 알림 자동 수집용) 기능만 있고, 목업의 **알림 종류별 on/off, 알림 시간, 방해금지 시간, 요일별 설정** 같은 알림 스케줄링/환경설정 개념 자체가 프론트·백엔드 어디에도 없음
- [ ] 완전히 새로운 기능 — 백엔드에 알림 환경설정 저장 테이블/API, 그리고 실제 예약 알림을 발송하는 스케줄러(로컬 알림 or 푸시)까지 필요한 큰 작업. 우선순위 논의 필요

**E. 백업 및 데이터 관리 — ❌ 완전 신규 기능**
- [ ] 데이터 백업/복원/내보내기/초기화 API가 전혀 없음. "초기화"는 특히 파괴적 기능이라 백엔드 설계(무엇을 어디까지 지우는지, 되돌릴 수 있는지)를 먼저 정해야 함

**F. 앱 설정 (테마/화면표시/언어/홈화면/앱잠금) — ❌ 대부분 신규 기능**
- [ ] 다크 모드 자체가 현재 앱에 없음(`theme.dart`에 라이트 테마 하나만 정의됨) — 다크 테마 색상셋 정의 + 시스템 설정 감지 로직 신규 필요
- [ ] 금액 표시 형식, 언어 설정(다국어), 앱 잠금(PIN/생체인증)도 전부 신규 기능. 이 중 앱 잠금은 보안 기능이라 로컬 저장이 아니라 `local_auth` 같은 패키지 도입이 필요
- [ ] 이 화면은 로그인 유저 설정이라기보단 **로컬 기기 설정**에 가까워서, 서버 API보다는 `shared_preferences` 같은 로컬 저장이 더 적합해 보임 — 필요 시 확인

**G. 앱 정보 — ✅ 구현 완료**
- [x] `package_info_plus` 패키지 추가, 실제 앱 이름/버전(`1.0.0 (1)`)을 표시 (`app_info_screen.dart`)
- [x] 오픈소스 라이선스는 Flutter 기본 `showLicensePage()`로 실제 패키지 라이선스 목록 표시(실기 확인 완료 — `_fe_analyzer_shared`, `abseil-cpp` 등 실제 의존성 라이선스 나열됨)
- [x] 이용약관/개인정보처리방침/문의하기는 실제 텍스트가 없어서(사용자 제공 필요) 탭하면 "준비 중이에요" 스낵바만 표시 — 가짜 약관 텍스트를 지어내지 않음

**H. AI 소비 분석 (준비중) — ✅ 구현 완료**
- [x] 목업 그대로 "준비중" placeholder 화면 구현, 설정 메뉴에서 진입 가능

### 7. 전체 완성도 감사 (2026-09-12) — 우선순위 항목

전체 앱(화면 26개 + 백엔드 라우터 대조 + 에뮬레이터 실기 확인) 감사 결과.
상세 리포트: https://claude.ai/code/artifact/75583c63-4359-4a89-a7f5-9ca3bcc7cc48
종합 점수 65/100 — 화면은 거의 다 서 있고 데이터도 실제 백엔드에서 오지만, **계정·저장 신뢰성**이 아직 시연용.

**P0 — 사용자 배포 전 반드시 막아야 할 것**
- [ ] **예산 배분 저장 불가**: 백엔드가 배분 1건 생성 직후 "활성 배분 합계 = 100"을 검사하고 아니면 방금 만든 행을 삭제 후 400. 온보딩/마이페이지의 순차 4건 생성이 **전부 실패**. `curl`로 재현 확인 → 벌크 생성 API 필요 (아래 API 요구사항 참고)
- [ ] **인증 부재**: `auth_provider.dart`가 시작 시 시드 유저 자동 로그인 + 온보딩 자동 완료. 로그아웃이 재시작 시 무효, `supabase_flutter`는 `main.dart`에서 초기화 안 됨, `api_client.dart`는 Authorization 헤더 미전송(`DEV_AUTH_BYPASS` 의존)
- [ ] **서버 주소 하드코딩**: `api_client.dart`·`main.dart` 2곳에 `10.0.2.2:4000`. `--dart-define`으로 환경 분리
- [ ] **새로고침 수단 전무**: `RefreshIndicator` 0곳 + `NoOverscrollBehavior`로 오버스크롤 신호까지 제거 → 데이터 갱신이 앱 재시작뿐
- [ ] **`reportDataProvider` 미무효화**: autoDispose가 아닌데 `_refreshAfterChange()` 대상에서 빠져 있어, 거래 추가 후 리포트가 옛 수치 유지
- [ ] **소비 평가 저장 불가**: 백엔드 `Transaction`에 평가/mood 컬럼 0개 → 선택값이 조용히 버려짐. 컬럼 추가 또는 UI에서 제거 결정 필요
- [ ] **온보딩 `completeOnboarding`이 실패를 삼킴**: `print`만 하고 성공 처리("unblock MVP" 주석) → 배분 저장이 전부 실패해도 사용자는 완료된 줄 앎
- [ ] **캘린더 기간 표시 하드코딩**: `calendar_screen.dart:158`의 "25 ~ 24"가 고정 → 월급일을 바꿔도 잘못된 기간을 보여줌

**P1 — 사용자 손해가 있는 불편**
- [ ] 죽은 버튼 6개: 알림 벨 5개(홈 `:91`/캘린더 `:132`/리포트 `:171`/정책 `:44`/마이 `:52`) + 캘린더 검색 `:131`. 알림 목록 화면 자체가 없음
- [ ] **북마크한 정책 목록 화면이 없음** — 북마크는 저장되는데 다시 찾아볼 곳이 없음(상세 화면 아이콘 상태로만 소비)
- [ ] 에러 재시도 버튼이 홈에만 있음 → 리포트·정책·캘린더·전체거래내역은 막다른 길
- [ ] 마이페이지 정보 영역에서 **사용자 정보(이름/이메일/아바타)가 사라짐** — 내 계정을 확인할 곳이 앱 전체에 없음
- [ ] 마이페이지 메뉴 8개 중 5개가 "준비중" — 실제보다 완성된 것처럼 보임
- [ ] 홈 거래 카드가 **오늘 것만** 표시 → 오늘 지출 없으면 빈 상태. 시안의 "실시간 거래 내역"은 최근 내역. "더보기"도 캘린더 탭 이동이 아니라 전체 목록으로
- [ ] 홈 거래 카드 탭 시 상세/수정 진입 불가(수정은 캘린더 경유만)
- [ ] 캘린더 일별 게이지가 홈의 "오늘 권장액" 한 값을 한 달 전체에 재사용 → `/api/reports/daily`의 날짜별 `recommended` 사용
- [ ] 거래 수정 시 금액·메모만 변경 가능(카테고리 변경 불가 → 삭제 후 재입력 필요)
- [ ] 거래 시각 미지원: `occurredAt`이 `DATEONLY`라 시안 전반의 "17:00" 표기 불가(스키마 변경 필요)
- [ ] 로그인/온보딩 입력 검증 없음 — 빈값이면 `3,000,000원 / 25일 / 50·10·10·30` 하드코딩 폴백이 조용히 들어감. 로딩/에러 표시·진행 표시(1/4)·`_emailController.dispose()`도 없음
- [ ] 정책 검색이 카테고리 칩뿐 — 백엔드의 지역·나이·키워드 필터 미노출, `/api/policies/recommended` 화면에서 사라짐
- [ ] 리포트 인사이트 행의 쉐브론이 장식(펼칠 내용 없음)
- [ ] 다크 모드 없음(`darkTheme`/`themeMode` 미설정) — 시안 앱 설정엔 라이트/다크/시스템 있음

**P2 — 다듬기**
- [ ] 미사용 코드 정리: `quick_add_form.dart`(참조 0), `fixed_expense_api.dart`(API만 있고 화면 없음), `mocks/db.dart`
- [ ] `day_transactions_screen.dart`만 로딩이 스피너(스켈레톤 미적용)
- [ ] 폰트 `'Pretendard'` 지정만 있고 폰트 파일 없음 → 시스템 폰트로 조용히 폴백
- [ ] 앱 이름이 `finance_client` / `Finance Client`로 노출 — 한글 서비스명 필요
- [ ] 정책 이미지가 전부 동일 placeholder(백엔드 이미지 필드 없음), 긴 카테고리명 칩 잘림
- [ ] 도넛 조각 내부 그라데이션은 `fl_chart` 미지원 → 커스텀 페인터 필요
- [ ] 태블릿/웹은 `maxWidth: 430` 레터박스 대응만

---

## API 요구사항 (백엔드 확인/개선 필요)

### 공식 `API_SPEC.md` 대조 감사 (2026-09-12)

사용자가 프로젝트 루트에 작성해 둔 `API_SPEC.md`(공식 API 명세)를 기준으로 프론트 코드 전체(`lib/data/api/*.dart`)를 한 줄씩 대조했다. 결과 요약:

**✅ 명세와 정확히 일치 (문제 없음)**
- `GET/PUT /api/finance/setting`, `GET/POST /api/finance/allocations`, `PATCH /api/finance/allocations/:id` (`finance_api.dart`)
- `GET/POST/PATCH/DELETE /api/transactions`, 쿼리 파라미터와 `{items, page, limit, total}` 응답 형태 (`transaction_api.dart`)
- `GET/POST /api/categories`, 시스템 카테고리 ID 체계(`core.expense.food` 등) (`category_api.dart`, 거래/카테고리 선택 화면 전반)
- `GET/PUT /api/profile`, `GET /api/policies/recommended`, `GET /api/policies`(검색), `GET /api/policies/:id`, `POST/DELETE /api/policies/:id/bookmark`, `GET /api/policies/bookmarks` (정책 페이지 작업 때 이미 실제 응답으로 검증 완료)

**🐛 실제로 찾아서 고친 버그**
- **`GET /api/home`의 `budget` 객체에 사용률을 계산할 필드가 아예 없었음** — 명세에는 `remainingFlexibleAmount`/`reservedFixedAmount`만 있고, 백엔드 컨트롤러(`dashboardController.ts`)도 실제로 그 두 필드만 내려주고 있었음. 정작 `DailyBudgetService.calculate()`는 총예산(`flexibleBudget`)과 사용액(`flexibleSpent`)을 이미 계산해두고 있었는데 응답에 담지 않았던 것 — 그래서 프론트(`home_provider.dart`)가 "홈 화면 사용률 75%"를 **하드코딩된 가짜값**으로 표시하고 있었음(코드에 `// ponytail: placeholder 0.75 ratio` 주석까지 있었음). `dashboardController.ts`에 `flexibleBudget`/`flexibleSpent`를 추가하고 `API_SPEC.md`에도 반영, 프론트는 실제 `flexibleSpent/flexibleBudget`로 계산하도록 수정. 에뮬레이터에서 실제 거래를 만들어 0% → 55%로 정확히 바뀌는 것까지 확인함
- **예산 배분율(allocation) 저장이 신규 사용자에게 조용히 실패하고 있었음** — 사용자가 처음 앱을 켜서 배분율이 하나도 없으면 프론트가 저축40/투자20/고정생활10/소비30을 화면에 기본으로 채워 보여주는데, 이때 사용된 임시 `id`('1'~'4')는 백엔드에 존재하지 않는 값이었음. 저장 시 이 id로 `PATCH /api/finance/allocations/:id`를 호출해 404가 나는데, 에러를 `catch(_) {}`로 조용히 삼키고 "저장했어요"를 보여주고 있어서 **사용자는 저장된 줄 알지만 실제로는 아무것도 저장되지 않는** 상태였음. 기본값에는 `id: null`을 쓰고, 저장 시 id가 없으면 `POST /api/finance/allocations`(생성)를 호출하도록 수정, 에러도 더 이상 삼키지 않음

**🕳️ 기능은 있는데 화면(UI)이 없음**
- `fixed_expense_api.dart`(고정지출 API 클라이언트)가 존재하지만 **앱 어디에서도 호출되지 않음** — `POST/GET /api/fixed-expenses`, occurrence 매칭 기능이 백엔드엔 다 있는데 구독료·월세 같은 고정지출을 등록/조회하는 화면 자체가 없음. 필요하면 마이페이지나 홈 화면에 신규 기능으로 추가 가능

**🚨 백엔드에 새로 요청하는 것 (2026-09-12 감사)**
- **배분 벌크 저장 API**(`PUT /api/finance/allocations`로 배열 전체 교체) — 현재 `POST /api/finance/allocations`는 행을 만든 **직후** "활성 배분 합계 = 100"을 검사하고 실패하면 방금 만든 행을 삭제한 뒤 `INVALID_ALLOCATION_TOTAL` 400을 낸다. 즉 한 건씩 만드는 경로로는 합계 100에 절대 도달할 수 없어서, 온보딩·마이페이지의 순차 4건 생성이 전부 실패한다. `curl -X POST … percentage:40` → `{"code":"INVALID_ALLOCATION_TOTAL"}`로 재현 확인. 벌크 교체 API를 주거나, 합계 검증을 "활성화 시점"으로 미루는 방식 중 하나가 필요. 카테고리 추가/삭제도 같은 이유로 현재 불가능
- **`Transaction`에 시각 컬럼** — `occurredAt`이 `DATEONLY`라 시안 전반의 "17:00" 시각 표기와 시간 선택 UI를 만들 수 없다. `occurredAt`을 `DATE`(timestamp)로 바꾸거나 별도 `occurredTime` 컬럼 필요
- **`Transaction`에 소비 평가 컬럼** — 거래 입력 화면의 소비 평가(만족/평범/아쉬움)를 저장할 곳이 없어 선택값이 버려진다(모델에 mood/rating/evaluation 컬럼 0개 확인). 리포트의 "만족한 소비 비중" 같은 인사이트도 이 컬럼이 있어야 가능
- **카테고리별 예산** — 예산이 `spendability` 단위로만 있어 리포트의 "카테고리별 예산 대비 사용액"을 만들 수 없다(현재는 "전체 대비 비중"으로 대체). `CategoryBudget` 스키마 필요
- **월급 주기 타입** — `UserFinanceSetting`에 주기 타입이 없어 월 단위만 지원. 시안의 2주/1주/기타 옵션은 비활성 상태
- **정책 신청 기간 캘린더 등록** — `POST /api/policies/:id/calendar`가 단일 `eventDate`만 받아 신청 기간(시작~마감) 전체를 표현하지 못함
- **정책 이미지 필드** — 목록/상세의 썸네일이 전부 동일한 그라데이션 placeholder. 이미지 URL 필드가 없음

**📝 명세에 없는 것 (이번 세션에서 추가함, 문서화 필요)**
- `GET /api/policies/calendar`, `POST/DELETE /api/policies/:id/calendar` (정책 "내 캘린더에 추가" 기능) — 지난 세션에 `PolicyCalendarEvent` 테이블은 있었지만 API가 없어서 기존 북마크 패턴대로 직접 추가한 엔드포인트인데, 사용자가 작성한 공식 `API_SPEC.md`에는 아직 반영이 안 되어 있음. 계속 쓸 기능이면 명세에 추가하는 게 좋음

**⚠️ 알고 있어야 할 기존 제약 (버그 아님, 명세에도 명시됨)**
- `api_client.dart`가 `Authorization` 헤더를 아예 안 보냄(주석 처리된 TODO) — 명세의 `DEV_AUTH_BYPASS=true` 개발 모드에 의존 중. 운영 배포 전에는 실제 Supabase 토큰 연동이 필요함(기존에 이미 알려진 사항)
- Android 알림 수신 시 "UNSUPPORTED_NOTIFICATION_PACKAGE" 400이 계속 뜨는 것은 명세에 문서화된 정상 동작(허용 패키지 목록에 없는 알림은 거부) — 실제 지원할 카드사 패키지명을 백엔드 `NOTIFICATION_ALLOWED_PACKAGES` 환경변수에 추가해야 함(기존에 이미 알려진 사항)

---

`financeBackend` 소스(`src/services/reportService.ts`, `src/controllers/reportController.ts`, `src/models/index.ts`)를 직접 확인해서 실제 계약을 파악했다. 아래는 그 결과 정리 + 남은 개선 요청이다.

- **[해결됨] `GET /api/reports/daily` 응답이 배열이 아니라 객체였음 — 프론트 버그였고 백엔드는 정상**
  - 실제 응답: `{ period: {startDate,endDate}, summary: {totalIncome,totalExpense,noSpendDays,noActivityDays}, daily: [{date,income,expense,spent,recommended,difference}] }`
  - 프론트의 `ReportApi.getDaily()`가 `Future<List<dynamic>>`로 잘못 선언되어 있어서 호출할 때마다 타입 캐스팅 런타임 에러가 났을 것 → `Future<Map<String, dynamic>>`로 수정 완료. **무지출 일수(`noSpendDays`)는 이미 이 응답에 포함되어 있어서 별도 백엔드 작업 없이 캘린더 요약 카드에 바로 연동함.**
- **[해결됨] `GET /api/reports/summary` 필드명 불일치 — 프론트 버그였고 백엔드는 정상**
  - 실제 응답: `{ income, expense, saving, investment, remainingAvailableAmount }` (필드명은 `expense`, `totalSpent`가 아님) → 프론트 수정 완료
- **[해결됨] `GET /api/reports/categories` 필드명 불일치 — 프론트 버그였고 백엔드는 정상**
  - 실제 응답: `[{ category, amount, transactionCount, percentage }]` (필드명은 `category`, `name`이 아니고 `id`도 없음) → 프론트 수정 완료
- **[확인 완료] `getPace()`(`GET /api/reports/pace`)는 월별/주별 비교용이 아님**
  - 실제 응답: `{ current: {cycleStart, cycleEnd, ...현재 예산주기 계산결과}, previous: null }` — `previous`가 코드상 항상 `null`로 고정되어 있어 이 API로는 전월 비교를 할 수 없음. 홈 화면의 "오늘 쓸 수 있는 금액" 계산과 같은 로직(현재 주기 페이스 확인용)이라 리포트 비교 화면과는 목적이 다름
  - **개선 요청**: 정말 전월 대비 페이스 비교 기능이 필요하면 `previous` 계산 로직을 실제로 구현해주거나, 아니면 이 필드를 응답에서 빼서 클라이언트가 오해하지 않게 정리 필요
- **[대체 구현함] "월별/주별 총 지출 비교" 화면은 `getMonthly()`(`GET /api/reports/monthly`)로 구현**
  - 실제 응답: `[{month:'YYYY-MM', income, expense, saving, investment}, ...]` (전체 기간, 필터 파라미터 없음) — 이번달/지난달 항목을 찾아 총지출 비교에 사용. 주차별 비교는 `getDaily()`의 일별 데이터를 프론트에서 주 단위로 합산해서 구현(원시 데이터가 정확하므로 문제 없음)
  - **참고**: `getMonthly()`가 시작/종료 날짜 필터를 안 받아서 매번 전체 이력을 다 내려줌 — 가입 기간이 길어지면 불필요하게 응답이 커질 수 있으니 `months` 개수 제한 파라미터가 있으면 더 효율적일 것
- **[신규 발견, 백엔드 스키마 변경 필요] 카테고리별 예산(budget) 데이터가 아예 없음**
  - 목업의 "카테고리 별 지출 상세" 화면은 "식비 400,000원/200,000원(예산 초과)"처럼 카테고리별 예산 대비 사용액을 보여주는데, 백엔드 스키마를 확인해보니 예산은 `BudgetCycleAllocation`에 `spendability`(LOCKED/RESERVED/FLEXIBLE) 단위로만 저장되고 특정 카테고리(예: "식비")에 대한 예산 개념 자체가 없음
  - 가짜 숫자를 만들 수 없어서 이 기능은 구현하지 않고, 대신 "전체 지출 대비 비중"으로 대체함 (`category_report_detail_screen.dart`)
  - **개선 요청**: 카테고리별 예산 기능을 정말 원하면 `Category`(또는 `BudgetCycleAllocation`)에 카테고리별 월 예산 필드를 추가하는 스키마 변경이 선행되어야 함
- **[해결됨] `GET /api/policies/bookmarks` 응답에 마감일 필드 포함 확인됨**
  - 실제 응답: `[{bookmarkId, bookmarkedAt, policy: {id, title, category, provider, applicationStartDate, applicationEndDate, applicationUrl, presentation}}]` — `applicationEndDate` 포함돼 있어 추가 호출 없이 마감 배지 구현 가능했음. 다만 정책이 `policy` 키로 중첩돼 있는데 프론트가 평평한 객체로 잘못 가정하던 버그가 있어서 수정함 (정책 페이지 작업 항목 참고)
- **[신규] "월급 주기"(매달/2주/1주/기타) 개념이 백엔드에 없음**
  - 마이페이지 목업의 "월급 주기 설정" 화면은 월급을 매달/2주/1주/기타 주기로 받는 사람을 위한 설정인데, `UserFinanceSetting`(salaryAmount/salaryDay/reportingStartDay)과 `BudgetCycle` 모두 월 단위 고정 구조라 격주·주급 개념 자체가 없음
  - **개선 요청**: 이 기능을 정말 만들려면 `UserFinanceSetting`에 `cycleType`(MONTHLY/BIWEEKLY/WEEKLY/CUSTOM) 같은 필드를 추가하고, `BudgetCycleService`의 주기 계산 로직도 월 단위 가정을 벗어나야 함 — 영향 범위가 커서 우선순위 논의 필요
- **[신규] 카테고리 수정/삭제/순서변경 API가 없음**
  - `categoryRoutes.ts`엔 목록조회(`GET /`)와 생성(`POST /`)만 있고 수정·삭제 라우트가 없음. 마이페이지의 "카테고리 관리"(수정/삭제/드래그 순서변경)를 구현하려면 `PATCH/DELETE /api/categories/:id`가 필요
- **[신규] `Category` 모델에 아이콘/색상 필드가 없음**
  - 지금은 카테고리 이름을 보고 아이콘을 추측하는 클라이언트 로직(`categoryIconFor`)만 있음. 마이페이지의 "카테고리 추가" 화면처럼 사용자가 아이콘/색을 직접 고르게 하려면 `Category`에 `icon`, `color` 컬럼 추가가 선행되어야 함
- **[신규] 알림 환경설정(종류별 on/off, 시간, 방해금지시간) 저장 API가 없음**
  - 지금 앱의 "알림"은 안드로이드 알림 리스너 접근 권한(금융 알림 자동 수집용)뿐이고, 목업의 알림 스케줄링/환경설정 개념 자체가 백엔드에 없음. 실제 예약 발송까지 구현하려면 저장 API + 스케줄러(로컬 알림 or 서버 푸시) 둘 다 필요한 큰 작업
- **[신규] 데이터 백업/복원/내보내기/초기화 API가 없음**
  - "초기화"는 파괴적 동작이라 무엇을 어디까지 지우는지, 되돌릴 수 있는지 등 백엔드 설계를 먼저 정해야 함

---

## Done

- **2026-09-13 (2)**:
  - [x] **캘린더 오늘 날짜 항상 초록 원 표시**: `_buildCalendarCell`의 24px 날짜 원에 `isToday && !isSelected`일 때 초록 테두리(`Border.all`)를 추가 — 지출 유무와 무관하게 오늘 날짜에 항상 원이 보이도록 함(기존엔 지출이 있는 날에만 그라데이션 링이 그려지고 오늘 자체를 표시하는 장치가 없었음)
  - [x] **홈페이지 마이너스 색상 톤다운**: `AppColors.danger`(0xFFFF3D00)가 큰 히어로 숫자에 쓰기엔 너무 쨍해서, `theme.dart`에 부드러운 코랄톤 `AppColors.dangerSoft`(0xFFF2665A)를 신규 추가하고 홈페이지의 마이너스 표시 전부(히어로 금액, 상세 시트 헤드라인, "어제 소비 돌아보기"의 금액/아이콘/건수)에 적용. 캘린더·리포트 등 다른 화면의 기존 `danger` 색상은 원래대로 유지(요청이 "홈페이지에서"로 한정됨)
  - [x] **홈 실시간 거래내역 카드 탭 → 상세(수정) 진입**: `_buildTransactionGrid`의 카드가 탭 핸들러가 전혀 없어서 눌러도 반응이 없던 것을, "어제 소비 돌아보기" 항목과 동일하게 `Material`+`InkWell`로 감싸 탭 시 `AddTransactionModal`(내역 수정하기)이 열리도록 구현 — 그림자가 클리핑되지 않도록 바깥 `Container`(그림자)+안쪽 `Material`(배경색+리플 클립) 이중 구조로 처리. 에뮬레이터에서 카드 탭 → 수정 모달 진입까지 확인
- **2026-09-13**:
  - [x] **소비 평가 저장 + 홈 화면 "어제 소비 돌아보기" 섹션 신규 구현**: 사용자가 `API_SPEC.md`에 `consumptionEvaluation`(GOOD/NORMAL/REGRETTABLE/BAD) 필드를 추가해서 확인해보니, 백엔드(`Transaction` 모델·검증 스키마·컨트롤러)는 이미 이 필드를 완전히 지원하고 있었음(다른 세션이 먼저 구현) — 그런데 **프론트의 `TransactionApi.createTransaction`/`updateTransaction`이 이 필드를 요청 body에 아예 담지 않고 있어서**, 거래 입력 화면에서 소비 평가(좋음/보통/아쉬움/나쁨)를 골라도 항상 버려지고 있던 버그를 발견해 수정. 수정 상세:
    - `TransactionApi`에 `consumptionEvaluation` 파라미터 추가, 생성/수정 요청에 포함
    - `add_transaction_screen.dart`: 저장 시 선택된 `_moodIndex`를 실제 enum 값으로 매핑해 전송, 기존 거래 수정 시에는 저장된 `consumptionEvaluation`으로 `_moodIndex`를 복원(이전엔 항상 "보통"으로 초기화되던 것도 같이 고침)
    - 홈 화면에 목업대로 "어제 소비 돌아보기" 섹션 신규 추가 — `GET /api/transactions`(어제 날짜, `type=EXPENSE`)를 가져와 `consumptionEvaluation === REGRETTABLE`인 항목만 클라이언트에서 필터링(새 백엔드 API 불필요, 하루치라 필터 파라미터 추가 없이도 충분). 항목이 없으면 섹션 자체를 숨김(캘린더 "관심 정책" 섹션과 동일한 패턴)
    - 목업의 브랜드 로고 대신 앱 전역 컨벤션대로 `categoryIconFor` 원형 아이콘 사용, 시간(17:00)은 `occurredAt`이 `DATEONLY`라 표시 불가능해서 다른 거래 카드와 동일하게 날짜(MM-DD)로 대체 — 가짜 데이터를 만들지 않음
    - 항목 탭 시 기존 거래 수정 모달(`AddTransactionModal`)로 이동 (앱에 이미 있는 "공통 상세" 동선 재사용)
    - 에뮬레이터에서 `consumptionEvaluation:"REGRETTABLE"` 거래 2건을 만들어 섹션이 목업과 동일하게 렌더링되는 것, 항목을 눌렀을 때 저장된 "아쉬움" 평가가 정확히 복원되는 것까지 실기 확인 완료
  - [x] **홈 화면 3건 수정**: (1) 당겨서 새로고침 — `home_screen.dart`의 `CustomScrollView`를 `RefreshIndicator`로 감싸 아래로 당기면 상단 원형 스피너가 돌며 새로고침되도록 구현, `homeDataProvider`/`homeRecentTransactionsProvider`에 `skipLoadingOnRefresh: false`를 줘서 새로고침 중엔 스켈레톤(`HomeHeroSkeleton`/`TransactionCardsSkeleton`)이 다시 보이도록 함. (2) **버그 수정**: 거래 등록/수정/삭제 후 `_refreshAfterChange()`가 `homeDataProvider`만 무효화하고 `homeRecentTransactionsProvider`(홈 화면 실시간 거래 내역 카드)는 빠뜨리고 있어서 홈으로 돌아와도 방금 등록한 거래가 바로 안 보이던 문제 — 무효화 목록에 추가해서 해결. (3) 오늘 쓸 수 있는 돈(`remainingToday`)이 초과 지출로 마이너스가 되면 히어로 큰 숫자와 상세 시트 헤드라인 모두 기존 위험색(`AppColors.danger`)으로 표시되도록 함
    - **백엔드 버그 발견·수정**: (3)을 실기로 검증하다가 `dashboardController.ts`의 `remainingToday`가 `Math.max(0, recommended - spentToday)`로 **항상 0 이상으로 clamp**되고 있어서, 프론트가 아무리 마이너스 색상 로직을 넣어도 실제로는 절대 마이너스 값이 내려오지 않던 것을 발견함. `remainingFlexibleAmount`(월 전체 잔액)는 이미 음수를 허용하고 `budgetStatus: OVER_BUDGET`으로 처리하고 있어서, 하루 단위(`remainingToday`)만 clamp하는 게 일관성이 없기도 했음 → clamp 제거하고 실제 초과분(음수)을 그대로 내려주도록 수정. `curl`로 `remainingToday: -18889` 확인, 에뮬레이터에서 30,000원 지출 등록 후 당겨서 새로고침 → "-18,889"가 빨간색으로 정확히 표시되는 것까지 실기 확인 완료
- **2026-09-12**:
  - [x] **하단 네비 탭 효과 정리 + 스켈레톤 레이아웃 개선 + 모달 시 네비바 숨김**:
    - 탭을 누르면 옆 버튼까지 번쩍이던 문제 수정 — 원인은 셀 전체를 덮은 `InkWell`이 `clipBehavior`가 없는 `Material` 위에 있어서 splash가 자기 영역 밖으로 번지던 것. 탭 영역은 셀 전체로 유지(`GestureDetector`)하면서 리플은 아이콘 알약(40×26) 안으로 가두고(`Material(clipBehavior: Clip.antiAlias)`), 선택 색상은 `Material.animationDuration`, 라벨은 `AnimatedDefaultTextStyle`로 부드럽게 전환. 에뮬레이터에서 탭을 누른 채 캡처해 눌린 버튼만 반응하는 것 확인
    - 스켈레톤을 회색 덩어리에서 **실제 레이아웃을 따라가는 카드형**으로 전면 재작성 (`SkeletonBox.line`/`SkeletonBox.lightLine`/`SkeletonCard` 프리미티브 + 화면별 스켈레톤): `ReportSkeleton`(초록 히어로+차트+도넛/범례+인사이트), `PolicyListSkeleton`(필터칩+히어로카드+썸네일 행), `HomeHeroSkeleton`(반투명 흰색 톤으로 초록 히어로에 맞춤), `TransactionCardsSkeleton`, `CalendarSummarySkeleton`, `TransactionRowsSkeleton`, `FormSkeleton`(라벨/값 행+미리보기 카드). 리포트 스켈레톤은 실기 캡처로 확인
    - 하단 모달이 뜨면 플로팅 네비바가 사라지도록 처리 — `ModalRoute.of(context)!.isCurrent`로 셸 위에 무언가 올라온 상태를 감지해 `AnimatedSlide`+`AnimatedOpacity`로 자연스럽게 내려가게 함. 더불어 `useRootNavigator: true`가 빠져 있던 시트 2개(리포트 월 선택, 정책 캘린더 추가)를 수정 — 리포트 월 선택 시트는 브랜치 네비게이터에 올라가서 네비바가 시트 위에 떠 있었음. 홈 예산 시트/리포트 월 선택 시트 모두 실기로 확인
  - [x] **홈 화면 사용률 그라데이션 + 스켈레톤 로딩 전체 적용 + 하단 네비 가림 확인 + 공식 API_SPEC.md 감사**:
    - 홈 화면 사용률 게이지(4분할 바)와 마이페이지 월급 주기 미리보기 바에 그라데이션 적용 (`GradientProgressBar` 공용 위젯 신규, `LinearProgressIndicator`는 단색만 지원해서 `FractionallySizedBox` 기반으로 직접 구현)
    - 그 과정에서 사용률 자체가 **하드코딩된 가짜 75%**였던 걸 발견 → 백엔드 `/api/home` 응답에 `flexibleBudget`/`flexibleSpent` 필드 추가(`DailyBudgetService`엔 이미 계산되어 있었음), `API_SPEC.md` 문서 갱신, 프론트에서 실제 사용률 계산하도록 수정. 에뮬레이터에서 실거래 생성 후 0%→55%로 정확히 바뀌는 것 확인
    - 재사용 가능한 `SkeletonBox`/`HomeSkeleton`/`ListCardsSkeleton`/`FormSkeleton` 위젯 신규 구현(패키지 추가 없이 직접 구현), 홈/캘린더(요약카드·거래내역시트)/리포트/정책 목록·상세/마이페이지(월급주기설정) 로딩 상태를 전부 스피너에서 스켈레톤으로 교체
    - 리포트/정책 목록/마이페이지(설정 메뉴) 화면의 리스트 하단 패딩이 24~40px로 부족해서 로그아웃 버튼 등이 플로팅 하단 네비게이션 바에 가려지고 있던 것을 확인 → 홈/캘린더와 동일한 100px로 통일. 에뮬레이터로 실제 가려짐 해소 확인
    - 공식 `API_SPEC.md`를 기준으로 프론트 API 클라이언트 전체를 대조 감사 — 위 사용률 버그 외에 **예산 배분율 저장이 신규 사용자에게 조용히 실패하던 버그**(존재하지 않는 임시 id로 PATCH → 404를 무시하고 성공 메시지 표시)도 발견해 수정(id 없으면 생성 API 호출). `fixed_expense_api.dart`가 어디에서도 쓰이지 않는 것, 이번에 새로 추가한 정책 캘린더 API가 아직 공식 명세에 없는 것도 확인해 정리. 상세 내용은 위 "API 요구사항" 섹션 참고
  - [x] **마이페이지: 앱 정보 / AI 소비 분석 / 월급 주기 설정(월급일 기준) 구현**:
    - `my_page_screen.dart`를 단일 롱폼에서 목업 스타일의 **설정 메뉴 목록**으로 전면 교체 (계정관리/월급주기설정/카테고리관리/알림설정/백업및데이터관리/앱설정/AI소비분석/앱정보 + 로그아웃). 아직 없는 기능은 재사용 가능한 `ComingSoonScreen`(목업의 AI소비분석 placeholder 디자인 그대로)으로 연결해 죽은 링크 없이 마무리
    - `salary_cycle_settings_screen.dart` 신규: 월급일/월 시작일 드롭다운 + 미리보기 카드(홈 화면과 동일 `homeDataProvider` 재사용, 실제 D-day/금액/사용률) 실 데이터로 구현. "월급 주기"(매달/2주/1주/기타) 탭은 사용자 확인에 따라 **월급일 기준으로만** 구현 — 매달만 활성화하고 나머지는 비활성+"준비 중" 표시(백엔드에 격주/주급 개념이 없어서 동작하는 척 만들지 않음)
    - 기존 마이페이지에 있던 월급 금액/예산 배분율/청년정책 프로필(나이·지역) 입력과 "금융 알림 자동 수집" 카드는 목업에 갈 곳이 명시돼 있지 않아 각각 월급 주기 설정 화면과 알림 설정 화면(`notification_settings_screen.dart`)으로 이전 — 실제 동작하던 기능이라 삭제하지 않음
    - `app_info_screen.dart` 신규: `package_info_plus`로 실제 앱 이름/버전 표시, Flutter 기본 `showLicensePage()`로 실제 패키지 라이선스 목록 표시. 이용약관/개인정보처리방침/문의하기는 실제 텍스트가 없어 "준비 중" 스낵바로 처리(가짜 약관 텍스트 지어내지 않음)
    - 설정 하위 화면들은 셸(하단 네비) 브랜치가 아니라 `Navigator.of(context, rootNavigator: true).push(...)`로 이동 — 정책 상세에서 겪었던 플로팅 네비게이션 바 겹침 버그를 처음부터 피함
    - 에뮬레이터에서 설정 메뉴 → 월급 주기 설정(실 데이터 D-28/금액/배분율) → 뒤로가기 → AI소비분석/앱정보(실제 버전 1.0.0(1))/오픈소스 라이선스(실제 패키지 목록)까지 전부 실기 확인 완료
  - [x] **마이페이지 목업 vs 현재 구현 비교 분석**: 목업 12개 화면(설정 메인 목록 + 월급주기설정 + 카테고리관리/추가 + 알림설정/공통시간/개별시간 + 백업및데이터관리 + 앱설정 + 앱정보 + AI소비분석)을 검토한 결과, 현재는 단일 롱폼 화면인데 목업은 설정 메뉴+하위화면 구조로 전면 재구축이 필요함을 확인. 화면별로 백엔드 데이터로 바로 구현 가능한지 조사(카테고리 목록/생성은 있으나 수정·삭제·아이콘·색상 없음, 월급 주기 타입 개념 없음, 알림 환경설정·백업·다크모드·앱잠금은 완전 신규 기능)하고 To Do·API 요구사항에 정리, 아직 구현은 하지 않음
  - [x] **정책(청년정책) 페이지 신규 구현 + 하단 네비 "뉴스"→"정책" 교체**:
    - 하단 네비 4번째 탭을 뉴스(placeholder, 폴더째 삭제)에서 정책으로 교체
    - 정책 목록/상세 화면을 시안(Frame 116/119/129/131)대로 전면 재구현, "내 캘린더에 추가" 확인 팝업까지 구현
    - 백엔드에 테이블만 있고 API가 없던 `PolicyCalendarEvent` 기능을 기존 북마크 패턴으로 신규 구현(`financeBackend`의 service/controller/route/validator에 추가)
    - 프론트 버그 2건 수정: `getPolicies()` 반환 타입이 실제론 배열인데 Map으로 잘못 선언돼 있던 것, `getBookmarks()`가 정책을 중첩 반환하는데 평평한 객체로 잘못 가정하고 있던 것(둘 다 이 기능들이 지금까지 조용히 깨져 있었을 가능성이 있었음)
    - 다른 세션이 동시에 백엔드에 추가한 `presentation`(AI/폴백 생성 카드 문구) 필드가 DB에 반영 안 돼 있어 500 에러였던 것을, 사용자 승인 받아 `sequelize.sync({alter:true})`로 1회성 스키마 동기화
    - 정책 상세 화면을 셸(하단 네비) 브랜치에 뒀다가 CTA 버튼이 플로팅 네비바에 가려지는 버그 발견 → 최상위 라우트로 분리해 수정
    - 에뮬레이터에서 정책 목록→상세→북마크 토글→캘린더 추가→캘린더 페이지에 "정책 D-4" 배지로 실제 반영되는 것까지 전 과정 실기 확인 완료
    - 정책 이미지(실제 사진 없음, placeholder로 대체)와 카테고리별 예산 부재는 아래 "남은 것"/API 요구사항에 기록
  - [x] **리포트 메인 화면 최종 시안 반영 (스타일 리디자인)**:
    - 히어로 영역을 옅은 민트색 고정높이 배경 + 개별 흰 카드 구조에서, 홈 화면과 동일한 진한 초록 그라데이션이 지출요약+월선택 알약까지 이어지는 구조로 변경. 헤더/지출요약/비교문구를 전부 흰 텍스트로, 지출요약은 중앙정렬로 변경
    - 월 선택을 `‹ 8월 ⌄ ›`(좌우화살표+흰카드)에서 좌우화살표 없는 알약 하나("9월 ⌄", 탭하면 월 선택 시트)로 단순화
    - 차트/도넛/인사이트 섹션을 각각의 그림자 있는 개별 흰 카드에서, 히어로 아래 하나로 이어지는 연속된 흰 배경 위에 배치하도록 변경 (`Stack+Positioned` → `Column(hero, Expanded(ListView))` 구조로 재작성)
    - "이번 달 리포트 요약" 인사이트 행 스타일 변경: 감정에 따라 배경색 분리(좋은 지표=연초록+👍, 지출 쏠림 지표=연빨강+👎), 핵심 숫자/단어를 행 강조색으로 볼드 처리, 우측에 펼치기 쉐브론 아이콘 추가
    - 3번째 인사이트 지표는 사용자 확인에 따라 "요일별 합계 최댓값" 로직 유지(최종 목업의 "하루 최댓값" 문구로 바꾸지 않음)
    - 도넛 차트 조각 내부 그라데이션 음영은 fl_chart의 `PieChartSectionData`가 조각별 그라데이션을 지원하지 않아 스킵 — 필요하면 커스텀 페인터로 별도 구현 필요 (스킵 사실을 사용자에게 안내함)
    - 에뮬레이터에서 실행해 목업과 나란히 대조 확인 완료
  - [x] **리포트 페이지 실제 데이터 전면 연동 (목업/가짜 데이터 전부 제거)**:
    - `financeBackend` 소스를 직접 읽어 `/api/reports/*` 실제 응답 계약 확인
    - **중대 버그 수정**: `ReportApi.getDaily()`가 실제로는 객체(`{period,summary,daily}`)를 반환하는데 `List<dynamic>`로 잘못 선언되어 있어 매번 런타임 타입 에러가 나고 있었음 → 타입 수정 + 캘린더/리포트 호출부 갱신
    - **버그 수정**: `summary['totalSpent']`(존재하지 않는 필드) → `expense`로, 카테고리 `['name']`(존재하지 않는 필드) → `['category']`로 수정. 이 두 버그 때문에 지출액이 항상 0으로 보이거나 카테고리 범례가 항상 목업 이름으로 보였을 것
    - 요약 카드 "지난달보다 N% 적게" 문구를 `getSummary()`+`getMonthly()` 기반 실제 계산으로 교체 (지난달 데이터 없으면 "비교할 수 없어요")
    - 일별 소비 흐름 차트의 지난달 라인을 실제 지난달 `getDaily()` 데이터로 교체, x축 라벨/오늘 표시를 보고 있는 달 기준으로 동적 계산
    - 카테고리 도넛/범례를 실제 데이터로만 렌더링(빈 상태는 "지출 내역이 없어요"), "외 N건"을 실제 남은 개수로 계산
    - "이번 달 리포트 요약" 인사이트 카드(전월 대비 %/최다지출 카테고리/최다지출 요일) 신규 추가, 전부 실제 데이터로 계산
    - 월 선택 바텀시트(1~12월 그리드) 추가
    - "더보기" 눌러서 들어가는 신규 화면 2개 구현: `category_report_detail_screen.dart`(카테고리별 전체 목록+비중 막대바), `monthly_comparison_screen.dart`(월별/주별 총 지출 비교, 실제 `getMonthly`/`getDaily` 기반)
    - 카테고리별 예산(budget) 데이터는 백엔드 스키마에 없는 것으로 확인 → 가짜 숫자 대신 "전체 대비 비중"으로 대체, 스키마 확장이 필요하다는 점을 API 요구사항에 기록
    - 캘린더 화면도 같은 `getDaily()` 버그의 영향을 받고 있어서 함께 수정: 월간 요약 카드(무지출 일수/수입/지출)를 실제 데이터로 교체
    - `flutter analyze` 전체 통과 확인, 에뮬레이터에서 실제 실행해 캘린더·리포트·카테고리상세·월별비교 화면 전부 스크린샷으로 렌더링 확인 완료
  - [x] **리포트 페이지 목업 vs 현재 구현 비교 분석**: 디자인 시안(월선택/리포트메인/카테고리상세/소비흐름비교/주별비교/월별비교) 대비 미구현 화면 및 기존 하드코딩된 목업 데이터(지난달 라인, "8% 적게" 문구, "외 6건") 정리, `getPace`/`getMonthly` 미사용 API 확인 및 To Do·API 요구사항 등록
  - [x] **캘린더 게이지 링 & 관심 정책 연동 수정**:
    - 소비 사용률 게이지 링에 그라데이션 색상 적용 (`_GradientRingPainter` 커스텀 페인터, Canvas 직접 그리기)
    - 지출 0원인 날은 회색 게이지 링을 아예 그리지 않도록 수정 (`hasSpending` 가드)
    - 캘린더 날짜 셀에 북마크한 관심 정책의 마감일 배지("정책 D-N"/"정책 D-Day") 표시 추가
    - "거래 내역" 팝업의 "관심 정책" 섹션이 실제로는 추천 정책을 보여주던 버그 수정 → 실제 북마크(`bookmarkedPoliciesProvider`) 기반으로 교체, 여러 건 리스트 표시
    - 위 "API 요구사항" 섹션에 백엔드 확인 필요 사항 정리
  - [x] **홈 화면 디자인 시안 반영**:
    - 하단 네비게이션 바를 시안대로 홈 / 캘린더 / 리포트 / 뉴스 / 마이 5탭 구조로 개편 (`lib/core/router.dart`), 강조색을 그린(`AppColors.primary`)으로 변경하고 선택 탭에 라운드 필 하이라이트 적용
    - "마이" 탭을 별도 push 화면에서 하단 탭(셸 브랜치)으로 편입, 홈 화면 아바타 탭도 `context.go('/mypage')`로 연동
    - "뉴스" 탭 최소 placeholder 화면 신규 생성 (`lib/features/news/screens/news_screen.dart`)
    - "정책" 화면은 시안에 탭으로 없어 최상위 독립 라우트로 유지 (캘린더 상세 등 기존 진입 경로 그대로 동작)
    - 카테고리 필터 칩에 아이콘 추가, 거래 카드 카테고리 배지에 아이콘 추가, 거래 카드 로고 영역을 소비 분류 아이콘 기반 원형 아바타로 변경 (사용자 확인: 별도 브랜드 로고 이미지 불필요, 기존 카테고리 아이콘 재사용으로 확정)
    - 중복 카테고리 아이콘 매핑 로직 제거하고 기존 `categoryIconFor` 공용 함수로 통일
  - [x] **AI 작업 진행 규칙 수립**: 요청마다 `aiProgress.md` 확인 및 To Do / Done 기록 체계 구축
  - [x] **Android 금융 알림 백그라운드 수집 & 백엔드 동기화 파이프라인 구축**:
    - `NotificationListenerService` 기반 금융/카드사 알림 필터링 및 가로채기
    - Android Room 로컬 큐 (`NotificationInbox`, SQLite DB) 적재
    - Android WorkManager (`NotificationSyncWorker`) + OkHttp를 통한 백그라운드 지수 백오프 재시도 및 백엔드 전송 (`POST /api/notifications`)
    - 중복 방지 SHA-256 `EventIdGenerator` 및 패키지 Allowlist (`FinancialAppAllowlist`)
    - `EncryptedSharedPreferences` 기반 보안 설정 저장소
    - Flutter `MethodChannel` (`finance_app/notification_access`) & `EventChannel` (`finance_app/notification_events`) 연동
    - 온보딩 4단계 알림 접근 권한 요청 및 라이프사이클 복귀 감지
    - 마이페이지 알림 접근 권한 상태 카드 및 마스킹된 로컬 수집 큐 디버그 바텀시트 모달 구현
    - 앱 시작 시 기본 `baseUrl` (`http://10.0.2.2:4000`) 자동 동기화
  - [x] **홈 화면 실시간 거래내역 오늘 날짜 필터링**: 당일 거래 내역만 필터링하여 목록에 표시하도록 개선
  - [x] **거래 입력/수정 모달창 높이 고정 및 키보드 오버레이 대응**: 카테고리 선택에 따라 높이가 흔들리지 않도록 고정하고 스마트폰 키보드 높이만큼 화면이 위로 올라가도록 개선
  - [x] **홈 화면 목업 vs 현재 구현 비교 분석**: 디자인 시안 대비 UI 불일치 사항 정리 및 To Do 등록
  - [x] **프로젝트 구조 1차 파악**: Flutter + Riverpod + go_router + Supabase 구조 분석

