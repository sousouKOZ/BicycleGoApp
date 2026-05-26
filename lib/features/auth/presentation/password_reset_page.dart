import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_controller.dart';

/// パスワード再設定メールを申請する画面。
/// メールアドレスを入力 → 再設定リンク付きメールを送信。
/// リンクを開くと SDK が passwordRecovery を発火し、SetNewPasswordPage に遷移する。
class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).sendPasswordReset(_email.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (_) {
      setState(() => _error = '送信に失敗しました。メールアドレスをご確認ください。');
    } catch (_) {
      setState(() => _error = '通信に失敗しました。しばらくして再度お試しください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('パスワードの再設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (_sent) ...[
              Icon(Icons.mark_email_read_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '再設定メールを送信しました',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_email 宛のメールに記載されたリンクを開いて、'
                '新しいパスワードを設定してください。'
                'メールが届かない場合は迷惑メールフォルダもご確認ください。',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ] else ...[
              Text(
                '登録済みのメールアドレスを入力してください。'
                'パスワード再設定用のリンクをお送りします。',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'メールアドレスを入力してください';
                        if (!s.contains('@')) return 'メールアドレスの形式が正しくありません';
                        return null;
                      },
                      onChanged: (v) => _email = v,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('再設定メールを送信'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
