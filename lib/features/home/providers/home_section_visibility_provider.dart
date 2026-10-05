import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Which optional Home sections are shown (앱 설정 > 홈 화면 설정).
///
/// Only sections that can be turned off live here. The hero amount and the
/// 다음 수입 / budget card are Home's core and are always shown.
class HomeSectionVisibility {
  /// 실시간 거래 내역 (header, category chips and transaction cards).
  final bool showRecentTransactions;

  /// 최근 소비 돌아보기.
  final bool showRegretReview;

  const HomeSectionVisibility({
    this.showRecentTransactions = true,
    this.showRegretReview = true,
  });

  HomeSectionVisibility copyWith({
    bool? showRecentTransactions,
    bool? showRegretReview,
  }) {
    return HomeSectionVisibility(
      showRecentTransactions:
          showRecentTransactions ?? this.showRecentTransactions,
      showRegretReview: showRegretReview ?? this.showRegretReview,
    );
  }
}

/// Kept on the device only. Both sections default to shown, so existing
/// users see the same Home as before.
class HomeSectionVisibilityNotifier extends Notifier<HomeSectionVisibility> {
  static const recentTransactionsKey = 'settings.home.showRecentTransactions';
  static const regretReviewKey = 'settings.home.showRegretReview';

  @override
  HomeSectionVisibility build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return HomeSectionVisibility(
      showRecentTransactions: prefs?.getBool(recentTransactionsKey) ?? true,
      showRegretReview: prefs?.getBool(regretReviewKey) ?? true,
    );
  }

  void setRecentTransactions(bool show) {
    state = state.copyWith(showRecentTransactions: show);
    ref.read(sharedPreferencesProvider)?.setBool(recentTransactionsKey, show);
  }

  void setRegretReview(bool show) {
    state = state.copyWith(showRegretReview: show);
    ref.read(sharedPreferencesProvider)?.setBool(regretReviewKey, show);
  }
}

final homeSectionVisibilityProvider =
    NotifierProvider<HomeSectionVisibilityNotifier, HomeSectionVisibility>(
      HomeSectionVisibilityNotifier.new,
    );
