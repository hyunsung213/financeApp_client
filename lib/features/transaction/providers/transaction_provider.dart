import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/providers/home_provider.dart';
import '../../report/providers/report_provider.dart';
import '../../calendar/screens/calendar_screen.dart';

/// Fetches one transaction by id (Figma 470:9711 "거래 상세") — used so the
/// detail screen is a real `GET /api/transactions/:id` call instead of only
/// working when a caller happens to already have the full object in hand.
final transactionByIdProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(transactionApiProvider);
  return await api.getTransaction(id);
});

/// Invalidates every provider whose data depends on the transaction list:
/// this transaction's own detail cache, Home's recent-transactions +
/// dashboard summary + yesterday-regrettable-spend list, Report's
/// main/monthly data (all months), and Calendar's monthly/daily views. Call
/// this after any create/update/delete so every screen stays in sync — used
/// by both the existing `AddTransactionModal` (create/update/delete) and the
/// new Transaction Detail screen's delete button.
///
/// The "전체 거래내역" list screen manages its own pagination as local
/// widget state (matching this codebase's existing pattern for one-off
/// screens, e.g. `AddTransactionModal`) rather than a shared provider, so it
/// refreshes itself directly instead of being invalidated from here.
void invalidateTransactionDependents(WidgetRef ref) {
  ref.invalidate(transactionByIdProvider);
  ref.invalidate(homeRecentTransactionsProvider);
  ref.invalidate(homeDataProvider);
  ref.invalidate(yesterdayRegrettableTransactionsProvider);
  ref.invalidate(reportMainDataProvider);
  ref.invalidate(monthlyReportDataProvider);
  ref.invalidate(monthlyReportProvider);
  ref.invalidate(dailyTransactionsProvider);
}

/// Deletes a transaction then runs [invalidateTransactionDependents].
Future<void> deleteTransactionAndRefresh(WidgetRef ref, String transactionId) async {
  final api = ref.read(transactionApiProvider);
  await api.deleteTransaction(transactionId);
  invalidateTransactionDependents(ref);
}
