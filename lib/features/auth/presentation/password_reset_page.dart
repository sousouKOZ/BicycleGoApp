import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_controller.dart';
import 'widgets/auth_header.dart';

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
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            if (_sent) ...[
              const AuthHeader(
                icon: Icons.mark_email_read_rounded,
                title: '再設定メールを送信しました',
              ),
              const SizedBox(height: 16),
              Text(
                '$_email 宛のメールに記載されたリンクを開いて、'
                '新しいパスワードを設定してください。'
                'メールが届かない場合は迷惑メールフォルダもご確認ください。',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ] else ...[
              const AuthHeader(
                icon: Icons.lock_reset_rounded,
                title: 'パスワードの再設定',
                subtitle: '登録済みのメールアドレスを入力してください。'
                    'パスワード再設定用のリンクをお送りします。',
              ),
              const SizedBox(height: 28),
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
                        prefixIcon: Icon(Icons.mail_outline_rounded),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
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
