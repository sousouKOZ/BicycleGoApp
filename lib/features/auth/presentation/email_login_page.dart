import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_controller.dart';
import 'password_reset_page.dart';
import 'widgets/auth_header.dart';

/// メールアドレス + パスワードでログインする画面。
/// 成功すると onAuthStateChange(signedIn) が AuthController で処理され、
/// HomeShell が再マウントされてこの画面は自動的に閉じる。
class EmailLoginPage extends ConsumerStatefulWidget {
  const EmailLoginPage({super.key});

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).signInWithEmail(
            _email.trim(),
            _password,
          );
      // 認証成功でゲートが home に切り替わる。この画面は AuthLanding の上に
      // push されているため、ルートまで戻して背後の HomeShell を表に出す。
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyMessage(e));
    } catch (_) {
      setState(() => _error = '通信に失敗しました。しばらくして再度お試しください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('credentials')) {
      return 'メールアドレスまたはパスワードが正しくありません。';
    }
    if (msg.contains('email not confirmed')) {
      return 'メールアドレスの確認が完了していません。確認メールをご確認ください。';
    }
    return 'ログインに失敗しました。入力内容をご確認ください。';
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
            const AuthHeader(
              icon: Icons.login_rounded,
              title: 'おかえりなさい',
              subtitle: 'メールアドレスとパスワードでログインします。',
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
                    textInputAction: TextInputAction.next,
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
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'パスワードを入力してください' : null,
                    onChanged: (v) => _password = v,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ログイン'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PasswordResetPage(),
                              ),
                            ),
                    child: const Text('パスワードを忘れた場合'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
