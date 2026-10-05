# 백업 및 데이터 관리 Backend 요구사항

Figma Frame 105 (`176:5415`) "백업 및 데이터 관리" 화면 구현 시점의 Backend Handoff 문서.

## 1. 기능 목적

사용자가 자신의 가계부 데이터를 백업 / 복원 / 파일로 내보내기 / 전체 초기화할 수 있게 한다.

Frontend 화면(`lib/features/mypage/screens/data_management_screen.dart`)은 Figma대로 완성되어 있지만, 네 기능 모두 Backend가 없어 탭하면 "준비 중" 안내만 표시한다. 어떤 데이터도 변경하지 않는다.

## 2. 현재 상태 (Audit)

| 기능 | Backend | Frontend |
|---|---|---|
| 데이터 백업 | ❌ 없음 | 버튼 → "백업 기능은 준비 중이에요." |
| 최근 백업 시각 | ❌ 없음 | `lastBackupAtProvider` = `null` → "최근 백업 기록이 없어요" |
| 데이터 복원 | ❌ 없음 | "아직 준비 중이에요." |
| 데이터 내보내기 | ❌ 없음 (Frontend에도 파일 저장/공유 패키지 없음) | "아직 준비 중이에요." |
| 데이터 초기화 | ❌ 없음 (`DELETE /api/categories/:id/preference`는 카테고리 단위 설정 리셋일 뿐) | "아직 준비 중이에요." |

## 3. 기준

- 대상 데이터: 거래, 정기 수입 / 급여 주기, 예산 배분(budget plan / allocation), 카테고리 사용자 설정, 알림 설정, 프로필.
- 모든 작업은 인증된 사용자 본인의 데이터만 대상으로 한다.
- 시각은 ISO-8601 (UTC)로 내려주고 Frontend가 로컬 시간으로 `2026.8.25 21:30` 형식 표시.

## 4. Edge case

- 백업 이력이 없는 사용자 → `lastBackupAt: null`.
- 복원 시 백업 이후 생성된 데이터 처리 방식(덮어쓰기 vs 병합)을 명시해야 한다.
- 초기화는 되돌릴 수 없다. 진행 중 실패 시 부분 삭제가 남지 않도록 단일 transaction으로 처리.
- 초기화 후 사용자는 온보딩(재정 설정 없음) 상태가 되어야 한다.

## 5. 요청 API 형태 (제안)

```
GET    /api/backups/latest     → { "lastBackupAt": "2026-08-25T12:30:00Z" | null }
POST   /api/backups            → { "id": "...", "createdAt": "..." }
POST   /api/backups/:id/restore
GET    /api/export?format=csv  → text/csv (또는 xlsx) 파일
DELETE /api/me/data            → body { "confirm": "RESET" } 필수
```

## 6. Frontend가 기대하는 타입

- `lastBackupAt`: `DateTime?` — `lastBackupAtProvider`만 실제 API 호출로 교체하면 UI 변경 없이 연결됨.
- 초기화: 연결 시 Frontend는 반드시 확인 dialog("데이터를 초기화할까요? / 모든 거래와 설정 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다. [취소] [초기화]")를 거친 뒤에만 호출한다.

## 7. Acceptance criteria

- 백업 후 `GET /api/backups/latest`가 새 시각을 반환한다.
- 복원 후 Home / Calendar / Report 수치가 백업 시점과 일치한다.
- 내보내기 파일에 사용자의 전체 거래가 포함된다.
- 초기화 API는 confirm 값 없이 호출 시 400을 반환하고, 다른 사용자 데이터에 영향이 없다.

## 8. 담당자 전달용 요약

"백업 및 데이터 관리" 화면 UI는 완료. 백업 / 최근 백업 시각 / 복원 / 내보내기 / 전체 초기화 API가 모두 없음. 위 5개 endpoint(특히 초기화는 confirm 필수 + 단일 transaction) 추가 요청.
