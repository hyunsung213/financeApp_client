# Development Work Policy

이 문서는 이 프로젝트(financeApp Frontend)에서 Frontend 개발을 진행하는 기준을 정의한다. 새로운 화면/기능을 시작하기 전에 반드시 읽는다.

## 0. Final Principle

이 프로젝트의 원칙은:

> "Backend가 준비된 것만 화면에 만든다"

가 아니다.

> "Figma의 제품 경험은 먼저 완성하되, 실제 데이터의 의미는 조작하지 않고, Backend가 도착하면 바로 연결할 수 있게 만든다."

이다.

Backend가 완성될 때까지 Frontend 구현을 기다리지 않는다. 이 프로젝트는 Figma 디자인이 상당 부분 먼저 완성되어 있고, Backend는 앞으로 추가/수정해야 할 기능이 많다. 그래서 "Backend가 없으니 나중에"가 기본값이 되어서는 안 된다.

## 1. Primary Development Goal

1. Frontend는 가능한 한 Figma 디자인과 UX를 높은 fidelity로 먼저 완성한다.
2. Backend가 아직 지원하지 않는 기능 때문에 Frontend 디자인 구현 전체를 중단하지 않는다.
3. 대신 Backend 미지원 데이터를 Frontend에서 가짜 production 계산이나 임시 business logic으로 만들어내지 않는다.
4. Backend가 나중에 완성되었을 때 기존 UI를 다시 뜯지 않고 API/Provider/Model 연결만으로 실제 기능을 붙일 수 있는 integration-ready 구조를 만든다.

## 2. Figma is the UI Source of Truth

Figma는 다음의 기준이다.

- Layout
- Typography
- Color
- Component
- Interaction
- Navigation
- Bottom Sheet / Modal
- Detail Screen
- Empty State / Loading State

Backend가 현재 해당 데이터를 제공하지 않는다는 이유로 Figma에 있는 UI 자체를 삭제하지 않는다. 가능하면 UI는 Figma대로 구현한다.

예: Figma Calendar cell에는 날짜 / +수입 / -지출 / 소비율(%)이 표시된다. Backend가 소비율을 아직 지원하지 않아도 Calendar cell 자체는 Figma 구조대로 구현한다. 대신 production에서는 `spendingRatio == null`이면 해당 값만 숨긴다. 나중에 Backend가 값을 내려주면 동일한 UI에 바로 연결될 수 있어야 한다.

## 3. Backend Audit의 목적

Backend Audit은 "이 기능을 Frontend에서 만들지 말자"를 결정하기 위한 과정이 아니다. 목적은 다음과 같다.

1. 현재 실제 연결 가능한 데이터 확인
2. 아직 Backend가 지원하지 않는 데이터 확인
3. Frontend Model/API contract를 미리 준비
4. Backend 담당자에게 정확한 요구사항 전달

즉 Backend가 부족해도 UI 구현 자체는 가능한 범위에서 계속 진행한다. Backend Audit은 구현을 막는 게이트가 아니라, 무엇을 실제로 연결하고 무엇을 nullable/disabled로 남길지 정하는 사전 조사다.

## 4. Feature Classification

기능/화면을 착수하기 전에 아래 4가지로 분류하고, 분류에 맞는 Action을 따른다.

### ✅ Existing Backend

Backend가 이미 지원.

- Figma UI 구현
- 실제 API 즉시 연결

### ⚠️ Partial Backend

일부 데이터만 존재.

- Figma UI는 최대한 완성
- 존재하는 실제 데이터는 연결
- 없는 값은 nullable/optional 처리
- Backend requirement 작성 (§7 참고)
- Backend 추가 후 즉시 연결 가능한 구조 유지

### ❌ Missing Backend

Backend 기능 자체가 없음.

- Figma UI는 가능한 경우 구현
- Production에서 fake 기능은 동작시키지 않음
- 필요한 Action/Data 영역은 disabled/hidden/empty 상태로 처리
- Backend contract/interface를 준비
- Backend requirement 작성

**중요**: Backend가 없다는 이유만으로 Figma 화면 전체를 생략하지 않는다.

### 🎨 UI Only

Backend 데이터 자체가 필요 없는 순수 UI/UX.

- 그대로 구현

## 5. Backend-Ready Frontend

Backend 미지원 기능을 구현할 때는 향후 실제 API 연결을 고려한다.

예를 들어 Backend가 향후 `recommendedAmount`, `spendingRatio`를 제공할 예정이라면, Frontend Model은 가능하면 다음처럼 optional하게 준비한다.

```dart
final int? recommendedAmount;
final double? spendingRatio;
```

현재 Backend response에 필드가 없으면 `null`로 처리한다. 나중에 Backend가 필드를 추가하면 UI 구조 변경 없이 바로 연결한다.

단, 이 준비 작업이 기존 API parsing이나 현재 production 기능을 깨뜨려서는 안 된다.

## 6. Presentation과 Domain Logic 분리

Frontend UI는 Backend 준비 상태와 가능한 한 독립적으로 구현한다. 다음 레이어를 유지한다.

```
Presentation
      ↓
Provider / State
      ↓
Repository / API
      ↓
Backend
```

UI Widget 내부에 Backend 미지원 계산식을 직접 넣지 않는다. 특히 Figma 디자인을 맞추기 위해 다음을 Widget 내부에 작성하지 않는다.

- 금융 계산
- 통계 계산
- 추천 로직
- 예측 로직

이런 계산이 필요하면 Provider/Repository 레이어에 두고, Backend가 그 값을 내려주기 시작하면 그 레이어만 실제 API 호출로 교체한다.

## 7. Debug Preview

Backend가 아직 없어도 완성된 Figma 화면을 검수할 수 있어야 한다. 따라서 `kDebugMode` 기반 Preview Data는 적극 허용한다.

예:

- Calendar Debug: 무지출 3일, 수입 1,000,000, 지출 500,000, 소비율 60/85/125%
- Policy Debug: 정책 카드 전체 상태
- Report Debug: 그래프와 insight가 채워진 화면

단, Debug data는 항상 다음 원칙을 지킨다.

- production data path와 분리
- release 빌드에 미노출
- API response로 위장하지 않음
- 실제 business logic으로 사용하지 않음

## 8. Design Fidelity

Frontend 구현이 완료되었다고 판단하려면 단순히 기능이 동작하는 것만으로 부족하다. Figma와 실제 렌더링을 비교해서 다음을 확인한다.

- hierarchy
- spacing
- typography
- component size
- border / radius
- gradient
- icon
- information density
- interaction state

"기능은 같다"는 이유로 Figma와 크게 다른 UI를 완료 처리하지 않는다.

## 9. Backend Handoff

Backend가 필요한 부분은 Frontend 작업을 멈추는 blocker가 아니라 Backend Handoff 항목으로 관리한다.

각 페이지 구현 후, `docs/backend/` 하위에 필요한 요구사항 문서를 남긴다. 형식은 `docs/backend/calendar-daily-spending-ratio-requirements.md`를 참고한다 (기능 목적 → 현재 계산/로직과의 일관성 → 계산 기준 → edge case → 요청 API 형태 → frontend가 기대하는 타입 → acceptance criteria → 담당자 전달용 요약 순).

Frontend는 해당 Backend가 구현됐을 때 최소 변경으로 연결될 수 있는 상태여야 한다 (§5, §6 참고).

## 10. Definition of Done

Frontend 페이지의 Done 기준은 다음과 같다.

1. Figma 주요 디자인 구현 완료
2. Interaction 구현 완료
3. 기존 Backend 기능 연결 완료
4. Backend 미지원 값은 fake production logic 없이 처리 (nullable/disabled/hidden)
5. 향후 Backend 연결 지점 준비 (§5, §6)
6. Debug에서 완성 상태 visual QA 가능 (§7)
7. Backend requirement 작성 (해당하는 경우, §9)
8. Responsive 확인
9. `flutter analyze` 통과

Backend 자체가 아직 구현되지 않았다는 이유만으로 Frontend 페이지를 미완료 상태로 남겨둘 필요는 없다.

## 11. Git Safety / Commit / Push Rules

이 프로젝트의 실제 운영 규칙이다. 코드 수정 작업뿐 아니라 이 문서/정책 파일 자체를 바꾸는 작업에도 동일하게 적용한다.

### 11.1 Git 작업 시작 전 필수 확인

모든 코드 수정 작업을 시작하기 전에 반드시 다음을 확인한다.

```
git status
git branch --show-current
git remote -v
```

- 다른 작업자의 uncommitted 변경이 있으면 그대로 보존한다 (임의로 stash/삭제/덮어쓰지 않는다).
- `main`/`master`에서 직접 기능 작업을 하지 않는다. 항상 feature branch에서 작업한다.
- 이미 해당 작업에 맞는 feature branch에 있다면 불필요하게 새 branch를 만들지 않는다.

### 11.2 금지 명령

사용자의 명시적 승인 없이는 절대 다음을 실행하지 않는다.

- `git reset --hard`
- `git clean` (untracked 파일/디렉터리 삭제)
- force push (`git push --force`, `--force-with-lease` 포함)
- 히스토리를 다시 쓰는 작업 (`git rebase -i`, 기존 커밋 amend 등)

되돌리기 어려운 작업(파일/브랜치 삭제, uncommitted 변경 폐기 등) 전에는 `git status`로 현재 상태를 먼저 확인하고, 필요하면 stash/commit으로 먼저 보존한다.

### 11.3 Commit 규칙

- 자동 commit 금지. 커밋은 사용자가 명시적으로 요청했을 때만 생성한다.
- 작업을 완료하면 commit을 실행하기 전에 먼저 다음을 보고한다.
  - 변경 파일
  - 신규 파일
  - 구현 내용
  - 테스트 결과 (예: `flutter analyze`)
  - 남은 이슈
  - 추천 commit message
- 사용자가 이 보고 내용을 보고 명시적으로 승인한 뒤에만 local commit을 수행한다.
- 커밋 시 `git add -A`/`git add .` 대신 관련 파일을 이름으로 명시해서 스테이징하고, 커밋 전 `git status`/`git diff`로 실제 포함되는 내용을 확인한다. `.env`, credential 등 민감 파일은 커밋하지 않는다.
- pre-commit hook 등 커밋/검증 훅은 `--no-verify`로 건너뛰지 않는다. 실패하면 원인을 수정하고 다시 커밋한다.

### 11.4 Push 규칙

- push는 기본적으로 금지한다.
- 사용자가 그 시점에 명시적으로 push를 요청한 경우에만 수행한다.
- **commit 승인과 push 승인은 별개다.** commit을 승인받았다고 해서 push까지 승인된 것으로 해석하지 않는다.
- PR 생성/코멘트 등 원격 저장소에 보이는 다른 작업도 마찬가지로 사용자 확인 후 진행한다.
