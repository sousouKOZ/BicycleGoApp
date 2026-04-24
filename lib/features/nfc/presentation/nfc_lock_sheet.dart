import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../../sessions/data/notification_service.dart';
import '../../user/providers/user_providers.dart';

enum _Stage { waitingTag, verifying, success, error }

class NfcLockSheet extends ConsumerStatefulWidget {
  final String parkingId;
  final String parkingName;
  final String deviceId;

  const NfcLockSheet({
    super.key,
    required this.parkingId,
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

  Future<void> _scheduleSessionNotifications(ParkingSession session) async {
    final startedAt = session.authenticatedAt ?? DateTime.now();
    final notifier = NotificationService.instance;
    await notifier.requestPermissions();
    await notifier.scheduleSessionReminders(
      sessionStartAt: startedAt,
      parkingName: widget.parkingName,
    );
  }

  Future<void> _authenticate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);

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
      ref.read(activeParkingInfoProvider.notifier).state = ActiveParkingInfo(
        parkingId: widget.parkingId,
        parkingName: widget.parkingName,
      );
      unawaited(_scheduleSessionNotifications(session));
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

  Color get _accent {
    switch (_stage) {
      case _Stage.success:
        return AppColors.success;
      case _Stage.error:
        return AppColors.danger;
      case _Stage.waitingTag:
      case _Stage.verifying:
        return AppColors.accent;
    }
  }

  String get _statusLabel {
    switch (_stage) {
      case _Stage.waitingTag:
        return 'スキャン待機中';
      case _Stage.verifying:
        return '認証中';
      case _Stage.success:
        return '認証完了';
      case _Stage.error:
        return 'エラー';
    }
  }

  IconData get _statusIcon {
    switch (_stage) {
      case _Stage.waitingTag:
        return Icons.nfc_rounded;
      case _Stage.verifying:
        return Icons.radar_rounded;
      case _Stage.success:
        return Icons.check_circle_rounded;
      case _Stage.error:
        return Icons.error_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.parkingName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: GlassDecoration.accentCard(context, radius: 24),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _StageIcon(
                    key: ValueKey(_stage),
                    stage: _stage,
                    icon: _statusIcon,
                    accent: accent,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_stage == _Stage.error)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _stage = _Stage.waitingTag;
                  _message = 'iPhone上部をタグに近づけてください';
                });
                _startNfc();
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('もう一度'),
            ),
          if (_stage != _Stage.success) ...[
            if (_stage == _Stage.error) const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _isCancelled = true;
                NfcManager.instance.stopSession();
                Navigator.of(context).pop<ParkingSession?>(null);
              },
              child: Text(
                'キャンセル',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  final _Stage stage;
  final IconData icon;
  final Color accent;
  const _StageIcon({
    super.key,
    required this.stage,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading =
        stage == _Stage.waitingTag || stage == _Stage.verifying;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.12),
              ),
            ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: accent, size: 34),
          ),
        ],
      ),
    );
  }
}
