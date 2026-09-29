import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/skeleton.dart';
import '../../policy/providers/policy_provider.dart';
import '../providers/my_page_provider.dart';
import '../theme/my_tokens.dart';
import '../utils/profile_regions.dart';
import '../widgets/logout_dialog.dart';
import '../widgets/settings_form.dart';

/// 계정 관리: the signed-in user's profile from `GET /api/profile` plus
/// account actions.
///
/// Nickname, age and region are writable (`PUT /api/profile`). Email and
/// password changes, login-method lookup and account deletion have no backend
/// yet (see docs/backend/account-management-requirements.md), so those rows
/// are shown disabled with a short note instead of pretending to work.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  static const String _authPendingNote = '인증 서버 연동 후 지원돼요';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;

    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: settingsAppBar('계정 관리'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          profileAsync.when(
            loading: () => const _ProfileCardSkeleton(),
            error: (e, _) => _ProfileErrorCard(
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (data) => _ProfileCard(
              profile: data,
              onEdit: () => _openProfileEditSheet(context, data),
            ),
          ),
          const SizedBox(height: 24),
          _AccountSection(
            title: '계정 정보',
            rows: [
              _AccountRow(
                icon: Icons.badge_outlined,
                title: '닉네임 변경',
                subtitle: '내 프로필 이름 수정',
                // Enabled once the profile is loaded, so the sheet can start
                // from the saved nickname.
                onTap: profile == null
                    ? null
                    : () => _openNicknameEditSheet(context, profile),
              ),
              const _AccountRow(
                icon: Icons.mail_outline,
                title: '이메일 변경',
                subtitle: _authPendingNote,
              ),
              const _AccountRow(
                icon: Icons.lock_outline,
                title: '비밀번호 변경',
                subtitle: _authPendingNote,
              ),
              const _AccountRow(
                icon: Icons.login_rounded,
                title: '로그인 방식 확인',
                subtitle: _authPendingNote,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AccountSection(
            title: '보안',
            rows: [
              _AccountRow(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                subtitle: '현재 계정에서 로그아웃',
                onTap: () => showLogoutDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _WithdrawalNote(),
        ],
      ),
    );
  }

  void _openProfileEditSheet(BuildContext context, Map<String, dynamic> data) {
    _showEditSheet(
      context,
      _ProfileEditSheet(
        initialAge: (data['age'] as num?)?.toInt(),
        initialRegion: data['region'] as String?,
      ),
    );
  }

  void _openNicknameEditSheet(BuildContext context, Map<String, dynamic> data) {
    _showEditSheet(
      context,
      _NicknameEditSheet(initialNickname: data['nickname'] as String?),
    );
  }

  void _showEditSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final nickname = (profile['nickname'] as String?)?.trim();
    final email = profile['email'] as String?;
    final age = (profile['age'] as num?)?.toInt();
    final region = profile['region'] as String?;
    final hasNickname = nickname != null && nickname.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MyTokens.cardSurface,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: MyTokens.accentSoftBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: MyTokens.accentSoftBorder),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: MyTokens.accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNickname ? nickname : '닉네임 없음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasNickname
                            ? MyTokens.textPrimary
                            : MyTokens.placeholder,
                      ),
                    ),
                    if (email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: MyTokens.placeholder,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: MyTokens.borderNeutral),
          const SizedBox(height: 12),
          _InfoLine(label: '만 나이', value: age == null ? null : '$age세'),
          const SizedBox(height: 8),
          _InfoLine(label: '거주 지역', value: region),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.white,
              foregroundColor: MyTokens.accentDark,
              side: const BorderSide(color: MyTokens.accentSoftBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MyTokens.cardRadius),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text(
              '프로필 수정',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: MyTokens.placeholder),
        ),
        const Spacer(),
        Text(
          value ?? '미설정',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: value == null ? MyTokens.placeholder : MyTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MyTokens.cardSurface,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: const Row(
        children: [
          SkeletonBox(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox.line(width: 96, height: 18),
                SizedBox(height: 8),
                SkeletonBox.line(width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MyTokens.cardSurface,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '계정 정보를 불러오지 못했어요.',
              style: TextStyle(fontSize: 14, color: MyTokens.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: MyTokens.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title plus one card holding [rows] separated by thin dividers.
class _AccountSection extends StatelessWidget {
  final String title;
  final List<_AccountRow> rows;

  const _AccountSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: MyTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MyTokens.cardSurface,
            borderRadius: BorderRadius.circular(MyTokens.cardRadius),
            boxShadow: MyTokens.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          // Transparent Material so row ripples paint above the card.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MyTokens.borderNeutral,
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon + title + description row in the 설정 menu style. A null [onTap]
/// renders the row disabled (muted, no chevron) for actions without backend
/// support yet.
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          color: enabled ? MyTokens.accent : MyTokens.placeholder,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: enabled ? MyTokens.textPrimary : MyTokens.placeholder,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: enabled ? MyTokens.textPrimary : MyTokens.placeholder,
        ),
      ),
      trailing: enabled
          ? const Icon(Icons.chevron_right, color: MyTokens.textMuted)
          : null,
    );
  }
}

/// 회원 탈퇴 sits last and low-emphasis. There is no delete-account API yet,
/// so it is a note rather than a button that could not do anything.
class _WithdrawalNote extends StatelessWidget {
  const _WithdrawalNote();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          '회원 탈퇴',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MyTokens.placeholder,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '회원 탈퇴는 인증 서버 연동 후 이 화면에서 신청할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: MyTokens.placeholder),
        ),
      ],
    );
  }
}

/// Saves through `PUT /api/profile`, then closes the sheet. The provider
/// invalidates `profileProvider`, so the profile card refreshes right away.
mixin _ProfileSaveMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool saving = false;

  /// Shown inside the sheet: a SnackBar would sit behind the modal.
  String? errorMessage;

  Future<void> saveProfile({String? nickname, int? age, String? region}) async {
    setState(() {
      saving = true;
      errorMessage = null;
    });
    try {
      await ref
          .read(myPageActionsProvider.notifier)
          .updateProfile(nickname: nickname, age: age, region: region);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('프로필을 저장했어요.'),
          backgroundColor: MyTokens.accent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        errorMessage = '저장하지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void showError(String message) => setState(() => errorMessage = message);
}

/// Bottom-sheet chrome shared by the profile edit sheets: drag handle,
/// title, description, [fields] and the 저장 button.
class _EditSheetFrame extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> fields;
  final bool saving;
  final String? errorMessage;
  final VoidCallback onSave;

  const _EditSheetFrame({
    required this.title,
    required this.description,
    required this.fields,
    required this.saving,
    required this.errorMessage,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: MyTokens.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MyTokens.borderNeutral,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MyTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: MyTokens.placeholder,
                ),
              ),
              const SizedBox(height: 20),
              ...fields,
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MyTokens.negative,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SettingsSaveButton(isSaving: saving, onPressed: onSave),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edits `nickname`. The backend trims it and rejects blanks and more than
/// [maxLength] characters; the same rules are checked here first.
class _NicknameEditSheet extends ConsumerStatefulWidget {
  static const int maxLength = 20;

  final String? initialNickname;

  const _NicknameEditSheet({this.initialNickname});

  @override
  ConsumerState<_NicknameEditSheet> createState() => _NicknameEditSheetState();
}

class _NicknameEditSheetState extends ConsumerState<_NicknameEditSheet>
    with _ProfileSaveMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNickname ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      showError('닉네임을 입력해주세요.');
      return;
    }
    saveProfile(nickname: nickname);
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: '닉네임 변경',
      description: '프로필에 표시되는 이름이에요.',
      saving: saving,
      errorMessage: errorMessage,
      onSave: _save,
      fields: [
        TextField(
          key: const ValueKey('nickname-field'),
          controller: _controller,
          autofocus: true,
          maxLength: _NicknameEditSheet.maxLength,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: settingsInputDecoration(
            labelText: '닉네임',
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
        ),
      ],
    );
  }
}

/// Edits the policy-profile fields: 만 나이 and 거주 지역.
class _ProfileEditSheet extends ConsumerStatefulWidget {
  final int? initialAge;
  final String? initialRegion;

  const _ProfileEditSheet({this.initialAge, this.initialRegion});

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet>
    with _ProfileSaveMixin {
  late final TextEditingController _ageController = TextEditingController(
    text: widget.initialAge?.toString() ?? '',
  );
  late String? _region = profileRegions.contains(widget.initialRegion)
      ? widget.initialRegion
      : null;

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);
    if (ageText.isNotEmpty && (age == null || age > 120)) {
      showError('만 나이를 0~120 사이로 입력해주세요.');
      return;
    }
    if (age == null && _region == null) {
      showError('만 나이 또는 거주 지역을 입력해주세요.');
      return;
    }
    saveProfile(age: age, region: _region);
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: '프로필 수정',
      description: '맞춤 청년정책 추천에 사용돼요.',
      saving: saving,
      errorMessage: errorMessage,
      onSave: _save,
      fields: [
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: settingsInputDecoration(
            labelText: '만 나이',
            suffixText: '세',
            prefixIcon: const Icon(Icons.cake_outlined),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _region,
          decoration: settingsInputDecoration(
            labelText: '거주 지역',
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          items: profileRegions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (val) => setState(() => _region = val),
        ),
      ],
    );
  }
}
