# 계정 관리 화면 Backend 요구사항

설정 > 계정 관리(`lib/features/mypage/screens/account_settings_screen.dart`)는 현재 `GET /api/profile`(id, email, nickname, age, region, timezone)과 `PUT /api/profile`(nickname, age, region 수정)만 실제로 연결되어 있다. 아래 항목은 화면에 비활성 행으로 자리만 잡아 두었고, API가 생기면 해당 행에 `onTap`만 연결하면 된다.

## 1. 닉네임 변경 (완료)

- `PUT /api/profile`이 `nickname`을 받도록 확장됨(trim 후 1~20자, 빈 값/null 거부, 보낸 필드만 수정). 기존 `User.nickname` 컬럼을 사용하므로 migration 없음.
- 계정 관리의 "닉네임 변경" 행에 연결됨.
- 남은 과제: 회원가입 시 입력한 이름을 nickname에 저장하는 경로(현재 `authMiddleware`의 `User.upsert`는 nickname을 채우지 않음).

## 2. 로그인 방식 확인 (선택)

- 현재 어떤 API도 가입/로그인 provider(email, kakao, google, apple)를 내려주지 않는다. Frontend도 Supabase 연동 전이라 알 수 없다.
- 요청: `GET /api/profile` 응답에 `authProvider: 'email' | 'kakao' | 'google' | 'apple' | null` 추가(Supabase `app_metadata.provider` 기반). Frontend는 값이 있으면 프로필 카드에 배지로 표시.

## 3. 이메일 변경 / 비밀번호 변경 (Supabase Auth 연동 필요)

- Supabase Auth가 담당하는 기능이라 우리 backend API보다는 Frontend의 Supabase 연동(`AuthActions.updatePassword` 등, `lib/features/auth/providers/auth_actions.dart`)이 선행돼야 한다.
- 이메일 변경 시 backend의 `User.email`도 동기화돼야 한다(현재는 `authMiddleware`의 upsert가 요청마다 갱신하는지 확인 필요).

## 4. 회원 탈퇴 (필수 논의)

- 현재 탈퇴 API 없음. 화면에는 버튼 없이 안내 문구만 둔다.
- 요청: `DELETE /api/account` — Supabase 사용자 삭제(service role 필요) + 사용자 소유 데이터(설정, 예산, 거래, 고정지출, 알림, 북마크, 캘린더 이벤트) 삭제 정책 결정(즉시 삭제 vs 유예 기간).
- Frontend는 확인 다이얼로그 후 호출하고, 성공 시 로그아웃 처리 후 `/login`으로 이동할 예정.

## 담당자 전달용 요약

1. ~~`PUT /api/profile`에 `nickname` 수정 추가~~ (완료)
2. `GET /api/profile`에 `authProvider` 추가 (선택)
3. 이메일/비밀번호 변경은 Supabase Auth 연동 이후 진행
4. `DELETE /api/account` 설계 및 데이터 삭제 정책 결정
