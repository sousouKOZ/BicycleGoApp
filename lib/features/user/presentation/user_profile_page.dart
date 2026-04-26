import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../providers/user_providers.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final asyncDeviceId = ref.watch(deviceIdProvider);
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
                  colors: [Color(0xFF2E7CF6), Color(0xFF7C5CFF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332E7CF6),
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
            const _SectionLabel(label: 'プロフィール'),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: GlassDecoration.light(context, radius: 18),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading:
                    Icon(Icons.badge_outlined, color: AppColors.accent),
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
            const _SectionLabel(label: 'デバイス'),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: GlassDecoration.light(context, radius: 18),
              child: asyncDeviceId.when(
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
            const _SectionLabel(label: 'アカウント'),
            const SizedBox(height: 10),
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
                    child: Icon(Icons.cloud_sync_outlined,
                        color: AppColors.accentAlt),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'アカウント連携',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '機種変更時にポイント・履歴・お気に入りを引き継げます',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.subtleBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '準備中',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '※ 現在は端末ローカルにすべてのデータを保存しています。アプリ削除や機種変更でデータが消失します。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNickname(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: ref.read(userProfileProvider).nickname);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ニックネーム'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '20文字以内',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;
    await ref.read(userProfileProvider.notifier).setNickname(next);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
      ),
    );
  }
}
