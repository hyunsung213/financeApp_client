# Report UX 개발 명세

이 문서는 Report 영역의 화면 구조, 상태, 이동, 데이터 계약을 정의하는 구현 및 검수 기준이다. Figma에서 직접 확인한 사실과 Prototype 정의, 제품 결정, Backend 의존성, 아직 결정되지 않은 항목을 분리해서 기록한다.

## 0. 문서 범위와 우선순위

| 항목 | 값 |
| --- | --- |
| Figma file | `월릿-wallet` (`F8IxMoDpZ2e8RCGFQLSHxr`) |
| Figma page | `report` (`114:4951`) |
| Section | `FINAL_REPORT_SCREENS` (`545:2982`) |
| Prototype flow | `Flow 2` |
| Flow starting point | `Frame 69` (`362:3635`) |
| 기준 viewport | 주요 화면 `375 × 812`; Report Main 원본 Frame은 `375 × 1119` |

충돌 시 적용 순서는 다음과 같다.

1. **C. 사용자와 추가로 확정한 제품 규칙**
2. **B. Prototype에서 직접 확인된 interaction**
3. **A. Figma에서 직접 확인된 사실**
4. **E. 아직 미정인 항목**은 구현 전에 결정하거나 명시적으로 미지원 상태로 유지한다.

Figma 제작 artifact로 확인된 월 선택용 category component 재사용과 미연결 navigation은 실제 앱 동작의 기준으로 사용하지 않는다.

---

# A. Figma에서 직접 확인된 사실

## A.1 Screen inventory

| 실제 Frame 이름 | Node ID | 개발 명칭 | 크기 | 화면 목적 | 주요 UI |
| --- | --- | --- | --- | --- | --- |
| `Frame 69` | `362:3635` | Report Main | `375 × 1119` | 선택 월의 소비 요약 진입점 | 월 선택, 총지출/전월 비교, 일별 차트, 카테고리 도넛, 인사이트 3개, Bottom Navigation |
| `Frame 68` | `114:5143` | Monthly Report | `375 × 812` | 현재 월과 이전 월의 소비 흐름 및 인사이트 | Header, 비교 일별 차트, 인사이트 3개, 비교 안내, Bottom Navigation |
| `Frame 118` | `431:6676` | Monthly Total Insight Detail | `375 × 812` | 월 총지출 비교 상세 | 요약 인사이트, 월별 막대 차트, 비교 수치, 설명 카드, Bottom Navigation |
| `Frame 157` | `431:7759` | Weekly Insight Detail | `375 × 812` | 주차별 지출 비교 상세 | 요약 인사이트, 주차별 차트, 주차별 수치, 설명 카드, Bottom Navigation |
| `Frame 66` | `114:5192` | Category Report / collapsed | `375 × 812` | 카테고리별 지출 목록의 접힘 상태 | Header, 월 선택, 도넛 차트, 예산 진행률 목록, Bottom Navigation |
| `Frame 117` | `397:5357` | Category Report / food expanded | `375 × 812` | 식비 카테고리 상세가 펼쳐진 상태 | 카테고리 요약, 식비 지표, 거래 내역 보기, 다음 카테고리 목록, Bottom Navigation |
| `Frame 158` | `470:9780` | Transaction List | `375 × 812` | 선택 월/카테고리의 거래 목록 | Header, 카테고리 필터 chip, 월별 합계, 날짜 timeline, transaction rows |
| `Frame 115` | `470:9711` | Transaction Detail | `375 × 812` | 단일 거래 조회/편집/삭제 | Header, 가맹점/금액/카테고리, 유형·날짜·카테고리·소비 평가·메모 rows, 삭제 버튼 |
| `home 상세2` | `397:6017` | Month Selector Overlay | `346 × 156` | 1월부터 12월까지 월 선택 | 4열 × 3행 월 항목 |

`Frame 117`과 `Frame 118`은 사용자가 처음 제공한 주요 Frame 목록에는 없었지만, Prototype destination으로 직접 연결되어 있어 명세 범위에 포함한다.

**(확정, 구현 상태)** `Frame 118`(Monthly Total Insight Detail)과 `Frame 157`(Weekly Insight Detail)은 각각 `MonthlyTotalComparisonDetailScreen`, `WeeklyComparisonDetailScreen`으로 별도 구현되어 있으며, Monthly Report(`Frame 68`)의 해당 insight row를 탭하면 push되고 back으로 Monthly Report로 복귀한다. 세 번째 insight("~증가 영향이 컸어요")는 Category Report(`Frame 66`/`Frame 117`)로 push되며 대상 category가 expanded 상태로 진입한다.

## A.2 공통 visual foundation

### 색상

| 용도 | Figma 값 |
| --- | --- |
| 기본 화면 배경 | `#F7F7F7` |
| 기본 카드 배경 | `#FCFCFC` 또는 `#FFFFFF` |
| 주 텍스트 | `#2F2F2F` |
| 보조/비활성 텍스트 | `#A0AFA4`, 일부 설명 `#8F8E8E` |
| Primary green | `#00AE76` |
| Dark green | `#007C4F`, `#004725` |
| Light green surface | `#EFF8F2`, `#D6F3E8` |
| Expense/caution coral | `#EF6C4C` |
| Category blue | `#42B7FD` |
| Category orange | `#FFB702` |
| Category lime | `#BDD527` |
| Card border | `#DADADA`, `#E0E0E0`, 또는 `#E4E4E4` |
| Header gradient | `#6DD9AB → #00AF76` |

### Typography

- 기본 font family: `Wanted Sans`
- 공통 letter spacing: `-0.45px`
- 기본 line height: font size의 약 `130%`
- 화면 title: `20px / Bold`
- Transaction Detail의 가맹점명: `20px / SemiBold`
- Transaction Detail의 대표 금액: `32px / SemiBold`, `#EF6C4C`
- Section heading: `16px / SemiBold`
- Body/label: `16px / Regular`
- 강조 수치: `16px / SemiBold` 또는 `Bold`
- 축/보조 정보: `10px` 또는 `12px`
- Bottom Navigation label: `16px / SemiBold`; 선택 `#007C4F`, 비선택 `#A0AFA4`

Figma 텍스트 중 `400,000원` 등 일부 금액은 letter spacing `-0.95px`를 사용한다. 구현에서 자간 차이가 눈에 띄는 금액 영역은 해당 값을 우선한다.

### Card와 navigation shell

- 기본 카드 radius: `6px`
- 기본 카드 shadow: `0 1px 2px rgba(0, 0, 0, 0.05)`
- Bottom Navigation: `347 × 66`, 좌우 margin `14px`, radius `16px`, border `1px #E0E0E0`
- Bottom Navigation은 Figma에서 상단 방향 green-tinted shadow와 background blur를 사용한다.
- Header의 back/bell icon 크기: `24 × 24`

## A.3 화면별 정적 구조와 수치

### A.3.1 Report Main — `Frame 69` (`362:3635`)

Component hierarchy:

```text
Frame 69
├─ Status bar
├─ Header gradient
│  ├─ Greeting/summary copy
│  ├─ Current/previous month totals
│  └─ Notification icon
├─ Month selector (Frame 182)
├─ Daily spending card
├─ Category spending card
├─ Monthly insight summary card
│  └─ Insight rows × 3
└─ Bottom Navigation
```

주요 geometry:

| 요소 | Node ID | Bounds `(x, y, w, h)` | 주요 스타일 |
| --- | --- | --- | --- |
| 월 선택 영역 | `470:9473` | `(15, 195, 346, 34)` | padding `8/12`, radius `6`, fill `#4ACB9A`, white border, shadow |
| 일별 소비 카드/hotspot | `378:5050` | `(15, 241, 346, 238)` | `#FCFCFC`, radius `6`, 기본 shadow |
| 카테고리 지출 카드/hotspot | `378:5046` | `(15, 491, 346, 229)` | `#FCFCFC`, radius `6`, 기본 shadow |
| 인사이트 카드 | `378:5051` | `(15, 732, 346, 347)` | `#FCFCFC`, radius `6`, 기본 shadow |
| 긍정 인사이트 첫 행/hotspot | `431:7284` | `(24, 796, 327, 42)` | `#EFF8F2`, radius `6` |
| 두 번째 인사이트 행 | `431:7283` | `(24, 846, 327, 42)` | `#FFF3EC`, radius `6` |
| 세 번째 인사이트 행 | `431:7282` | `(24, 896, 327, 42)` | `#FFF3EC`, radius `6` |
| Bottom Navigation | `378:5105` | `(14, 1019, 347, 66)` | 공통 shell 스타일 |

Figma sample content는 `이번 달 지출은 523,000원`, `지난 달 보다 8% 적게`, 최고 지출일 `8월 17일 / 10,000원`, 카테고리 합계 `800,000원`이다. 이는 화면 구조를 설명하기 위한 design data이며 production 고정값이 아니다.

### A.3.2 Monthly Report — `Frame 68` (`114:5143`)

```text
Frame 68
├─ Status/Header (`월간 리포트`, back, notification)
├─ Daily comparison chart card
│  ├─ Previous/current month selector label
│  ├─ Two line series
│  └─ Selected day tooltip
├─ Insight rows × 3
├─ Comparison guide
└─ Bottom Navigation
```

| 요소 | Node ID | Bounds | 주요 스타일 |
| --- | --- | --- | --- |
| 차트 카드 | `114:5146` | `(14, 119, 347, 241)` | `#FCFCFC`, radius `6`, 기본 shadow |
| 첫 번째 인사이트 row | `431:6649` | `(14, 372, 347, 42)` | `#EFF8F2`, radius `6` |
| 두 번째 인사이트 row/hotspot | `431:6648` | `(14, 422, 347, 42)` | `#FCFCFC`, radius `6` |
| 세 번째 인사이트 row | `431:6647` | `(14, 472, 347, 42)` | `#FCFCFC`, radius `6` |
| 비교 안내 | `431:6643` | `(33, 604, 310, 65)` | 제목과 설명 text |
| Bottom Navigation | `114:5191` | `(14, 713, 347, 66)` | 공통 shell 스타일 |

진행 중인 월 비교 안내 문구는 `현재 진행 중인 월은 동일 일자(1일~17일) 기준으로 지난달과 비교합니다.`로 배치되어 있다.

### A.3.3 Monthly Total Insight Detail — `Frame 118` (`431:6676`)

```text
Frame 118
├─ Header
├─ Selected insight summary row
├─ Monthly total bar chart card
├─ Metric card
│  ├─ Previous month total
│  ├─ Current month total
│  ├─ Difference
│  └─ Change rate
├─ Insight explanation card
└─ Bottom Navigation
```

| 요소 | Bounds | 스타일 |
| --- | --- | --- |
| 선택 인사이트 | `(14, 117, 347, 42)` | `#EFF8F2`, radius `6` |
| 월별 총지출 차트 | `(14, 168, 347, 241)` | `#FCFCFC`, radius `6` |
| 비교 지표 카드 | `(14, 421, 347, 159)` | `#FCFCFC`, radius `6` |
| 설명 카드 | `(14, 592, 347, 97)` | `#EFF8F2`, radius `6` |

### A.3.4 Weekly Insight Detail — `Frame 157` (`431:7759`)

```text
Frame 157
├─ Header
├─ Selected weekly insight row
├─ Week-by-week comparison chart
├─ Week-by-week value table
├─ Insight explanation card
└─ Bottom Navigation
```

| 요소 | Bounds | 스타일 |
| --- | --- | --- |
| 선택 인사이트 | `(14, 117, 347, 42)` | `#EFF8F2`, radius `6` |
| 주차별 차트 | `(14, 168, 347, 257)` | `#FCFCFC`, radius `6` |
| 주차별 값 카드 | `(14, 437, 347, 210)` | `#FCFCFC`, radius `6` |
| 설명 카드 | `(14, 659, 347, 97)` | `#EFF8F2`, radius `6` |

Figma는 1~4주차를 표시하며 각 주차의 이전 월/현재 월 값을 나란히 비교한다.

### A.3.5 Category Report collapsed — `Frame 66` (`114:5192`)

```text
Frame 66
├─ Header
├─ Category summary card
│  ├─ Month selector
│  ├─ Donut chart and total
│  └─ Category legend/percentages
├─ Category budget rows
│  ├─ 식비
│  ├─ 교통비
│  ├─ 식비 (별도 category row로 Figma에 존재)
│  ├─ 통신비
│  └─ 문화생활비
└─ Bottom Navigation
```

| 요소 | Node ID | Bounds | 스타일 |
| --- | --- | --- | --- |
| Category summary card | `397:5756` | `(15, 119, 346, 238)` | `#FFFFFF`, radius `6` |
| Category list container | `397:5636` | `(15, 119, 346, 608)` | content group |
| 식비 row | `397:5672` | `(15, 369, 346, 56)` | `#FCFCFC`, radius `6` |
| 식비 interactive header | `397:5677` | `(27, 378, 321, 38)` | collapsed state trigger |
| 이후 category rows | `397:5673`~`397:5676` | 각 `346 × 56`, 세로 `66px` 간격 | `#FCFCFC`, radius `6` |

각 row는 category name, spent amount, budget amount, chevron, progress bar를 가진다. 초과 상태에는 `초과` badge와 coral accent가 나타난다.

### A.3.6 Category Report expanded — `Frame 117` (`397:5357`)

```text
Frame 117
├─ Header
├─ Category summary card
├─ Expanded 식비 card
│  ├─ Category header and progress
│  ├─ 금액
│  ├─ 비율
│  ├─ 지난달 비교
│  ├─ 거래 건수
│  ├─ 예산 사용률
│  └─ 거래 내역 보기 button
├─ Remaining category rows
└─ Bottom Navigation
```

| 요소 | Node ID | Bounds | 스타일 |
| --- | --- | --- | --- |
| Expanded card | `397:5797` | `(15, 363, 346, 319)` | `#FCFCFC`, radius `6` |
| Expanded header trigger | `397:5854` | `(32, 377, 316, 39)` | expanded state trigger |
| 거래 내역 보기 | `397:5592` | `(30, 628, 315, 43)` | `#FCFCFC`, border `#DADADA`, radius `6` |
| 다음 category row | `397:5904` | `(15, 694, 346, 56)` | `#FCFCFC`, radius `6` |

Figma sample expanded metrics는 금액 `261,500원`, 비율 `50%`, 지난달 `235,000원 (-11%)`, 거래 건수 `28건`, 예산 사용률 `87% (300,000원 중)`이다.

### A.3.7 Transaction List — `Frame 158` (`470:9780`)

```text
Frame 158
├─ Header (`최근 거래내역 전체`, back, notification)
├─ Horizontal category filter chips
├─ Month summary
├─ Date timeline
└─ Transaction rows
   ├─ Merchant icon/logo
   ├─ Merchant, time, amount
   ├─ Category/subcategory chip
   └─ Chevron
```

| 요소 | Node ID | Bounds | 비고 |
| --- | --- | --- | --- |
| Filter chip strip | `470:9933` | `(0, 137, 375, 39)` | `전체`, `식비`, `교통`, `생활` 등 |
| 첫 transaction row | `470:9813` | `(62, 216, 299, 74)` | 스타벅스, 17:00, -13,000원 |
| 다음 rows | `470:9829`, `470:9845` | 각각 `(62, 296, 299, 74)`, `(62, 376, 299, 74)` | 동일 구조 |
| 다음 날짜 그룹 rows | `470:9861`, `470:9877`, `470:9893`, `470:9909` | `299 × 74` | 목록이 viewport 아래까지 이어짐 |

Merchant는 `16px / SemiBold`, expense amount는 `16px / SemiBold / #EF6C4C`, category chip text는 `12px / Regular`이다.

### A.3.8 Transaction Detail — `Frame 115` (`470:9711`)

```text
Frame 115
├─ Header (`거래 상세`, back, notification)
├─ Merchant identity
│  ├─ Logo
│  ├─ Merchant name
│  ├─ Amount
│  └─ Category/subcategory chip
├─ Editable-looking rows
│  ├─ 거래 유형
│  ├─ 날짜
│  ├─ 카테고리
│  ├─ 소비 평가
│  └─ 메모
└─ 거래 삭제 button
```

| 요소 | Node ID | Bounds | 스타일 |
| --- | --- | --- | --- |
| 거래 유형 row | `470:9738` | `(14, 371, 347, 56)` | `#FCFCFC`, radius `6` |
| 날짜 row | `470:9739` | `(14, 433, 347, 56)` | 동일 |
| 카테고리 row | `470:9740` | `(14, 495, 347, 56)` | 동일 |
| 소비 평가 row | `470:9741` | `(14, 557, 347, 56)` | 동일 |
| 메모 row | `470:9742` | `(14, 619, 347, 56)` | 동일 |
| 거래 삭제 | `470:9778` | `(14, 695, 347, 55)` | border `#E1D7D5`, radius `16`, coral label |

대표 금액은 `32px / SemiBold / #EF6C4C`, row label은 `16px / Regular`, row value는 `16px / SemiBold`이다.

### A.3.9 Month Selector Overlay — `home 상세2` (`397:6017`)

- 크기: `346 × 156`
- 구성: 4열 × 3행, `1월`~`12월`
- visible month item 크기: 폭 `71~73px`, 높이 `34px`
- 기본형: `#FFFFFF`, border `#E4E4E4`, radius `6`, text `16px / Regular / #2F2F2F`
- Prototype target의 선택형 visual: fill `#D6F3E8`, border `#00AE76`, text `#007C4F`, radius `6`
- Overlay background: black `25%`
- Overlay position: `MANUAL`, trigger 바로 아래 `x≈0, y=34`

---

# B. Prototype에서 직접 확인된 interaction

## B.1 원본 Prototype flow

```text
Frame 69 (362:3635)
├─ 월 선택 → home 상세2 overlay (397:6017)
├─ 일별 소비 카드 → Frame 68 (114:5143)
├─ 첫 번째 요약 insight → Frame 68 (114:5143)
└─ 카테고리 지출 카드 → Frame 66 (114:5192)

Frame 68 (114:5143)
├─ 첫 insight → Frame 118 (431:6676)
├─ 두 번째 insight → Frame 157 (431:7759)
└─ 세 번째 insight → interaction 없음

Frame 66 (114:5192)
└─ 식비 row → Frame 117 (397:5357)

Frame 117 (397:5357)
├─ 식비 row → Frame 66 (114:5192)
└─ 거래 내역 보기 → Frame 158 (470:9780)

Frame 158 (470:9780)
└─ 첫 스타벅스 row → Frame 115 (470:9711)
```

## B.2 Interaction table

| 현재 화면 | Source | Source node ID | Trigger | Figma action | Destination | Transition/options |
| --- | --- | --- | --- | --- | --- | --- |
| Frame 69 | `8월` selector | `470:9473` | `ON_CLICK` | `OVERLAY` | `397:6017` | transition 없음, relative `(≈0, 34)` |
| Frame 69 | 일별 소비 카드 전체 | `378:5050` | `ON_CLICK` | `NAVIGATE` | `114:5143` | transition 없음 |
| Frame 69 | `저번보다 8% 적게 썼어요` | `431:7284` | `ON_CLICK` | `NAVIGATE` | `114:5143` | transition 없음 |
| Frame 69 | 카테고리 지출 카드 전체 | `378:5046` | `ON_CLICK` | `NAVIGATE` | `114:5192` | transition 없음 |
| Frame 68 | `지난달보다 8% 적게 썼어요` | `431:6880` | `ON_CLICK` | `NAVIGATE` | `431:6676` | transition 없음 |
| Frame 68 | `3주차 지출이 가장 컸어요` | `431:6648` | `ON_CLICK` | `NAVIGATE` | `431:7759` | transition 없음 |
| Frame 66 | collapsed 식비 row | `397:5677` | `ON_CLICK` | `NAVIGATE` | `397:5357` | `SMART_ANIMATE`, `EASE_OUT`, `0.3s` |
| Frame 117 | expanded 식비 row | `397:5854` | `ON_CLICK` | `NAVIGATE` | `114:5192` | `SMART_ANIMATE`, `EASE_OUT`, `0.3s` |
| Frame 117 | 거래 내역 보기 | `397:5592` | `ON_CLICK` | `NAVIGATE` | `470:9780` | transition 없음 |
| Frame 158 | 첫 스타벅스 transaction | `470:9813` | `ON_CLICK` | `NAVIGATE` | `470:9711` | transition 없음 |

Overlay 밖을 누르면 `overlayBackgroundInteraction=CLOSE_ON_CLICK_OUTSIDE`에 의해 닫힌다. 별도의 Close 버튼은 없다.

## B.3 Figma interactive component state

월 항목 Instance는 `FINAL_HOME_SCREENS`의 category component reaction을 상속한다.

| Overlay instances | 표시 월 | `CHANGE_TO` destination |
| --- | --- | --- |
| `397:6107`, `397:6108`, `397:6109` | 1월, 5월, 9월 | `335:7566` |
| `397:6110`, `397:6111`, `397:6112` | 2월, 6월, 10월 | `335:7572` |
| `397:6113`, `397:6114`, `397:6115` | 3월, 7월, 11월 | `335:7578` |
| `397:6116`, `397:6117`, `397:6118` | 4월, 8월, 12월 | `335:7584` |

각 target에는 다음 역방향 reaction이 존재한다.

| Target | 역방향 destination |
| --- | --- |
| `335:7566` | `335:7536` |
| `335:7572` | `335:7542` |
| `335:7578` | `335:7548` |
| `335:7584` | `335:7554` |

이 구성은 월 전용 상태가 아니라 category component를 재사용한 Figma artifact다. 실제 제품 동작은 C.2 규칙을 따른다.

## B.4 Prototype에서 정의되지 않은 동작

- Header의 back icon에는 `BACK` reaction이 없다.
- Bottom Navigation과 notification icon에는 reaction이 없다.
- `SCROLL_TO`, drag, hover, after-delay reaction은 없다.
- Frame 68의 세 번째 insight에는 reaction이 없다.
- Transaction List에서는 첫 스타벅스 row 외의 row에 reaction이 없다.
- Transaction Detail의 field rows와 삭제 버튼에는 실행 가능한 reaction이 없다.
- Frame 118, Frame 157, Frame 115는 Prototype상 terminal이다.

---

# C. 사용자와 추가로 확정한 제품 규칙

이 절은 실제 구현 시 B의 미연결 또는 artifact 상태를 보완하거나 대체하는 규범적 요구사항이다.

## C.1 Back navigation

- 모든 상세 화면의 back은 navigation history의 **이전 route**로 돌아간다.
- Report Main으로 강제 이동하지 않는다.
- 상세 화면에는 Monthly Report, insight detail, Category Report, Transaction List, Transaction Detail이 포함된다.

## C.2 Month selection

- 상태 이름: `selectedMonth`
- 한 번에 하나의 월만 선택할 수 있다.
- 월 항목을 탭하면 `selectedMonth`를 해당 월로 변경한다.
- 선택 직후 Month Selector Overlay를 닫는다.
- Report Main과 현재 Report flow에서 소비되는 데이터를 새 월 기준으로 refresh한다.
- 월 이름은 선택 전후 모두 `1월`, `2월` 형식을 유지한다.
- 실제 앱에서는 월 selector 전용 component를 사용한다.
- Figma artifact의 독립 다중 `Change to` 동작은 구현하지 않는다.
- **(확정)** 앱/화면 최초 진입 시 `selectedMonth`는 항상 현재 월로 시작한다. 마지막으로 선택했던 월을 기기/세션에 영구 저장해 복원하지 않는다 (기존 E.6 미정 항목 해소).
- **(확정)** Month Picker는 1월~12월 그리드에 더해 연도 이전/다음 이동(◀ / ▶)을 함께 제공한다. 이는 Figma 원본 오버레이(1~12월 고정)보다 기능적으로 확장된 제품 규칙으로, 과거/미래 연도 조회를 지원하기 위해 의도적으로 도입한 것이다 (기존 E.11 미정 항목 해소).

권장 상태 전이는 다음과 같다.

```text
Overlay closed
  → current month selector tap
Overlay open
  → month tap
selectedMonth updated
  → overlay close
  → report data refresh
```

## C.3 Insight navigation

- 총지출 비교 insight는 Monthly Total Insight Detail로 이동한다.
- 주차 비교 insight는 Weekly Insight Detail로 이동한다.
- `식비 증가 영향이 컸어요`와 같은 category 영향 insight는 Category Report로 이동한다.
- Category 영향 insight에는 대상 `categoryId`를 함께 전달한다.
- Category Report는 가능하면 대상 category가 expanded/selected된 상태로 진입한다.
- **(확정)** Monthly Total Insight Detail(Frame 118)과 Weekly Insight Detail(Frame 157)은 동일 화면 내 아코디언이 아니라 **별도의 navigable screen/route**로 구현한다 (`MonthlyTotalComparisonDetailScreen`, `WeeklyComparisonDetailScreen`). 사용자는 Monthly Report → insight tap → Detail Screen → back → Monthly Report 흐름을 그대로 경험해야 한다.
- **(확정)** category 영향 insight는 `categoryId`가 아직 Backend에 없으므로(D.2 참고), 기존 "거래 내역 보기" 버튼과 동일한 name → id 역조회 패턴을 재사용해 category **name**으로 Category Report에 전달한다. Backend에 임의의 fake `categoryId`를 만들지 않는다.

## C.4 Category expand/collapse

- Category row는 동일 화면 안의 expanded/collapsed UX로 취급한다.
- 시각적 전환은 약 `300ms ease-out`으로 구현한다 (Flutter `AnimatedSize` + `Curves.easeOut`, `Duration(milliseconds: 300)`).
- 그 외 custom animation은 만들지 않는다.
- **(확정)** 한 번에 하나의 category만 expanded 상태가 된다. 다른 category를 펼치면 이전에 펼쳐져 있던 category는 자동으로 접힌다 (기존 E.7 미정 항목 해소).

## C.5 Transaction List

- 모든 transaction row가 클릭 가능하다.
- 각 row는 자신의 `transactionId`를 사용해 Transaction Detail로 이동한다.
- 목록 row의 merchant, amount, date/time, category 표시값은 해당 transaction 데이터에서 가져온다.
- **(확정)** Transaction List는 두 가지 진입 방식을 모두 지원한다.
  - Home의 "실시간 거래 내역 → 더보기": `initialMonth == null`. Report의 selectedMonth와 무관하게 전체 기간의 최근 거래를 페이지네이션으로 보여준다.
  - Report/Category Report의 "거래 내역 보기": 현재 선택된 Report month를 `initialMonth`로 전달받아, 그 달의 `startDate`~`endDate` 범위로 `GET /api/transactions`를 호출한다(기존 API 파라미터 재사용, 새 endpoint 없음).
- **(확정)** Category filter chip은 single-select이며 "전체" 선택 시 category filter는 `null`이 된다 (기존 E.8 미정 항목 해소).
- **(확정)** Pagination은 infinite scroll 방식을 유지한다 (기존 E.9 미정 항목 해소).

## C.6 Transaction Detail editing

- `거래 유형`, `날짜`, `카테고리`, `메모`는 편집 가능하다.
- 각 row를 탭하면 해당 field의 편집 UI를 연다.
- 확인하면 기존 transaction update API로 저장한다.
- `소비 평가`는 Backend field가 생기기 전까지 `기록 없음/준비 중` 상태로 표시하고 저장하지 않는다.
- **(확정)** `amount`(금액)도 편집 가능하다 (기존 D.5 "미정" 해소). Backend `PATCH /api/transactions/:id`가 이미 `categoryId`/`type`/`occurredAt`/`merchantOrTitle`/`memo`/`amount`를 모두 지원하므로(`transactionPatchSchema`), Frontend는 지원되는 필드를 임의로 잠그지 않는다.
- **(확정)** `merchantOrTitle`(거래명)은 이번 범위에서 편집 가능 필드로 승격하지 않고 기존 동작(읽기 전용 표시)을 유지한다. 명확한 편집 요구가 생기면 별도로 재검토한다.
- **(확정)** Field editor presentation: 필드마다 별도 editor 화면을 만들지 않는다. 모든 row는 기존 공용 Transaction edit 화면(`AddTransactionModal`, 실제로는 전체 화면 route)을 재사용하며, edit 모드에서는 사용자가 탭한 필드가 실제로 편집 가능한 상태여야 한다 (기존 E.2 미정 항목 해소).
- **(확정)** Transaction update 완료 후에는 편집 화면을 닫고 이전 화면(Transaction Detail)으로 복귀한다. Detail은 관련 provider invalidation을 통해 즉시 최신값을 반영하며, Transaction List까지 거슬러 올라가는 refresh는 C.7의 refresh 규칙을 따른다 (기존 E.13 미정 항목 해소).

## C.7 Transaction deletion

```text
거래 삭제 탭
→ Confirm Dialog
→ 확인
→ 기존 DELETE API 호출
→ 성공
→ 이전 화면으로 복귀
→ transaction/report/calendar/home 관련 데이터 refresh
```

- API 성공 전에 이전 화면으로 복귀하지 않는다.
- 실패 상태의 구체적인 메시지와 retry UX는 E에 남긴다.
- **(확정)** 현재 Confirm Dialog UX(기본 `AlertDialog`, 제목 "내역 삭제", 본문 "이 내역을 삭제할까요?", "취소"/"삭제" 버튼)를 최종 구현으로 유지한다 (기존 E.3 미정 항목 해소).
- **(확정)** 삭제 성공 시 refresh 대상에 **Transaction List**를 명시적으로 포함한다: Report/Home/Calendar는 기존 `invalidateTransactionDependents` 공용 구조로 refresh하고, Transaction List는 자체 로컬 페이지네이션 상태를 쓰므로 Transaction Detail에서 돌아올 때 현재 filter/month 조건으로 다시 fetch해 갱신한다.

## C.8 Bottom Navigation

- 앱의 실제 공통 navigation shell을 사용한다.
- 탭은 `홈 / 캘린더 / 리포트 / 뉴스 / 마이` 5개다.
- Report flow에서는 리포트 탭이 active다.
- 현재 탭을 다시 누를 때의 별도 동작은 없다.
- content가 스크롤되어도 Bottom Navigation은 shell에 고정한다.
- Prototype의 미연결 상태보다 실제 공통 shell 동작을 우선한다. Figma Prototype에는 Bottom Navigation 관련 interaction이 정의되어 있지 않지만, 실제 앱은 그와 무관하게 아래 공통 shell navigation 정책을 따른다.

### C.8.1 일반 탐색 화면 vs 집중 작업 화면 (확정)

- 다음은 **일반 탐색 화면**으로 취급하며, 어느 탭에서 진입하더라도 `StatefulShellRoute` branch-local `Navigator`(`Navigator.of(context).push(...)`, `rootNavigator` 지정 없음)로 push해 공통 Bottom Navigation이 계속 보이게 한다.
  - `TransactionListScreen`
  - `TransactionDetailScreen`
  - `MonthlyReportScreen`
  - `MonthlyTotalComparisonDetailScreen`
  - `WeeklyComparisonDetailScreen`
  - `CategoryReportScreen`
  - 같은 화면(예: `TransactionListScreen`, `TransactionDetailScreen`)이 Home에서 들어왔는지 Report에서 들어왔는지에 따라 Bottom Navigation이 있다 없다 하는 비대칭은 허용하지 않는다.
- `AddTransactionModal`(거래 추가/수정)은 **집중 작업 화면**으로 예외 처리한다. `Navigator.of(context, rootNavigator: true)`로 push해 Bottom Navigation을 의도적으로 숨긴다. 그 내부의 `CategoryPickerScreen` 등 하위 선택 화면도 동일한 집중 작업 흐름의 일부로 간주해 같은 방식을 유지한다.
- 요약: 일반 탐색 → Bottom Nav 유지, 거래 추가/수정 → Bottom Nav 숨김.

## C.9 Notification

- notification destination은 새로 추측하지 않는다.
- 확정된 destination이 생기기 전까지 상태는 `미정`이다.

## C.10 Scrolling

- Report Main, Monthly Report, insight detail, Category Report, Transaction List, Transaction Detail은 content가 viewport를 넘으면 vertical scroll을 허용한다.
- Bottom Navigation은 scroll content 밖의 common shell에 고정한다.
- Transaction List는 모든 row에 접근할 수 있어야 한다.
- Category expand로 content 높이가 증가해도 하단 content가 잘리지 않아야 한다.

## C.11 Transition

- 일반 화면 이동은 앱의 기본 route transition을 사용한다.
- 별도 custom route animation은 없다.
- Category collapsed ↔ expanded만 약 `300ms ease-out`으로 부드럽게 전환한다.

---

# D. Backend가 필요한 data/action

이 절은 UI가 요구하는 논리 데이터와 action을 정의한다. 고정 sample 값이나 production fake 계산으로 대체하지 않는다.

## D.1 공통 query/state

| 데이터 | 필수 여부 | 용도 |
| --- | --- | --- |
| `selectedMonth` (`YYYY-MM`) | 필수 | 모든 Report query 기준 월 |
| `previousMonth` | 필수 | 전월 비교 |
| `comparisonRange` | 필수 | 진행 중인 월의 동일 일자 비교 |
| `isLoading` | 필수 | 최초 로드 및 월 변경 refresh |
| `error` | 필수 | 조회 실패 처리 |
| `lastUpdatedAt` | 선택 | refresh 완료 추적 |

## D.2 Report Main / Monthly Report

| UI | 필요한 데이터 |
| --- | --- |
| 월 selector | `selectedMonth`, 선택 가능한 월 범위 |
| 이번 달 총지출 | `currentMonthExpenseTotal` |
| 전월 비교 | `previousMonthExpenseTotal`, `differenceAmount`, `differenceRate` |
| 일별 차트 | `dailyExpenses[] { date, amount }` for current/previous month |
| 선택 day tooltip | `selectedDate`, `selectedDateAmount`, 비교 월 amount |
| category donut | `categories[] { categoryId, name, icon, color, amount, percentage, transactionCount }` |
| 요약 insight | `momPercent`, `topCategory`, `peakDate`, `peakAmount` |
| 주차 insight | `weeklyTotals[]`, `topWeekIndex` |
| category 영향 insight | `categoryId`, `categoryName`, `growthAmount`, `growthRate` |

현재 Backend 관련 문서에 따르면 `GET /api/reports/categories`는 category name 중심이며 stable `categoryId`가 없다. Category Report 진입과 transaction filtering을 위해 `categoryId` 제공이 필요하다.

## D.3 Category Report

| UI | 필요한 데이터 |
| --- | --- |
| donut/legend | `categoryId`, `name`, `icon`, `color`, `amount`, `percentage` |
| category row | `spentAmount`, `budgetAmount?`, `budgetUsageRate?`, `isOverBudget` |
| expanded metrics | `amount`, `percentage`, `previousMonthAmount`, `changeRate`, `transactionCount`, `budgetAmount?`, `budgetUsageRate?` |
| expanded state | `expandedCategoryId?` |
| 거래 내역 보기 | `selectedMonth`, `categoryId` |

`budgetAmount`가 없으면 사용률이나 초과액을 임의 계산하지 않는다. Backend 지원 전에는 nullable data에 대응하는 정직한 empty/unavailable 표현을 사용한다. 상세 Backend gap은 [report-backend-requirements.md](../backend/report-backend-requirements.md)를 참고한다.

## D.4 Transaction List

| UI | 필요한 데이터 |
| --- | --- |
| 월별 grouping | `month`, `monthlyExpenseTotal` |
| 날짜 timeline | `transactionDate`, weekday |
| row identity | `transactionId` |
| row content | `merchantName`, `merchantIcon/logo?`, `amount`, `type`, `occurredAt`, `categoryId`, `categoryName`, `subcategoryName?`, `categoryColor?` |
| category filter | `activeCategoryId?`, filter option list |
| pagination | cursor/page 정보가 필요할 수 있으나 방식은 미정 |

필수 action:

- 선택 월 기준 transaction list 조회
- category 영향 insight 또는 Category Report에서 진입한 경우 `categoryId` filter 적용
- row tap 시 `transactionId`로 Transaction Detail 조회/이동

## D.5 Transaction Detail

| Field | 읽기 | 수정 | 비고 |
| --- | --- | --- | --- |
| `transactionId` | 필수 | 불가 | route 및 API identity |
| `type` | 필수 | 가능 | 거래 유형 |
| `occurredAt` | 필수 | 가능 | 날짜/시간 |
| `categoryId` | 필수 | 가능 | category selector 필요 |
| `categoryName` / `subcategoryName?` | 필수 | category 변경 결과로 갱신 | 표시용 |
| `merchantName` | 필수 | **(확정) 불가** — 이번 범위에서는 기존 동작(읽기 전용) 유지 | 대표 정보 |
| `merchantIcon/logo?` | 선택 | 불가 | 없을 때 fallback 필요 |
| `amount` | 필수 | **(확정) 가능** — Backend가 이미 지원(`transactionPatchSchema`) | Figma에는 표시되며 이번 세션에서 편집 가능으로 확정 |
| `memo?` | 선택 | 가능 | null/empty 허용 |
| `spendingEvaluation?` | Backend 추가 전 null | 저장하지 않음 | `기록 없음/준비 중` |

필수 action:

- Transaction Detail 조회
- 기존 transaction update API를 통한 `type`, `occurredAt`, `categoryId`, `memo` update
- 기존 transaction DELETE API 호출
- update 성공 응답을 현재 Transaction Detail에 반영
- delete 성공 후 관련 cache/provider invalidation

## D.6 Refresh/invalidation 규칙

| Trigger | 반드시 refresh/invalidate할 데이터 |
| --- | --- |
| `selectedMonth` 변경 | Report Main, Monthly Report, insight detail, Category Report, Transaction List |
| transaction delete 성공 | 해당 transaction detail 제거, 이전 transaction list, report summary/daily/category/insight, Calendar, Home |

Transaction update 성공 후의 화면 이동과 cross-screen refresh 범위는 아직 미정이다. update/delete API 실패 시 성공 상태를 UI에 반영하거나 관련 cache를 제거하면 안 된다.

---

# E. 아직 미정인 항목

다음 항목은 Figma Prototype과 현재 제품 결정만으로 구체적인 UX를 확정할 수 없다.

> Spec Reconciliation Audit 이후 진행된 제품 규칙 확정 세션에서 과거 2, 3, 6, 7, 8, 9, 10, 11, 13번 항목이 확정되어 C/D 절로 이동했다 (각 항목에 "(확정)" 표시와 함께 반영됨). 아래는 그 시점 이후에도 여전히 열려 있는 항목만 남긴 것이다.

1. **Notification destination**: 알림 아이콘의 목적 화면과 활성 조건.
2. **조회/저장/삭제 오류 상태**: 사용자 메시지, retry 방식, offline 처리.
3. **Loading/empty state 디자인**: Report 데이터 없음, category 없음, transaction 없음, logo 없음 상태의 정확한 화면.
4. **Refresh 표시 방식**: 월 변경이나 transaction mutation 후 skeleton, spinner, 기존 데이터 유지 중 어떤 표시를 사용할지. (현재는 전체 화면을 `CircularProgressIndicator`로 교체하는 단순한 방식만 적용되어 있으며, 이것이 최종 디자인으로 확정된 것은 아니다.)

미정 항목은 임의로 interaction이나 Backend 동작을 추가하지 않는다. 구현이 필요해지는 시점에 제품 결정을 이 문서에 먼저 반영한다.

---

## 검수 체크리스트

- 모든 화면이 위 Frame/node ID와 대응되는지 확인한다.
- 일반 화면 이동은 기본 route transition을 사용한다.
- 모든 back action이 실제 이전 route로 복귀하는지 확인한다.
- 월 선택은 단일 선택이며 선택 즉시 Overlay가 닫히고 데이터가 갱신되는지 확인한다.
- category 영향 insight가 올바른 `categoryId`로 Category Report를 여는지 확인한다.
- 모든 transaction row가 자신의 `transactionId`로 상세 화면을 여는지 확인한다.
- `type`, `occurredAt`, `categoryId`, `memo` 변경이 기존 update API에 저장되고 성공 응답이 현재 Detail에 반영되는지 확인한다.
- 소비 평가는 Backend field 추가 전 저장되지 않는지 확인한다.
- 삭제는 confirm → API 성공 → 이전 route 복귀 → 관련 데이터 refresh 순서를 지키는지 확인한다.
- content만 세로 스크롤되고 Bottom Navigation은 common shell에 고정되는지 확인한다.
- category expand/collapse만 약 `300ms ease-out`을 사용하는지 확인한다.
- notification과 E 절의 미정 항목을 임의 구현하지 않았는지 확인한다.
