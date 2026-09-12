# Calendar 날짜별 사용 가능 금액 / 소비율 API 요구사항

작성 배경: Calendar 화면(Figma `FINAL_CALENDAR_SCREENS` / Frame 25, node 114:5459)의 날짜 cell에 "그 날짜에 실제로 얼마를 썼는가"를 백분율로 보여주는 기능을 추가하려 합니다. Frontend는 UI와 데이터 연결 지점까지 준비를 마쳤고, 실제 계산은 이 문서의 요구사항대로 backend에서 구현해 주셔야 합니다. Frontend 코드나 Figma 전체를 다시 볼 필요 없이 이 문서만으로 구현할 수 있도록 작성했습니다.

## A. 기능 목적

Calendar에서 각 날짜별로 다음을 percentage로 보여줍니다.

> "그 날짜에 사용할 수 있었던 금액 중 실제로 얼마를 소비했는가"

예: 해당 날짜 사용 가능 금액 50,000원, 해당 날짜 실제 지출 35,000원 → `spendingRatio = 70`.

## B. 현재 Home 계산과의 일관성

Calendar가 별도의 "사용 가능 금액" 공식을 새로 만들면 안 됩니다. 현재 Home(`/api/home`)이 쓰는 `ReportService.context()` → `DailyBudgetService.calculate()`의 계산 규칙을 그대로 source of truth로 재사용해야 합니다. 코드 분석으로 확인한 현재 규칙(`src/services/dailyBudgetService.ts`):

```
flexibleBudget          = 그 BudgetCycle 생성 시점에 스냅샷된 FLEXIBLE 배분 금액 합
flexibleSpent           = 그 cycle 내 CONFIRMED/EXPENSE 이면서 category.purposeType === 'GENERAL'인 거래 합
nonFlexibleOverage      = LOCKED 카테고리(저축/투자) 지출이 그 배분 예산을 초과한 금액
reservedScheduledAmount = 기준일 ~ cycle 종료일 사이 dueDate이면서 status === 'SCHEDULED'인 FixedExpenseOccurrence.expectedAmount 합
remainingFlexibleAmount = flexibleBudget - flexibleSpent - nonFlexibleOverage - reservedScheduledAmount
remainingDays           = 기준일 ~ cycle 종료일까지 남은 일수 (최소 1)
recommendedAmount       = floor(remainingFlexibleAmount / remainingDays)
```

Calendar 날짜별 계산도 이 규칙을 "기준일 = 그 날짜"로 바꿔 그대로 적용해야 합니다.

## C. 날짜별 계산 기준

날짜 `d`에 대해:

1. `d`가 속한 `BudgetCycle`을 확인한다.
2. 그 `BudgetCycle`의 **생성 당시 스냅샷 예산**(`plannedFlexibleAmount` 등)을 사용한다 — 현재의 `UserFinanceSetting`이 아니다.
3. cycle 시작일부터 `d` **이전**까지의 지출을 반영한다 (아래 D 참고).
4. `d` 시점 이후 cycle 종료일까지 남아 있던 scheduled fixed expense를 반영한다.
5. `d` 기준 `remainingDays`(= `d` ~ cycle 종료일)를 계산한다.
6. `d`의 `dailyRecommendedAmount`를 계산한다.
7. 해당 날짜의 실제 expense를 집계한다.
8. `spendingRatio = dailyExpense / dailyRecommendedAmount * 100`을 계산한다. **100% 이상이어도 clamp하지 않는다.**

예: `dailyRecommendedAmount = 40,000`, `dailyExpense = 50,000` → `spendingRatio = 125`.

## D. 하루 지출 반영 시점 (확인 필요 사항)

`dailyRecommendedAmount`는 "그 날짜에 지출하기 **전**, 그날 아침 시점에 사용할 수 있었던 금액" 개념으로 계산하는 것을 기준으로 제안합니다. 즉 `d`의 `flexibleSpent`는 `occurredAt < d` 까지만 반영하고(`d` 당일 지출은 분모 계산에서 제외), 그 `recommendedBeforeDailyExpense`와 `d` 당일 실제 expense를 비교합니다.

**이 정의가 현재 Home의 "오늘" 계산(당일 지출도 이미 `flexibleSpent`에 포함된 상태에서 `remainingFlexibleAmount`를 구하는 방식)과 다를 수 있습니다.** Home과 완전히 동일한 규칙을 쓸지, Calendar만 "지출 전 시점" 기준으로 살짝 다르게 정의할지는 backend 담당자가 판단해 확인해 주세요. 두 정의가 다르면 아래 L의 "Home 오늘 값과 Calendar 오늘 값 일치" 기준에 영향을 줍니다.

## E. BudgetCycle 스냅샷 사용

과거 날짜 계산 시 **현재 `UserFinanceSetting` 값을 사용하지 않습니다.** 사용자가 그 이후 월급/배분 비율을 바꿨을 수 있기 때문입니다. 반드시 해당 cycle이 생성될 때 `BudgetCycleService.ensureCurrentCycle()`이 저장한 스냅샷(`BudgetCycle.plannedFlexibleAmount`, `plannedReservedAmount`, `salarySnapshot` 등, `src/services/budgetCycleService.ts` 참고)을 조회해서 사용해야 합니다.

## F. Fixed Expense 이력 한계

`FixedExpenseOccurrence`는 `timestamps: false`로 정의되어 있어(`src/models/index.ts`) SCHEDULED → PAID로 언제 바뀌었는지 기록이 없습니다. 즉 이미 결제 처리(matched)된 occurrence는 "그 과거 날짜 당시에도 이미 지출 확정 상태였는지"를 정확히 복원할 방법이 없습니다.

현재 구조에서 가능한 최선의 근사: `occurrence.matchedTransaction.occurredAt`을 "그 occurrence가 사실상 처리된 시점"의 대리 지표로 사용해, `d` 시점에 `matchedTransaction.occurredAt > d` 이면 "d 당시엔 아직 SCHEDULED였다"고 간주하는 방식입니다. 이는 추정이며 100% 정확하지 않을 수 있음을 명시해 주세요.

개선 제안(이번 요구사항과 DB migration을 무조건 묶을 필요는 없음): `FixedExpenseOccurrence`에 `paidAt` 또는 `statusChangedAt` 컬럼을 추가하면 이 문제가 근본적으로 해결됩니다. 여유가 될 때 별도 개선 티켓으로 진행해 주시면 좋겠습니다.

## G. 추가 수입(Additional Income) 미반영

코드 분석 결과 `INCOME` 타입 거래는 현재 `recommendedAmount` 계산 어디에도 포함되지 않습니다(가용 예산이 수입만큼 늘어나지 않음). Calendar에서 이 부분만 임의로 다르게(예: 그날 추가 수입을 가용금액에 더하기) 계산하지 않습니다. 이 정책 자체를 바꾸고 싶다면 Home과 Calendar에 동시 적용되는 별도 개선사항으로 분리해 주세요.

## H. 현재 `dailyReport()` 구현의 문제

`ReportService.dailyReport()`(현재 `/api/reports/daily`가 사용 중)는 요청 range의 **end 날짜 하나의 cycle 컨텍스트**만 계산해서, 그 range에 속한 **모든 날짜에 동일한 `dailyRecommended`를 적용**하고 있습니다(`dailyRecommended = floor(plannedFlexibleAmount / cycleDays)`, `src/services/reportService.ts` 32번째 줄 부근).

월급일이 매월 1일이 아닌 이상, Calendar가 조회하는 "달력 한 달"(1일~말일)은 대부분 두 개의 `BudgetCycle`에 걸칩니다. 따라서 이 필드를 그대로 쓰면 cycle 경계를 넘는 날짜들이 잘못된 cycle의 예산으로 계산됩니다. **각 날짜는 반드시 자기 자신이 속한 cycle을 사용해 개별 계산**해야 합니다.

## I. 요청 API — 신규 endpoint보다 기존 확장 우선

새 endpoint를 만들기보다 기존 `GET /api/reports/daily`의 응답을 확장하는 방향을 제안합니다. 현재 계약(`API_SPEC.md` 기준):

```json
{
  "success": true,
  "data": [
    { "date": "2026-08-16", "spent": 12000, "recommended": 30000, "difference": -18000 }
  ]
}
```

목표로 하는 응답 형태(개념 예시 — 실제 property 이름/nesting은 현재 backend convention에 맞춰 조정해 주세요):

```json
{
  "success": true,
  "data": [
    {
      "date": "2026-08-17",
      "spent": 35000,
      "recommended": 50000,
      "difference": -15000,
      "spendingRatio": 70
    }
  ]
}
```

- 기존 `spent`/`recommended`/`difference`는 그대로 유지합니다(하위 호환).
- `recommended`를 H에서 설명한 "자기 자신의 cycle" 기준으로 재계산하도록 고칩니다.
- `spendingRatio`를 새 필드로 추가합니다.

> **참고 (이번 요구사항과 별개의 기존 버그)**: 현재 `dailyReport()`가 반환하는 각 행에는 `income` 필드가 아예 없습니다(`spent`/`recommended`/`difference`만 존재). Frontend Calendar는 이 응답에서 `income`도 함께 읽고 있어서, Calendar의 "이번 달 +수입" 합계와 날짜 cell의 "+수입" 표시가 **현재 항상 0으로 나오고 있을 가능성이 높습니다.** 이번에 이 endpoint를 수정하는 김에 해당 날짜의 실제 `INCOME` 거래 합계를 `income` 필드로 함께 내려주시면 좋겠습니다. (이 문서의 핵심 요청은 아니지만, 같은 endpoint라 함께 알려드립니다.)

## J. Frontend가 기대하는 타입

| 필드 | 타입 | 단위 | nullable | 의미 |
|---|---|---|---|---|
| `recommended` (dailyRecommendedAmount) | integer | KRW | 예 — 계산 불가(예: BudgetCycle/salary setting 없음) 시 `null` | 그 날짜 기준 하루 사용 가능 금액. `0`은 "실제로 가용 예산이 0"이라는 뜻이며, `null`과는 다릅니다. |
| `spendingRatio` | number (소수 허용) | percent | 예 — `recommended`가 `null`이거나 `0`이어서 나눌 수 없을 때 `null` | `expense / recommended * 100`. 100 초과 허용, clamp 금지. 소수점은 backend에서 반올림해서 정수로 내려주는 것을 제안합니다(정수가 아니면 frontend가 반올림해서 표시). |

Frontend는 이미 두 필드를 **nullable**로 파싱하도록 준비되어 있습니다 (`lib/features/calendar/screens/calendar_screen.dart`의 `DailyReportEntry.recommendedAmount: int?`, `DailyReportEntry.spendingRatio: double?`). 필드가 응답에 아예 없거나 값이 없으면 자동으로 `null` 처리되어 Calendar가 percentage 영역을 그냥 숨기므로, 이 문서의 필드를 먼저 내려주지 않아도 기존 화면은 깨지지 않습니다.

## K. Edge Case

다음을 반드시 정의해 주세요.

- `dailyRecommendedAmount == 0`: `spendingRatio`를 어떻게 처리할지 (0으로 나누기 방지 — `null`을 권장)
- `expense == 0`: `spendingRatio = 0`으로 내려줄지, `null`로 내려줄지
- 해당 사용자에게 `BudgetCycle`이 아예 없음(과거에 온보딩 전 날짜 등): `recommended`/`spendingRatio` 모두 `null`
- `salary setting`이 없음: 위와 동일하게 `null` 처리, 500 에러 아님
- fixed expense 데이터 없음: `reservedScheduledAmount = 0`으로 계산 진행
- cycle 경계를 넘는 월간 조회: H 항목대로 날짜별로 각자 cycle 사용
- 과거 cycle의 snapshot이 DB에 없는 경우(cycle 생성 이전 날짜 등): `null` 처리하고 임의 추정하지 않음
- `remainingFlexibleAmount`가 음수인 경우: `recommended`는 0으로 clamp(현재 Home 로직과 동일하게 `Math.max(0, ...)`), 그러나 `spendingRatio`는 분모가 0이 되므로 `null`
- `spendingRatio > 100`: 정상 케이스, clamp하지 않고 그대로 반환
- 미래 날짜(아직 오지 않은 날짜) 조회: `expense`는 0(또는 실제 미리 등록된 예정 거래가 있다면 그 값), `recommended`는 그 날짜 기준으로 정상 계산해서 반환

## L. Acceptance Criteria

- 월급일이 25일인 사용자가 8월 Calendar를 조회하면, 8/1~8/24와 8/25~8/31이 각각 올바른(자기 자신의) `BudgetCycle`로 계산된 `recommended` 값을 반환한다.
- 오늘 날짜에 대해, 동일한 시점에 호출한 Home의 `today.recommendedAmount`와 Calendar의 오늘 날짜 `recommended`가 (D 항목에서 정의한 "지출 전/후 시점" 차이를 제외하면) 동일한 조건에서 동일한 값을 반환한다.
- `spendingRatio`가 `expense / recommended * 100`과 정확히 일치한다(반올림 규칙 포함).
- 100%를 초과하는 소비도 100으로 clamp되지 않고 그대로(예: 125) 반환된다.
- 기존 `/api/reports/daily`의 `spent`/`recommended`/`difference` 응답 필드와 하위 호환이 깨지지 않는다(기존 필드 제거/이름 변경 없음).
- `BudgetCycle`/설정이 없는 사용자·날짜에 대해 500 에러 대신 `recommended: null`, `spendingRatio: null`을 반환한다.

---

## 요약 (Backend 담당자 전달용)

**[요청 목적]**
Calendar 날짜별 소비율(spendingRatio) 표시

**[필요 데이터]**
- `recommended` (dailyRecommendedAmount, 날짜별로 자기 자신의 BudgetCycle 기준 재계산)
- `spendingRatio` (`expense / recommended * 100`, clamp 없음)

**[수정 우선 대상]**
- `ReportService.dailyReport()` (`src/services/reportService.ts`)
- `DailyBudgetService`의 계산 규칙 재사용 (`src/services/dailyBudgetService.ts`) — Calendar가 별도 공식을 만들지 않음
- 날짜별로 자기 자신이 속한 `BudgetCycle` 컨텍스트 사용 (현재는 range의 end 날짜 하나만 사용 중 — 버그)

**[주의사항]**
- 현재 `UserFinanceSetting` 값이 아니라 그 `BudgetCycle` 생성 시점 snapshot(`plannedFlexibleAmount` 등) 사용
- 한 달(달력 기준)에 여러 `BudgetCycle`이 걸쳐 있을 수 있음
- `spendingRatio`는 100% 초과 허용, clamp 금지
- `FixedExpenseOccurrence`는 상태 변경 이력이 없어(`timestamps: false`) 과거 시점의 SCHEDULED/PAID 상태를 100% 정확히 복원 불가 — 현재 구조로 가능한 최선(근사)만 적용, 필요시 `paidAt`/`statusChangedAt` 추가를 별도 개선사항으로 제안
- (덤) 현재 `dailyReport()` 응답에 `income` 필드가 아예 없어서 Calendar의 "+수입" 표시가 항상 0인 것으로 보이는 기존 버그 발견 — 같은 endpoint 수정 시 함께 확인 요망

**[Frontend 연결]**
Frontend는 이미 `recommendedAmount: int?`, `spendingRatio: double?`를 nullable로 파싱하도록 준비되어 있음 (`DailyReportEntry`, `lib/features/calendar/screens/calendar_screen.dart`). API가 이 필드들을 내려주기 시작하면 Calendar 날짜 cell의 percentage 영역이 코드 변경 없이 즉시 연결됨. 현재는 필드가 없으므로 percentage 영역이 자동으로 숨겨진 상태이며, `kDebugMode`에서만 Figma 검수용 샘플 값(60% / 85% / 125%)을 보여준다 (release 빌드에는 포함되지 않음, API 응답처럼 위장하지 않음).
