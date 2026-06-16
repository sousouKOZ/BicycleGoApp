import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/domain/account_status.dart';
import '../../auth/presentation/change_password_page.dart';
import '../../auth/presentation/email_login_page.dart';
import '../../auth/presentation/email_signup_page.dart';
import '../../auth/presentation/widgets/auth_form_fields.dart';
import '../../auth/presentation/widgets/google_auth_button.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/user_providers.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final asyncInstallId = ref.watch(installIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.accentAlt],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3300A88F),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      profile.initial,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BicycleGo ユーザー',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel(label: 'プロフィール'),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: GlassDecoration.light(context, radius: 18),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.badge_outlined, color: AppColors.accent),
                title: const Text('ニックネーム'),
                subtitle: Text(
                  profile.nickname.isEmpty ? '未設定' : profile.nickname,
                  style: theme.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editNickname(context, ref),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel(label: 'デバイス'),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: GlassDecoration.light(context, radius: 18),
              child: asyncInstallId.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('読み込み失敗: $e'),
                ),
                data: (deviceId) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading:
                      Icon(Icons.smartphone_rounded, color: AppColors.accent),
                  title: const Text('デバイスID'),
                  subtitle: Text(
                    deviceId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'コピー',
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: deviceId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コピーしました')),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel(label: 'アカウント'),
            const SizedBox(height: 10),
            _AccountCard(status: ref.watch(accountStatusProvider)),
          ],
        ),
      ),
    );
  }

  Future<void> _editNickname(BuildContext context, WidgetRef ref) async {
    final initial = ref.read(userProfileProvider).nickname;
    // 手動で TextEditingController を作るとダイアログ unmount 前に dispose して
    // _dependents.isEmpty アサーション失敗を起こすため、TextFormField の
    // initialValue + onChanged で Flutter 側にライフサイクルを任せる。
    var text = initial;
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ニックネーム'),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '20文字以内',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => text = v,
          onFieldSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (next == null) return;
    await ref.read(userProfileProvider.notifier).setNickname(next);
  }
}

/// アカウント連携状態カード。ゲストなら作成/ログイン導線、連携済みなら
/// メール/Google 表示とログアウト。
class _AccountCard extends ConsumerWidget {
  final AccountStatus status;
  const _AccountCard({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isGuest = status.isGuest;

    final String title;
    final IconData icon;
    if (isGuest) {
      title = 'ゲストとして利用中';
      icon = Icons.person_outline_rounded;
    } else if (status.kind == AccountKind.googleLinked) {
      title = 'Google で連携済み';
      icon = Icons.verified_user_outlined;
    } else {
      title = 'メールで連携済み';
      icon = Icons.verified_user_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: GlassDecoration.light(context, radius: 18),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentAlt.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.accentAlt),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!isGuest && status.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isGuest) ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmailSignupPage()),
            ),
            child: const Text('アカウントを作成'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmailLoginPage()),
            ),
            child: const Text('ログイン'),
          ),
          const SizedBox(height: 16),
          const AuthOrDivider(),
          const SizedBox(height: 16),
          GoogleAuthButton(
            busy: false,
            onPressed: () => _signInWithGoogle(context, ref),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ゲストのデータ（ポイント・クーポン・駐輪履歴）は一時アカウントに保存されています。'
              'アカウントを作成すると、機種変更後も同じデータを引き継げます。'
              'なお、お気に入り駐輪場はこの端末のみに保存され、引き継がれません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ] else ...[
          if (status.hasPasswordLogin) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
              icon: const Icon(Icons.password_rounded, size: 18),
              label: const Text('パスワードを変更'),
            ),
            const SizedBox(height: 8),
          ],
          // Google 連携の追加/解除。未連携なら追加、連携済みかつ他の手段が
          // 残る場合のみ解除を出す（最後の1手段は解除させない）。
          if (!status.hasGoogleLinked) ...[
            OutlinedButton.icon(
              onPressed: () => _linkGoogle(context, ref),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Google と連携'),
            ),
            const SizedBox(height: 8),
          ] else if (status.canUnlinkGoogle) ...[
            OutlinedButton.icon(
              onPressed: () => _confirmUnlinkGoogle(context, ref),
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Google 連携を解除'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('ログアウト'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ポイント・クーポン・駐輪履歴はアカウントに保存されています。'
              '別の端末でも同じアカウントでログインすれば引き継げます。'
              'なお、お気に入り駐輪場はこの端末のみに保存され、引き継がれません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 退会導線（ストア要件）。元に戻せないため強めの確認を挟む。
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              child: const Text('アカウントを削除'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text(
          'アカウントとすべてのデータ（ポイント・クーポン・駐輪履歴）が完全に削除されます。'
          'この操作は取り消せません。同じデータを復元することはできません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authControllerProvider).deleteAccount();
      // 削除成功で signOut → ゲートが authLanding に切り替わる。プロフィール画面は
      // HomeShell の上に push されているため、ルートまで戻して背後を表に出す。
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('アカウントを削除しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('アカウントの削除に失敗しました。通信環境をご確認ください。')),
      );
    }
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      // 匿名（ゲスト）なら linkIdentity で連携し、uid 不変でデータを引き継ぐ。
      // ブラウザ起動のみで、連携成立はディープリンク経由で onAuthStateChange が処理する。
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google ログインを開始できませんでした。')),
        );
      }
    }
  }

  Future<void> _linkGoogle(BuildContext context, WidgetRef ref) async {
    try {
      // ブラウザ起動のみ。連携成立はディープリンク経由で onAuthStateChange が
      // 処理し、accountStatusProvider 経由でこのカードが連携済み表示に更新される。
      await ref.read(authControllerProvider).linkGoogle();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 連携を開始できませんでした。')),
        );
      }
    }
  }

  Future<void> _confirmUnlinkGoogle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Google 連携を解除しますか？'),
        content: const Text(
          '解除後は Google でのログインができなくなります。'
          'メールアドレスとパスワードでのログインは引き続き利用できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authControllerProvider).unlinkGoogle();
      messenger.showSnackBar(
        const SnackBar(content: Text('Google 連携を解除しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Google 連携の解除に失敗しました。')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        content: const Text(
          'ログアウトしてもデータはアカウントに保存されています。'
          '再度ログインすればいつでも復元できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider).signOut();
    // サインアウトでゲートが authLanding に切り替わる。プロフィール画面は
    // HomeShell の上に push されているため、ルートまで戻して背後の
    // AuthLanding を表に出す。
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
