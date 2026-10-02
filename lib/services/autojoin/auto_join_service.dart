import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/class_session.dart';

/// Thin wrapper over the native Android auto-join scheduler, which opens Zoom
/// at class start time even when the app is killed. No-op on other platforms.
class AutoJoinService {
  static const _channel = MethodChannel('com.autozoom/autojoin');

  const AutoJoinService();

  /// Replaces the whole native schedule with the future [classes],
  /// minus the ones the user already joined or dismissed (see [cancel]).
  Future<void> sync(List<ClassSession> classes) async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    final cancelled = await _cancelledIds();
    final items = <Map<String, Object?>>[];
    for (final session in classes) {
      final id = session.notificationId(0);
      final uri = session.zoom.deepLinkUrl ?? session.zoom.computedUrl;
      if (uri == null || !session.startTime.isAfter(now)) continue;
      if (cancelled.contains(id)) continue;
      items.add({
        'id': id,
        'timeMillis': session.startTime.millisecondsSinceEpoch,
        'uri': uri,
        'fallbackUri': session.zoom.computedUrl,
        'title': session.title,
      });
    }
    // Prune cancelled ids that are no longer upcoming so the list stays small.
    final upcomingIds = classes.map((c) => c.notificationId(0)).toSet();
    await _saveCancelledIds(cancelled.intersection(upcomingIds));
    await _invoke('sync', {'items': items});
  }

  /// Cancels the native auto-join for [id] and remembers it, so the next
  /// [sync] (e.g. on app resume) doesn't re-arm it.
  Future<void> cancel(int id) async {
    if (!Platform.isAndroid) return;
    await _saveCancelledIds({...await _cancelledIds(), id});
    await _invoke('cancel', {'id': id});
  }

  Future<Map<String, bool>> getPermissionStatus() async {
    const allGranted = {'overlay': true, 'fullScreen': true, 'exactAlarm': true};
    if (!Platform.isAndroid) return allGranted;
    try {
      return await _channel.invokeMapMethod<String, bool>(
              'getPermissionStatus') ??
          allGranted;
    } on PlatformException catch (e) {
      debugPrint('[AutoJoinService] getPermissionStatus error: $e');
    } on MissingPluginException catch (e) {
      debugPrint('[AutoJoinService] getPermissionStatus error: $e');
    }
    return allGranted;
  }

  Future<void> requestOverlayPermission() => _invoke('requestOverlayPermission');

  Future<void> requestFullScreenPermission() =>
      _invoke('requestFullScreenPermission');

  Future<void> _invoke(String method, [Object? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      debugPrint('[AutoJoinService] $method error: $e');
    } on MissingPluginException catch (e) {
      debugPrint('[AutoJoinService] $method error: $e');
    }
  }

  // Persisted (not in-memory) because a notification "Bỏ qua" runs in a
  // background isolate and the app process may be killed while in Zoom.
  Future<Set<int>> _cancelledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // pick up writes from the notification background isolate
      return (prefs.getStringList(AppConstants.keyAutoJoinCancelledIds) ??
              const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } catch (e) {
      debugPrint('[AutoJoinService] read cancelled ids error: $e');
      return <int>{};
    }
  }

  Future<void> _saveCancelledIds(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.keyAutoJoinCancelledIds,
          ids.map((id) => '$id').toList());
    } catch (e) {
      debugPrint('[AutoJoinService] save cancelled ids error: $e');
    }
  }
}
