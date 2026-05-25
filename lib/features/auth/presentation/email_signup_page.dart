import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_constants.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// メールアドレス + パスワードでアカウントを新規作成する画面。
/// 匿名（ゲスト）状態なら「昇格」となり、uid 不変でポイント・クーポン・履歴を
/// 引き継いだままアカウント化する。
class EmailSignupPage extends ConsumerStatefulWidget {
  const EmailSignupPage({super.key});

  @override
  ConsumerState<EmailSignupPage> createState() => _EmailSignupPageState();
}

class _EmailSignupPageState extends ConsumerState<EmailSignupPage> {
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
      await ref.read(authControllerProvider).signUpWithEmail(
            _email.trim(),
            _password,
          );
      // 確認 OFF（Phase 1）では即サインイン状態になりゲートが home に切り替わる。
      // この画面は AuthLanding の上に push されているためルートまで戻す。
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
    if (msg.contains('already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already exists')) {
      return 'このメールアドレスは既に登録されています。ログインをお試しください。';
    }
    if (msg.contains('password')) {
      return 'パスワードは$kMinPasswordLength文字以上で設定してください。';
    }
    return 'アカウント作成に失敗しました。入力内容をご確認ください。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGuest = ref.watch(isGuestProvider);
    final title = isGuest ? 'アカウントを作成' : '新規登録';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (isGuest)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '今のポイント・クーポン・駐輪履歴はそのまま引き継がれます。'
                  'アカウントを作成すると、機種変更後も同じデータを使えます。',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
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
                      border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'パスワードを入力してください';
                      if (v.length < kMinPasswordLength) {
                        return 'パスワードは$kMinPasswordLength文字以上で入力してください';
                      }
                      return null;
                    },
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
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isGuest ? 'アカウントを作成' : '登録'),
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
