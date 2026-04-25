import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_providers.dart';
import '../../sessions/data/notification_service.dart';
import '../../sessions/providers/notification_permission_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionLabel(label: 'テーマ'),
            const SizedBox(height: 10),
            _ThemeModeSelector(
              selected: mode,
              onChanged: (m) =>
                  ref.read(themeModeProvider.notifier).set(m),
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: '通知'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.notifications_active_rounded,
                      color: AppColors.accent),
                  title: const Text('通知権限を確認'),
                  subtitle: Text(
                    'クーポン発行タイミングの通知を受け取るか確認します',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final ok = await NotificationService.instance
                        .requestPermissions();
                    final permNotifier =
                        ref.read(notificationPermissionProvider.notifier);
                    if (ok) {
                      permNotifier.markGranted();
                    } else {
                      permNotifier.markDenied();
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? '通知権限はオンです' : '通知権限がオフです。設定アプリから許可してください。',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: 'アプリ情報'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.info_outline_rounded,
                      color: AppColors.accent),
                  title: const Text('バージョン'),
                  trailing: Text(
                    '1.0.0',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.subtleBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = <_ThemeOption>[
      _ThemeOption(
        mode: ThemeMode.system,
        label: '端末設定に合わせる',
        icon: Icons.phone_iphone_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        label: 'ライト',
        icon: Icons.light_mode_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        label: 'ダーク',
        icon: Icons.dark_mode_rounded,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.subtleBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _ThemeOptionTile(
              option: options[i],
              selected: selected == options[i].mode,
              onTap: () => onChanged(options[i].mode),
            ),
            if (i < options.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: context.subtleBorder,
              ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });
}

class _ThemeOptionTile extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(option.icon, color: AppColors.accent),
      title: Text(
        option.label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}
