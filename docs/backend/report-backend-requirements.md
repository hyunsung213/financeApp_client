# Report / Transaction Backend Requirements

Source: FINAL_REPORT_SCREENS (Figma `F8IxMoDpZ2e8RCGFQLSHxr`, node 545:2982), compared against `financeApp_backend` (read-only audit, no backend files were modified while producing this document or the accompanying frontend work).

Format follows `docs/development-work-policy.md` §9. Every item below is a real gap found while wiring the Report/Transaction screens to the current backend — none of this was invented speculatively.

---

## 1. Category ↔ Budget mapping (per-category budget usage)

**현재 상태**: `Category` (`식비`, `카페`, `교통비`, …) and `BudgetAllocation`/`BudgetCycleAllocation` (`FOOD`, `TRANSPORT`, `HOUSING`, … via `allocationType`) are two separate, unrelated tables in `src/models/index.ts` — there is no foreign key or join table between them. `GET /api/reports/categories` (`reportService.categories()`) returns `{ category, amount, transactionCount, percentage }` with no budget/limit field at all.

**필요한 이유**: Figma's Category Report screen (frame 114:5192 / 397:5357) shows a spent/budget progress bar per category — e.g. "식비 400,000원 / 200,000원 (초과)" — and a per-category "예산 사용률" of "87% (300,000원 중)". Without a real budget number per category, this is currently rendered as an honest "예산이 아직 설정되지 않았어요" empty state (`BudgetUsageBar` in `lib/features/report/widgets/budget_usage_bar.dart`) rather than a fabricated percentage.

**관련 Backend Service/Model**: `src/models/index.ts` (`Category`, `BudgetAllocation`, `BudgetCycleAllocation`), `src/services/reportService.ts#categories()`, `src/services/budgetCycleService.ts`.

**Frontend 연결 위치**: `lib/features/report/widgets/budget_usage_bar.dart` (already built to full Figma fidelity, takes `budgetAmount` as nullable), consumed from `lib/features/report/screens/category_report_screen.dart`.

**권장 API contract**: Either (a) add an optional `allocationId` FK on `Category` so a category can declare which `BudgetAllocation` bucket it draws from, then have `GET /api/reports/categories` also return `budgetAmount` (that cycle's `BudgetCycleAllocation.amount` for the mapped allocation, split across mapped categories by usage or by an explicit per-category sub-limit), or (b) introduce a dedicated `CategoryBudget` table (`userId`, `categoryId`, `monthlyAmount`) the user sets directly, independent of the coarser `BudgetAllocation` buckets, and expose it via `/api/reports/categories` or a new `/api/finance/category-budgets` endpoint.

**Priority**: Medium (screen works and looks correct without it — this only unlocks the progress bar/badge from being real).

**Acceptance criteria**: `GET /api/reports/categories` (or a new endpoint) returns a `budgetAmount` (nullable, for categories with no budget set) per category for the requested period; `BudgetUsageBar` starts receiving a real value with zero UI changes.

---

## 2. Transaction 소비 평가 (spending-mood) field

**현재 상태**: The `Transaction` model has no field for this. `lib/features/transaction/screens/add_transaction_screen.dart` already has a 3-state mood picker (`_moodIndex`: 아쉬운/평범한/만족한) that the user can tap while creating/editing a transaction, but the selected value is **never sent** to `createTransaction`/`updateTransaction` — it's discarded. `lib/features/home/widgets/regret_spending_section.dart` independently documents the same gap for Home's "아쉬운 소비" section.

**필요한 이유**: Figma's Transaction Detail screen (frame 470:9711) shows a "소비 평가: 아쉬운 소비 🙁" row as a persisted, editable field. The new `_MoodRow` in `lib/features/transaction/screens/transaction_detail_screen.dart` renders an honest "기록 없음" and explains the feature is "준비 중" instead of writing a value nothing will read back.

**관련 Backend Service/Model**: `src/models/index.ts` (`Transaction`), `src/controllers/transactionController.ts` (`createTransaction`/`updateTransaction`), `src/validators/schemas.ts` (`transactionSchema`/`transactionPatchSchema`).

**Frontend 연결 위치**: `lib/features/transaction/screens/add_transaction_screen.dart` (`_moodIndex`/`_moodIcons`/`_moodLabels`), `lib/features/transaction/screens/transaction_detail_screen.dart` (`_MoodRow`), `lib/features/home/widgets/regret_spending_section.dart`.

**권장 API contract**: Add `spendingEvaluation: ENUM('REGRET','NEUTRAL','SATISFIED') NULL` to `Transaction`, accepted on `POST /api/transactions` and `PATCH /api/transactions/:id`, returned on all transaction reads. A migration is required (out of scope for this frontend-only session).

**Priority**: Medium-High — this also unblocks Home's "어제 소비 돌아보기" section, which has been stubbed pending exactly this field since an earlier session.

**Acceptance criteria**: Creating/editing a transaction with a mood selected persists it; `GET /api/transactions/:id` and the list endpoint return it; `_MoodRow` and `RegretSpendingSection` can be switched from their empty/placeholder states to real data with no UI restructuring.

---

## 3. `dailyReport` doesn't handle a date range spanning more than one budget cycle

**현재 상태**: `reportService.dailyReport(userId, start, end)` calls `this.context(userId, end ? parseDateOnly(end) : new Date())`, which resolves **one** `BudgetCycle` (via `ensureCurrentCycle`, keyed off `end`), then applies that single cycle's `plannedFlexibleAmount / cycleDays` as `dailyRecommended` uniformly across every day in `[start, end]`. Budget cycles are anchored to the user's `salaryDay` (`UserFinanceSetting.salaryDay`), not the 1st of the calendar month. Our Report screens request full **calendar-month** ranges (`GET /api/reports/daily?startDate=2026-08-01&endDate=2026-08-31`); whenever `salaryDay` isn't 1, that range spans two different budget cycles, but every day in it gets the `recommended`/`difference` figures computed from whichever single cycle contains `end`.

**필요한 이유**: `recommended`/`difference` would be silently wrong for any user whose salary day isn't the 1st, for any calendar-month query. Not a blocker for this ticket — the new Report screens only read `spent` (an unconditionally correct raw transaction sum) from `/api/reports/daily` and never surface `recommended`/`difference` — but the next feature that wants to plot "recommended daily spend" on a calendar-month chart will hit this.

**관련 Backend Service/Model**: `src/services/reportService.ts#dailyReport()` and `#context()`, `src/services/budgetCycleService.ts`.

**Frontend 연결 위치**: Not currently consumed by name, but `lib/features/report/providers/report_provider.dart` calls this endpoint for both the current and previous month, so it's the natural place to switch once fixed.

**권장 API contract**: `dailyReport` should resolve the budget cycle **per day** (or per sub-range) instead of once for the whole request, so each day's `recommended` reflects the cycle it actually belongs to.

**Priority**: Low for this ticket (unused field), Medium once any screen wants per-day recommended amounts on a calendar-month basis.

**Acceptance criteria**: For a user with `salaryDay != 1`, `GET /api/reports/daily?startDate=<month start>&endDate=<month end>` returns `recommended` values that correctly reflect each day's own budget cycle, not just the cycle containing `endDate`.

---

## 4. `dailyReport` only ever includes `EXPENSE` transactions

**현재 상태**: `dailyReport`'s query hardcodes `type: 'EXPENSE'` (`Transaction.findAll({ where: { userId, status: 'CONFIRMED', type: 'EXPENSE', ... } })`). `INCOME` and `SAVING` transactions are excluded entirely, matching the documented `API_SPEC.md` shape (`spent`/`recommended`/`difference` only).

**필요한 이유**: Fine for every Report screen built in this ticket (all use daily data purely as an expense flow, matching Figma exactly — none of the 9 frames show an income line). Flagging this now so a future income-related daily view doesn't assume the data is already there.

**관련 Backend Service/Model**: `src/services/reportService.ts#dailyReport()`.

**Frontend 연결 위치**: None currently — informational only.

**권장 API contract**: If a future screen needs it, either add an `income` field alongside `spent` per day, or accept a `type` query param.

**Priority**: Low (no current frontend need).

**Acceptance criteria**: N/A until a concrete screen requires income-by-day.

---

## 5. Frontend-derived values that would be cleaner as backend fields long-term

All of the following are implemented today as pure, documented, deterministic functions in `lib/features/report/utils/report_date_utils.dart` and `report_insight_utils.dart` (never inline in a widget, per `docs/development-work-policy.md` §6), combining only existing `/api/reports/*` responses. None of them block this ticket. Listed here because if a second client (e.g. a future web dashboard) needs the same numbers, duplicating this logic outside Flutter would be a maintenance risk worth avoiding by moving it server-side eventually:

- **전월 대비 %** — computed from two `summary()`/`daily()` calls (`momPercent()` in `report_insight_utils.dart`).
- **동일 일자 기준 비교** — the partial-month-vs-same-day-range-last-month rule (`monthComparisonRange()` in `report_date_utils.dart`). This is a specific business rule (see Figma's own "비교안내" copy) that isn't captured anywhere in the backend today.
- **주차별 합계** — "주차" (week-of-month) is entirely a frontend invention: `weeklyTotalsFromDaily()` buckets days 1-7/8-14/15-21/22-31 into 4 fixed buckets. The backend has no concept of "주차" at all; if this rule ever needs to change (e.g. to real Mon-Sun weeks), it must change consistently in exactly one place, and today that place is the frontend.
- **카테고리 비율 재검증, 최고 지출 카테고리, 최고 지출 일자, 카테고리 증가폭** — all simple max/diff over an already-fetched list (`topCategory()`, `maxDailyRow()`, `monthlyReportDataProvider`'s growth diff).
- **Report insight 문구** — the "이번 달 리포트 요약" and "월간 리포트" insight sentences are 100% rule-based string templates over the above numbers (`buildMainInsights()`, `buildMonthlyInsights()`); there is no free-text/AI generation anywhere.

**권장 API contract** (if/when moved): a single `/api/reports/insights?month=YYYY-MM` that returns `{ momPercent, topCategory, peakDay, topWeekIndex, topGrowthCategory }` pre-computed, so multiple clients don't reimplement the same rules.

**Priority**: Low (frontend implementation is correct and centralized).

---

## 6. `GET /api/reports/categories` identifies categories by name, not id

**현재 상태**: `reportService.categories()` groups transactions by `transaction.category?.name`, and the response's `category` field is that name string — there is no `categoryId` in the response.

**필요한 이유**: The frontend's "거래내역 보기" button (Category Report → filtered transaction list) has to re-resolve a category name back to an id by cross-referencing `GET /api/categories` (`lib/features/report/screens/category_report_screen.dart`). This works today but is fragile: if a user ever has two categories with the same name (currently not prevented by the schema — `Category.name` has no uniqueness constraint), the match is ambiguous, and the month-over-month category-growth comparison in `monthlyReportDataProvider` (which also matches by name) could silently misattribute.

**관련 Backend Service/Model**: `src/services/reportService.ts#categories()`, `src/models/index.ts` (`Category` — no unique constraint on `name`).

**Frontend 연결 위치**: `lib/features/report/providers/report_provider.dart` (`_toCategoryAmounts`), `lib/features/report/screens/category_report_screen.dart` (name→id lookup for "거래내역 보기").

**권장 API contract**: Add `categoryId` alongside `category` (name) in the `/api/reports/categories` response.

**Priority**: Low (no known duplicate-name accounts today, but cheap to fix and removes a real ambiguity).

**Acceptance criteria**: Response includes a stable `categoryId`; frontend can filter/compare by id instead of by name.
