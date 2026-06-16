import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase のレート制限（メール送信・リクエスト過多）に該当するエラーか判定する。
/// 該当時はユーザーに「時間をおいて再試行」を促す文言を出すのに使う。
bool isRateLimitError(AuthException e) {
  if (e.statusCode == '429') return true;
  final code = e.code?.toLowerCase() ?? '';
  if (code.contains('rate')) return true;
  final msg = e.message.toLowerCase();
  return msg.contains('rate limit') || msg.contains('too many');
}

/// レート制限時に表示する共通文言。
const String kRateLimitMessage = '短時間に試行しすぎました。しばらく時間をおいてから再度お試しください。';

/// メールアドレスの形式チェック用の正規表現。
/// 厳密な RFC 準拠ではなく、よくある打ち間違い（@ 抜け・ドメイン無し・空白混入）を
/// はじく実用的なパターン。最終的な有効性確認はサーバ側に委ねる。
final _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// メールアドレスの共通バリデーション。
String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'メールアドレスを入力してください';
  if (!_emailRegExp.hasMatch(s)) return 'メールアドレスの形式が正しくありません';
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
/// 末尾アイコンで表示/非表示を切り替えられる。
class AuthPasswordField extends StatefulWidget {
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
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.initialValue,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        helperText: widget.helperText,
        suffixIcon: IconButton(
          tooltip: _obscured ? 'パスワードを表示' : 'パスワードを隠す',
          icon: Icon(_obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
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

/// メール認証とソーシャルログインを区切る「または」の水平線。
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline.withValues(alpha: 0.4);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'または',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
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
