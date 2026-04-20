import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/api_providers.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../../user/providers/user_providers.dart';

enum _Stage { waitingTag, verifying, success, error }

class NfcLockSheet extends ConsumerStatefulWidget {
  final String parkingName;
  final String deviceId;

  const NfcLockSheet({
    super.key,
    required this.parkingName,
    required this.deviceId,
  });

  @override
  ConsumerState<NfcLockSheet> createState() => _NfcLockSheetState();
}

class _NfcLockSheetState extends ConsumerState<NfcLockSheet> {
  _Stage _stage = _Stage.waitingTag;
  String _message = 'iPhone上部をタグに近づけてください';
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
      // NFC未対応端末：仕様§非機能要件（プロトはAndroidのみNFC）を踏まえ、
      // デモ目的でスキャン成功とみなしてGPS照合・認証フローに進む。
      setState(() {
        _stage = _Stage.verifying;
        _message = 'NFC未対応端末：デモモードで認証を実行します';
      });
      await _authenticate();
      return;
    }

    setState(() {
      _stage = _Stage.waitingTag;
      _message = 'iPhone上部をタグに近づけてください';
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        if (!mounted || _isCancelled) return;
        await NfcManager.instance.stopSession();
        if (!mounted || _isCancelled) return;
        setState(() {
          _stage = _Stage.verifying;
          _message = 'GPS照合中…';
        });
        await _authenticate();
      },
      onError: (error) async {
        if (!mounted || _isCancelled) return;
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        setState(() {
          _stage = _Stage.error;
          _message = '読み取りに失敗しました';
        });
      },
    );
  }

  Future<void> _authenticate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);

      // §7.2 正常系：検知 → 認証。プロトでは認証直前に検知イベントを発火。
      await api.postParkingDetect(
        deviceId: widget.deviceId,
        detectedAt: DateTime.now(),
      );

      final session = await api.postParkingAuth(
        userId: userId,
        deviceId: widget.deviceId,
        lat: position.latitude,
        lng: position.longitude,
      );

      if (!mounted) return;
      ref.read(activeSessionProvider.notifier).state = session;
      setState(() {
        _stage = _Stage.success;
        _message = '認証完了・15分計測を開始しました';
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } on GpsMismatchException catch (e) {
      _showError(e.message);
    } on AuthGraceExpiredException catch (e) {
      _showError(e.message);
    } on ApiException catch (e) {
      _showError('認証に失敗しました（${e.code}）');
    } catch (_) {
      _showError('位置情報の取得に失敗しました。GPSをご確認ください。');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.error;
      _message = message;
    });
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
    Widget icon;
    switch (_stage) {
      case _Stage.success:
        icon = const Icon(Icons.check_circle, color: Colors.green, size: 48);
        break;
      case _Stage.error:
        icon = Icon(Icons.error, color: theme.colorScheme.error, size: 48);
        break;
      case _Stage.waitingTag:
      case _Stage.verifying:
        icon = const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.parkingName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_stage), child: icon),
          ),
          const SizedBox(height: 16),
          Text(
            _message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_stage == _Stage.error)
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _stage = _Stage.waitingTag;
                  _message = 'iPhone上部をタグに近づけてください';
                });
                _startNfc();
              },
              child: const Text('もう一度'),
            ),
          if (_stage != _Stage.success)
            TextButton(
              onPressed: () {
                _isCancelled = true;
                NfcManager.instance.stopSession();
                Navigator.of(context).pop<ParkingSession?>(null);
              },
              child: const Text('キャンセル'),
            ),
        ],
      ),
    );
  }
}
