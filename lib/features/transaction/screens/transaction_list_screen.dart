import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/api/category_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/theme/home_tokens.dart';
import '../../home/utils/category_icons.dart';
import '../../report/providers/report_provider.dart';
import '../../report/utils/report_date_utils.dart';
import '../../report/utils/report_insight_utils.dart';
import 'transaction_detail_screen.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// "최근 거래내역 전체" (Figma node 470:9780): category filter chips, then
/// month-grouped + day-grouped transaction rows with a timeline rail.
///
/// Two entry points share this screen:
/// - Home's "실시간 거래 내역 → 더보기" opens it with [initialMonth] == null,
///   so it lists the most recent transactions across all time (unfiltered
///   by month), same as before.
/// - Report/Category Report's "거래 내역 보기" passes the currently selected
///   Report month as [initialMonth], so the list is scoped to that month's
///   `startDate`/`endDate` (via the existing `GET /api/transactions` date
///   range params) instead of showing unrelated, more-recent months first.
///
/// Pagination follows the existing `GET /api/transactions` page/limit/total
/// contract as-is — this screen keeps its own paging state locally (same
/// pattern as `AddTransactionModal`) rather than introducing a new shared
/// provider, since only this screen needs it. [initialMonth] is a fixed
/// snapshot for this screen instance (not reactive to later changes of
/// Report's own selected month elsewhere in the app).
class TransactionListScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  final DateTime? initialMonth;
  const TransactionListScreen({super.key, this.initialCategoryId, this.initialMonth});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  static const _pageLimit = 30;

  String? _categoryId;
  DateTime? _month;
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _month = widget.initialMonth;
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  String? get _startDate => _month == null ? null : formatDateOnly(startOfMonth(_month!));
  String? get _endDate => _month == null ? null : formatDateOnly(endOfMonth(_month!));

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(transactionApiProvider);
      final res = await api.getTransactions(
        categoryId: _categoryId,
        startDate: _startDate,
        endDate: _endDate,
        page: 1,
        limit: _pageLimit,
      );
      setState(() {
        _items
          ..clear()
          ..addAll((res['items'] as List<dynamic>).cast<Map<String, dynamic>>());
        _page = 1;
        _total = (res['total'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _items.length >= _total) return;
    setState(() => _isLoadingMore = true);
    try {
      final api = ref.read(transactionApiProvider);
      final nextPage = _page + 1;
      final res = await api.getTransactions(
        categoryId: _categoryId,
        startDate: _startDate,
        endDate: _endDate,
        page: nextPage,
        limit: _pageLimit,
      );
      setState(() {
        _items.addAll((res['items'] as List<dynamic>).cast<Map<String, dynamic>>());
        _page = nextPage;
        _total = (res['total'] as num?)?.toInt() ?? _total;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  /// Re-fetches page 1 under the current filter/month after returning from
  /// Transaction Detail, so an edit or delete made there never leaves this
  /// list showing stale data (Detail's own provider invalidation already
  /// keeps Home/Report/Calendar in sync, but this screen manages its own
  /// local paging state and isn't covered by that invalidation).
  Future<void> _refreshAfterDetailReturn() async {
    if (!mounted) return;
    await _loadFirstPage();
  }

  void _selectCategory(String? categoryId) {
    if (_categoryId == categoryId) return;
    setState(() => _categoryId = categoryId);
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: HomeTokens.pageBackground,
        elevation: 0,
        foregroundColor: HomeTokens.textDark,
        title: Text(
          _month == null ? '최근 거래내역 전체' : '${_month!.month}월 거래내역',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          categoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox(height: 48),
            data: (categories) => _CategoryFilterRow(
              categories: categories.whereType<Map>().toList(),
              selectedId: _categoryId,
              onSelect: _selectCategory,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('불러오지 못했어요\n$_error', textAlign: TextAlign.center));
    if (_items.isEmpty) return const Center(child: Text('거래 내역이 없어요', style: TextStyle(color: HomeTokens.textMuted)));

    final groups = _groupByMonthThenDay(_items);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: groups.length + (_items.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groups.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final group = groups[index];
        return _MonthSection(group: group, onDetailReturn: _refreshAfterDetailReturn);
      },
    );
  }

  List<_MonthGroup> _groupByMonthThenDay(List<Map<String, dynamic>> items) {
    final monthMap = <String, _MonthGroup>{};
    for (final tx in items) {
      final date = DateTime.tryParse((tx['occurredAt'] ?? '').toString());
      if (date == null) continue;
      final mKey = monthKeyOf(date);
      final month = monthMap.putIfAbsent(mKey, () => _MonthGroup(month: DateTime(date.year, date.month, 1)));
      final dKey = DateFormat('yyyy-MM-dd').format(date);
      final day = month.days.firstWhere(
        (d) => d.dateKey == dKey,
        orElse: () {
          final created = _DayGroup(date: date, dateKey: dKey);
          month.days.add(created);
          return created;
        },
      );
      day.items.add(tx);
    }
    return monthMap.values.toList();
  }
}

String monthKeyOf(DateTime d) => DateFormat('yyyy-MM').format(d);

class _MonthGroup {
  final DateTime month;
  final List<_DayGroup> days = [];
  _MonthGroup({required this.month});
}

class _DayGroup {
  final DateTime date;
  final String dateKey;
  final List<Map<String, dynamic>> items = [];
  _DayGroup({required this.date, required this.dateKey});
}

class _CategoryFilterRow extends StatelessWidget {
  final List<Map> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategoryFilterRow({required this.categories, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _chip(context, null, '전체', null),
          const SizedBox(width: 8),
          for (final c in categories) ...[
            _chip(context, c['id']?.toString(), (c['name'] ?? '').toString(), categoryIconFor(c['id']?.toString(), c['name']?.toString())),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String? id, String label, IconData? icon) {
    final selected = selectedId == id;
    return GestureDetector(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HomeTokens.chipActiveBg : HomeTokens.chipInactiveBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? HomeTokens.chipActiveBorder : HomeTokens.chipInactiveBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: selected ? HomeTokens.accentDark : HomeTokens.textDark), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? HomeTokens.accentDark : const Color(0xFF004725))),
          ],
        ),
      ),
    );
  }
}

class _MonthSection extends ConsumerWidget {
  final _MonthGroup group;
  final Future<void> Function() onDetailReturn;
  const _MonthSection({required this.group, required this.onDetailReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(monthTotalExpenseProvider(group.month));
    final now = DateTime.now();
    final monthDelta = (now.year - group.month.year) * 12 + (now.month - group.month.month);
    // Figma only ever labels the current and immediately-previous month
    // (이번 달 / 저번 달); anything older just shows its own month number so a
    // long scroll-back never mislabels a month from further back as "저번 달".
    final label = monthDelta == 0 ? '이번 달' : (monthDelta == 1 ? '저번 달' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HomeTokens.chipActiveBg,
                  border: Border.all(color: HomeTokens.accent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${group.month.month}월', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomeTokens.accent)),
                  const Icon(Icons.expand_less, size: 14, color: HomeTokens.accent),
                ]),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 16, color: HomeTokens.accent),
                  children: [
                    TextSpan(text: label == null ? '소비 ' : '$label 소비 '),
                    TextSpan(
                      text: totalAsync.maybeWhen(data: (v) => formatWon(v), orElse: () => ''),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final day in group.days) _DaySection(day: day, onDetailReturn: onDetailReturn),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final _DayGroup day;
  final Future<void> Function() onDetailReturn;
  const _DaySection({required this.day, required this.onDetailReturn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: HomeTokens.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 1, offset: const Offset(0, 1))],
                    ),
                    child: Column(
                      children: [
                        Text('${day.date.day}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: HomeTokens.textDark)),
                        Text(DateFormat('E', 'ko_KR').format(day.date), style: const TextStyle(fontSize: 11, color: HomeTokens.textMuted)),
                      ],
                    ),
                  ),
                  const Expanded(child: VerticalDivider(width: 1)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: day.items.map((tx) => _TransactionRow(tx: tx, onDetailReturn: onDetailReturn)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final Future<void> Function() onDetailReturn;
  const _TransactionRow({required this.tx, required this.onDetailReturn});

  @override
  Widget build(BuildContext context) {
    final amount = _toInt(tx['amount']);
    final isIncome = tx['type'] == 'INCOME';
    final categoryName = (tx['category'] is Map ? tx['category']['name'] : null)?.toString();
    final title = (tx['merchantOrTitle'] ?? categoryName ?? '내역').toString();
    final date = DateTime.tryParse((tx['occurredAt'] ?? '').toString());

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx['id'].toString())),
        );
        // Always refetch on return (not just when Detail reports a change)
        // so this screen's local paging state can never go stale.
        await onDetailReturn();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 1, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(color: HomeTokens.chipActiveBg, borderRadius: BorderRadius.circular(6)),
              child: Icon(categoryIconFor(tx['categoryId']?.toString(), categoryName), size: 18, color: HomeTokens.accentDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeTokens.textDark), overflow: TextOverflow.ellipsis)),
                    if (date != null) ...[const SizedBox(width: 6), Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontSize: 11, color: HomeTokens.textMuted))],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${isIncome ? '+' : '-'}${formatWon(amount)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isIncome ? HomeTokens.accentDark : HomeTokens.negative),
                  ),
                ],
              ),
            ),
            if (categoryName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: HomeTokens.chipInactiveBg, borderRadius: BorderRadius.circular(30), border: Border.all(color: HomeTokens.chipInactiveBorder)),
                child: Text(categoryName, style: const TextStyle(fontSize: 11, color: HomeTokens.textDark)),
              ),
            const Icon(Icons.chevron_right, size: 22, color: HomeTokens.textMuted),
          ],
        ),
      ),
    );
  }
}
