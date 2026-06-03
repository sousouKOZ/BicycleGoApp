import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_constants.dart';
import '../providers/auth_controller.dart';
import 'widgets/auth_header.dart';

/// パスワード再設定リンクを開いた後（passwordRecovery 発火後）に表示し、
/// 新しいパスワードを設定する画面。app.dart が rootNavigatorKey 経由で push する。
class SetNewPasswordPage extends ConsumerStatefulWidget {
  const SetNewPasswordPage({super.key});

  @override
  ConsumerState<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends ConsumerState<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
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
      await ref.read(authControllerProvider).updatePassword(_password);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを変更しました')),
      );
    } on AuthException catch (_) {
      setState(() => _error = 'パスワードの変更に失敗しました。もう一度お試しください。');
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
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            const AuthHeader(
              icon: Icons.lock_outline_rounded,
              title: '新しいパスワード',
              subtitle: '新しいパスワードを入力してください。',
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '新しいパスワード',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      helperText: kPasswordRuleLabel,
                    ),
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
                        : const Text('パスワードを変更'),
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
