import 'package:dio/dio.dart';
import 'package:finance_client/data/api/policy_api.dart';
import 'package:finance_client/features/mypage/screens/account_settings_screen.dart';
import 'package:finance_client/features/policy/providers/policy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for `GET/PUT /api/profile`, applying writes the way the backend
/// does (only the fields sent change).
class _FakePolicyApi extends PolicyApi {
  _FakePolicyApi(this.profile) : super(Dio());

  Map<String, dynamic> profile;
  final List<Map<String, dynamic>> updates = [];

  @override
  Future<Map<String, dynamic>> getProfile() async => {...profile};

  @override
  Future<void> updateProfile({
    String? nickname,
    int? age,
    String? region,
  }) async {
    final changes = <String, dynamic>{
      'nickname': ?nickname,
      'age': ?age,
      'region': ?region,
    };
    updates.add(changes);
    profile = {...profile, ...changes};
  }
}

void main() {
  Future<_FakePolicyApi> pumpWithApi(
    WidgetTester tester,
    Map<String, dynamic> profile,
  ) async {
    final api = _FakePolicyApi(profile);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [policyApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AccountSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Map<String, dynamic> profile,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith((ref) async => profile)],
        child: const MaterialApp(home: AccountSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ListTile tileFor(WidgetTester tester, String title) => tester.widget(
    find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
  );

  testWidgets('shows the profile from GET /api/profile', (tester) async {
    await pumpScreen(tester, {
      'email': 'seed@example.local',
      'nickname': 'MVP Seed',
      'age': 25,
      'region': '광주',
    });

    expect(find.text('아직 준비중이에요'), findsNothing);
    expect(find.text('MVP Seed'), findsOneWidget);
    expect(find.text('seed@example.local'), findsOneWidget);
    expect(find.text('25세'), findsOneWidget);
    expect(find.text('광주'), findsOneWidget);
    expect(find.text('프로필 수정'), findsOneWidget);
  });

  testWidgets('missing values are shown as unset, not invented', (
    tester,
  ) async {
    await pumpScreen(tester, {'email': 'a@b.c', 'nickname': null});

    expect(find.text('닉네임 없음'), findsOneWidget);
    expect(find.text('미설정'), findsNWidgets(2));
  });

  testWidgets('unsupported actions are disabled, logout is enabled', (
    tester,
  ) async {
    await pumpScreen(tester, {'email': 'a@b.c'});

    for (final title in ['이메일 변경', '비밀번호 변경', '로그인 방식 확인']) {
      expect(tileFor(tester, title).onTap, isNull, reason: title);
    }
    expect(tileFor(tester, '닉네임 변경').onTap, isNotNull);
    expect(tileFor(tester, '로그아웃').onTap, isNotNull);

    await tester.ensureVisible(find.text('로그아웃'));
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('정말 로그아웃 하시겠습니까?'), findsOneWidget);
  });

  testWidgets('nickname change saves the trimmed value and refreshes', (
    tester,
  ) async {
    final api = await pumpWithApi(tester, {
      'email': 'a@b.c',
      'nickname': 'MVP Seed',
      'age': 25,
      'region': '광주',
    });

    await tester.tap(find.text('닉네임 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nickname-field')),
      '  상훈  ',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(api.updates, [
      {'nickname': '상훈'},
    ]);
    expect(find.text('상훈'), findsOneWidget);
    expect(find.text('25세'), findsOneWidget);
    expect(find.text('프로필을 저장했어요.'), findsOneWidget);
  });

  testWidgets('blank nickname is rejected without calling the API', (
    tester,
  ) async {
    final api = await pumpWithApi(tester, {
      'email': 'a@b.c',
      'nickname': 'MVP Seed',
    });

    await tester.tap(find.text('닉네임 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nickname-field')), '   ');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(api.updates, isEmpty);
    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
  });
}
