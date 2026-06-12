import 'package:flutter/material.dart';

/// メールアドレスの共通バリデーション。
String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'メールアドレスを入力してください';
  if (!s.contains('@')) return 'メールアドレスの形式が正しくありません';
  return null;
}

/// 認証フォーム共通のメールアドレス入力欄。
class AuthEmailField extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;

  const AuthEmailField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: textInputAction,
      decoration: const InputDecoration(
        labelText: 'メールアドレス',
        prefixIcon: Icon(Icons.mail_outline_rounded),
      ),
      validator: validateEmail,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// 認証フォーム共通のパスワード入力欄。
/// バリデーションは画面によって異なる（ログインは入力必須のみ、
/// 登録・再設定はパスワードポリシー準拠）ため呼び出し側が渡す。
class AuthPasswordField extends StatelessWidget {
  final String initialValue;
  final String labelText;
  final String? helperText;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthPasswordField({
    super.key,
    required this.initialValue,
    required this.validator,
    required this.onChanged,
    this.labelText = 'パスワード',
    this.helperText,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      obscureText: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        helperText: helperText,
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// 認証フォーム共通のエラーメッセージ表示。
class AuthErrorText extends StatelessWidget {
  final String error;
  const AuthErrorText({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      error,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

/// 認証フォーム共通の送信ボタン。busy 中は無効化してスピナーを出す。
class AuthSubmitButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
