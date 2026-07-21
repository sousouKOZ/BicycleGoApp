import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_constants.dart';
import '../providers/auth_controller.dart';
import 'widgets/auth_form_fields.dart';
import 'widgets/auth_header.dart';

/// ログイン中にパスワードを変更する画面。プロフィールから push する。
///
/// 現在のパスワードで本人確認（再認証）したうえで新しいパスワードに更新する。
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  String _currentPassword = '';
  String _newPassword = '';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).changePassword(
            _currentPassword,
            _newPassword,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを変更しました')),
      );
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
    if (msg.contains('invalid login') ||
        msg.contains('credentials') ||
        msg.contains('invalid')) {
      return '現在のパスワードが正しくありません。';
    }
    if (msg.contains('same') || msg.contains('should be different')) {
      return '現在のパスワードと異なるパスワードを設定してください。';
    }
    return 'パスワードの変更に失敗しました。入力内容をご確認ください。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            const AuthHeader(
              icon: Icons.password_rounded,
              title: 'パスワードの変更',
              subtitle: '現在のパスワードを確認してから、新しいパスワードを設定します。',
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthPasswordField(
                    initialValue: _currentPassword,
                    labelText: '現在のパスワード',
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'パスワードを入力してください' : null,
                    onChanged: (v) => _currentPassword = v,
                  ),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    initialValue: _newPassword,
                    labelText: '新しいパスワード',
                    helperText: kPasswordRuleLabel,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'パスワードを入力してください';
                      if (!isPasswordPolicyCompliant(v)) {
                        return 'パスワードは$kPasswordRuleLabelで入力してください';
                      }
                      return null;
                    },
                    onChanged: (v) => _newPassword = v,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorText(error: _error!),
                  ],
                  const SizedBox(height: 24),
                  AuthSubmitButton(
                    busy: _busy,
                    label: 'パスワードを変更',
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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
