import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';

/// Figma's soft-orange "초과" pill (frames 114:5192 / 397:5357).
///
/// Kept as its own reusable widget so it can be re-attached the moment a real
/// category budget exists. It has no decision logic of its own: callers must
/// only build it when `spentAmount > budgetAmount` holds for a *real* budget
/// (see [CategoryShareBar]). Nothing renders it today because the backend has
/// no category budget yet.
class OverBudgetBadge extends StatelessWidget {
  const OverBudgetBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: context.glass.negativeSoft,
        border: Border.all(color: context.glass.negative),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text('초과', style: TextStyle(fontSize: 11, color: context.glass.negative)),
    );
  }
}
