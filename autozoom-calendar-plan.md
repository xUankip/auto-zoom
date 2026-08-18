# AutoZoom (AutoClass) - Calendar Integration & Instant Zoom Launcher Plan (v2.1)

> **Task Slug:** `autozoom-calendar-plan`  
> **Project Type:** MOBILE (Flutter / iOS 17+ & Android)  
> **Core Principle:** Ponytail Lazy Senior Dev — Zero-Backend, Zero-DB, Calendar as Single Source of Truth, Reconciliation Engine

---

## 1. Executive Summary & Ponytail Architecture

AutoZoom transforms the mobile device's native Calendar (Apple Calendar / synced Google Calendar via EventKit / Calendar Provider) into an automated class schedule and Zoom meeting launcher.

### Ponytail Lazy Senior Dev Decisions:
1. **Rung 1 (YAGNI):** No backend servers, no user authentication, no database (SQLite/Isar) duplication. Calendar is the source of truth.
2. **Rung 2 & 3 (Native Platform & Stdlib):**
   - iOS: `device_calendar: ^4.3.3` with `NSCalendarsFullAccessUsageDescription` (iOS 17+) and `NSCalendarsUsageDescription` (iOS <= 16 fallback). `NSRemindersUsageDescription` removed completely.
   - Android: `READ_CALENDAR`, `POST_NOTIFICATIONS`.
3. **Rung 4 (Minimal Logic & Abstraction):**
   - `MeetingLauncher` abstraction with `ZoomLauncher` (prioritizes raw `joinUrl` directly via App/Universal Links $\rightarrow$ fallback to constructed HTTPS URL $\rightarrow$ clear failure handling).
   - Robust `ZoomParser` pipeline with strict Meeting ID validation (9–11 digits) and passcode validation.
   - Deterministic Notification IDs: `DeterministicHash` (DJB2 32-bit positive integer hash, independent of Dart runtime `String.hashCode`).
   - Immutable Notification Payload: Contains `{eventId, joinUrl, meetingId}` for zero-delay 1-tap join without re-querying the calendar.
   - Rolling Window: `const notificationScheduleWindow = Duration(days: 7);`.

---

## 2. Technical Architecture & Directory Layout

```
lib/
├── app/
│   ├── app.dart                          # AppLifecycleListener (Auto-sync on resume)
│   └── app_theme.dart                    # Modern Slate & Sky-blue palette
│
├── core/
│   ├── constants/app_constants.dart      # Constants (7-day window, channels, keys)
│   ├── models/
│   │   ├── app_settings.dart             # Settings preferences
│   │   ├── class_session.dart            # Immutable session & notification payload
│   │   └── zoom_meeting.dart             # Zoom URL & Deep-link constructor
│   ├── parser/zoom_parser.dart           # Priority Regex & 9-11 digit validation
│   └── utils/deterministic_hash.dart     # DJB2 32-bit stable hash without SQLite
│
├── services/
│   ├── calendar/
│   │   ├── calendar_service.dart         # Interface
│   │   └── device_calendar_service.dart  # device_calendar implementation
│   ├── meetings/
│   │   ├── meeting_launcher.dart         # MeetingLauncher interface
│   │   └── zoom_launcher.dart            # joinUrl priority + zoomus:// + Web fallback
│   └── notifications/
│       ├── notification_reconciler.dart  # Pure functional reconciler
│       └── notification_service.dart     # flutter_local_notifications engine
│
├── features/
│   ├── home/
│   │   ├── home_controller.dart          # Riverpod state notifier & sync logic
│   │   ├── home_screen.dart              # Timeline UI (Hôm nay & 7 ngày tới)
│   │   └── widgets/
│   │       ├── class_session_card.dart   # Interactive class card with 1-tap join
│   │       ├── empty_schedule_view.dart  # Empty state
│   │       └── permission_request_card.dart # Permission prompt
│   └── settings/
│       ├── settings_controller.dart      # SharedPreferences persistence
│       └── settings_sheet.dart           # Calendar multi-select & reminder dropdown
│
└── main.dart                             # ProviderScope & app entrypoint
```

---

## 3. Core Data Models & Abstractions

### 3.1 `ZoomMeeting`
```dart
class ZoomMeeting {
  final String? joinUrl;
  final String? meetingId;
  final String? passcode;

  const ZoomMeeting({
    this.joinUrl,
    this.meetingId,
    this.passcode,
  });

  /// Computed direct join URL: uses explicit joinUrl or constructs from ID + passcode.
  String? get computedUrl {
    if (joinUrl != null && joinUrl!.trim().isNotEmpty) return joinUrl!.trim();
    if (meetingId != null && meetingId!.trim().isNotEmpty) {
      final cleanId = meetingId!.replaceAll(RegExp(r'\s+|-'), '');
      if (passcode != null && passcode!.trim().isNotEmpty) {
        return 'https://zoom.us/j/$cleanId?pwd=${Uri.encodeComponent(passcode!.trim())}';
      }
      return 'https://zoom.us/j/$cleanId';
    }
    return null;
  }
}
```

### 3.2 `MeetingLauncher` Abstraction
```dart
enum LaunchStatus { appLaunched, webFallback, failed }

abstract class MeetingLauncher {
  Future<LaunchResult> launch(ZoomMeeting meeting);
}
```

---

## 4. Implementation Phases & Status

### ✅ PHASE 0: Foundation & Setup
- [x] Flutter initialized with platforms `ios`, `android`.
- [x] Dependencies added: `device_calendar: ^4.3.3`, `flutter_riverpod: ^2.5.1`, `flutter_local_notifications`, `timezone`, `url_launcher`, `shared_preferences`, `intl`.
- [x] Theme system without prohibited violet/purple colors (`AppTheme`).

### ✅ PHASE 1: Codebase & Logic Implementation
- [x] `ZoomParser` pipeline (priority-based + strict 9-11 digit validation) $\rightarrow$ 100% tests pass.
- [x] `DeterministicHash` (DJB2 32-bit stable hash independent of Dart String.hashCode) $\rightarrow$ 0 collisions across 5,000 pairs.
- [x] `NotificationReconciler` & `NotificationService` (Add/Update/Delete reconciliation lifecycle, action buttons `[Tham gia ngay]` / `[Bỏ qua]`, password concealed from lock-screen banner).
- [x] `CalendarService` & `DeviceCalendarService` (iOS 17+ Full Access & Android calendar reading, recurring events, filtering).
- [x] `ZoomLauncher` (direct `joinUrl` launch + `zoomus://` + web fallback).
- [x] UI: `HomeScreen` timeline (Today + 7 Days), `SettingsSheet` (calendar multi-selection & reminder offset), and `AppLifecycleListener` for foreground auto-sync.

### ⏳ PHASE 0.5: Real Device Acceptance Testing
*Detailed manual verification checklist created at [REAL_DEVICE_VALIDATION.md](file:///home/ubuntu/Desktop/AutoZoom/REAL_DEVICE_VALIDATION.md):*
- [ ] TC-01 to TC-03: Calendar Permission Flow (iOS 17+ Full Access & Settings redirect).
- [ ] TC-04 to TC-05: Synced Google Calendar via iPhone EventKit.
- [ ] TC-06 to TC-07: Calendar filtering (School vs Personal).
- [ ] TC-08 to TC-10: Live Zoom link & Vietnamese text parsing on real device.
- [ ] TC-11 to TC-13: Lock-screen Notification timing, privacy, and action buttons.
- [ ] TC-14 to TC-15: Zoom app deep-linking vs HTTPS fallback on device.
- [ ] TC-16 to TC-17: Real-time Reconciliation when modifying/deleting calendar events.
- [ ] TC-18: Background / Killed app notification firing.

---

## 5. Automated Verification Status

```bash
$ flutter analyze
Analyzing AutoZoom...
No issues found! (ran in 0.5s)

$ flutter test
00:00 +19: All tests passed!
```
