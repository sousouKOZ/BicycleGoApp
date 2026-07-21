import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_constants.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_form_fields.dart';
import 'widgets/auth_header.dart';
import 'widgets/google_auth_button.dart';
import 'widgets/legal_consent_text.dart';

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
  String _passwordConfirm = '';
  bool _busy = false;
  bool _confirmationSent = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 匿名（ゲスト）なら linkIdentity で連携し uid 不変でデータを引き継ぐ。
      // ブラウザ起動のみで、完了はディープリンク経由で画面ごと差し替わる。
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (_) {
      setState(() => _error = 'Google ログインを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final needsConfirmation =
          await ref.read(authControllerProvider).signUpWithEmail(
                _email.trim(),
                _password,
              );
      if (!mounted) return;
      if (needsConfirmation) {
        // メール確認が有効：この時点ではサインインされない。確認案内を表示する。
        setState(() => _confirmationSent = true);
      } else {
        // 確認 OFF では即サインイン状態になりゲートが home に切り替わる。
        // この画面は AuthLanding の上に push されているためルートまで戻す。
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
    if (isRateLimitError(e)) return kRateLimitMessage;
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

    if (_confirmationSent) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              const AuthHeader(
                icon: Icons.mark_email_read_rounded,
                title: '確認メールを送信しました',
              ),
              const SizedBox(height: 16),
              Text(
                '$_email 宛のメールに記載されたリンクを開くと登録が完了します。'
                'リンクを開いた後、アプリに自動で戻ってログイン状態になります。'
                'メールが届かない場合は迷惑メールフォルダもご確認ください。',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

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
                  ),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    initialValue: _passwordConfirm,
                    labelText: 'パスワード（確認）',
                    validator: (v) {
                      if (v == null || v.isEmpty) return '確認用のパスワードを入力してください';
                      if (v != _password) return 'パスワードが一致しません';
                      return null;
                    },
                    onChanged: (v) => _passwordConfirm = v,
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
                  const SizedBox(height: 16),
                  const AuthOrDivider(),
                  const SizedBox(height: 16),
                  GoogleAuthButton(
                    busy: _busy,
                    onPressed: _signInWithGoogle,
                  ),
                  const SizedBox(height: 20),
                  const LegalConsentText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
