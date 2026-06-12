import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_controller.dart';
import 'widgets/auth_form_fields.dart';
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
                    AuthEmailField(
                      initialValue: _email,
                      textInputAction: TextInputAction.done,
                      onChanged: (v) => _email = v,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorText(error: _error!),
                    ],
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                      busy: _busy,
                      label: '再設定メールを送信',
                      onPressed: _submit,
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
