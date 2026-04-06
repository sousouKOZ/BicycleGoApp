import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcLockSheet extends StatefulWidget {
  final String parkingName;

  const NfcLockSheet({super.key, required this.parkingName});

  @override
  State<NfcLockSheet> createState() => _NfcLockSheetState();
}

class _NfcLockSheetState extends State<NfcLockSheet> {
  String _status = 'iPhone上部をタグに近づけてください';
  bool _isReading = true;
  bool _isSuccess = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startNfc();
  }

  Future<void> _startNfc() async {
    final isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _isReading = false;
        _status = 'この端末ではNFCが使えません';
      });
      return;
    }

    setState(() {
      _isReading = true;
      _status = 'iPhone上部をタグに近づけてください';
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        if (!mounted || _isCancelled) return;

        setState(() {
          _isReading = false;
          _isSuccess = true;
          _status = 'ロックしました';
        });

        NfcManager.instance.stopSession();

        // 成功アニメーションを少し見せてから結果を返す
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        Navigator.of(context).pop(true); // ✅ 成功を返す
      },
      onError: (error) async {
        if (!mounted || _isCancelled) return;

        setState(() {
          _isReading = false;
          _status = '読み取りに失敗しました';
        });

        NfcManager.instance.stopSession();
      },
    );
  }

  @override
  void dispose() {
    _isCancelled = true;
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStyle = theme.textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSuccess
                ? const Icon(Icons.check_circle, color: Colors.green, size: 48)
                : _isReading
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.info, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: statusStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!_isSuccess)
            TextButton(
              onPressed: () {
                _isCancelled = true;
                NfcManager.instance.stopSession();
                Navigator.of(context).pop(false); // ❌ キャンセルを返す
              },
              child: const Text('キャンセル'),
            ),
        ],
      ),
    );
  }
}
