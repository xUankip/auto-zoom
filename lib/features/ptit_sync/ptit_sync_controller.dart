import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/calendar/calendar_service.dart';
import '../../services/ptit/ptit_api_client.dart';
import '../../services/ptit/ptit_sync_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum PtitSyncStatus { idle, syncing, success, error }

class PtitSyncState {
  final PtitSyncStatus status;
  final String message;
  final double progress;
  final int? eventsWritten;
  final String? errorMessage;

  const PtitSyncState({
    this.status = PtitSyncStatus.idle,
    this.message = '',
    this.progress = 0.0,
    this.eventsWritten,
    this.errorMessage,
  });

  bool get isRunning => status == PtitSyncStatus.syncing;
  bool get hasError => status == PtitSyncStatus.error;
  bool get isSuccess => status == PtitSyncStatus.success;

  PtitSyncState copyWith({
    PtitSyncStatus? status,
    String? message,
    double? progress,
    int? eventsWritten,
    String? errorMessage,
  }) =>
      PtitSyncState(
        status: status ?? this.status,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        eventsWritten: eventsWritten ?? this.eventsWritten,
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final ptitSyncServiceProvider = Provider<PtitSyncService>((ref) {
  return PtitSyncService();
});

final ptitSyncControllerProvider =
    StateNotifierProvider<PtitSyncController, PtitSyncState>((ref) {
  final service = ref.watch(ptitSyncServiceProvider);
  return PtitSyncController(service);
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class PtitSyncController extends StateNotifier<PtitSyncState> {
  final PtitSyncService _service;

  PtitSyncController(this._service) : super(const PtitSyncState());

  /// Start the sync with explicit credentials. If null, uses saved credentials.
  Future<void> startSync({
    required String targetCalendarId,
    String? username,
    String? password,
  }) async {
    if (state.isRunning) return;

    state = const PtitSyncState(
      status: PtitSyncStatus.syncing,
      message: 'Đang khởi động…',
      progress: 0.0,
    );

    try {
      final written = await _service.sync(
        targetCalendarId: targetCalendarId,
        username: username,
        password: password,
        onProgress: (msg, progress) {
          if (mounted) {
            state = state.copyWith(
              message: msg,
              progress: progress,
            );
          }
        },
      );

      if (mounted) {
        state = PtitSyncState(
          status: PtitSyncStatus.success,
          message: 'Đã đồng bộ $written buổi học thành công!',
          progress: 1.0,
          eventsWritten: written,
        );
      }
    } on PtitAuthException catch (e) {
      if (mounted) {
        state = PtitSyncState(
          status: PtitSyncStatus.error,
          message: 'Lỗi đăng nhập',
          progress: 0.0,
          errorMessage: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        state = PtitSyncState(
          status: PtitSyncStatus.error,
          message: 'Lỗi đồng bộ',
          progress: 0.0,
          errorMessage: e.toString(),
        );
      }
    }
  }

  void reset() {
    if (!state.isRunning) {
      state = const PtitSyncState();
    }
  }

  Future<List<CalendarAccount>> getWritableCalendars() =>
      _service.getWritableCalendars();

  Future<bool> hasCredentials() => _service.hasCredentials();
}
