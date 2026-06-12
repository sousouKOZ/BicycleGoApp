import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_constants.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_form_fields.dart';
import 'widgets/auth_header.dart';

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
      return 'パスワードは$kPasswordRuleLabelで設定してください。';
    }
    return 'アカウント作成に失敗しました。入力内容をご確認ください。';
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final title = isGuest ? 'アカウントを作成' : '新規登録';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            AuthHeader(
              icon: Icons.person_add_alt_1_rounded,
              title: title,
              subtitle: isGuest
                  ? '今のポイント・クーポン・駐輪履歴はそのまま引き継がれます。機種変更後も同じデータを使えます。'
                  : 'メールアドレスとパスワードで登録します。',
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthEmailField(
                    initialValue: _email,
                    onChanged: (v) => _email = v,
                  ),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    initialValue: _password,
                    helperText: kPasswordRuleLabel,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'パスワードを入力してください';
                      if (!isPasswordPolicyCompliant(v)) {
                        return 'パスワードは$kPasswordRuleLabelで入力してください';
                      }
                      return null;
                    },
                    onChanged: (v) => _password = v,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorText(error: _error!),
                  ],
                  const SizedBox(height: 24),
                  AuthSubmitButton(
                    busy: _busy,
                    label: isGuest ? 'アカウントを作成' : '登録',
                    onPressed: _submit,
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
