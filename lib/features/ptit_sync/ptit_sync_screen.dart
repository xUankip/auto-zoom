import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/calendar/calendar_service.dart';
import 'ptit_sync_controller.dart';

/// Full-screen UI for PTIT timetable auto-sync.
class PtitSyncScreen extends ConsumerStatefulWidget {
  const PtitSyncScreen({super.key});

  @override
  ConsumerState<PtitSyncScreen> createState() => _PtitSyncScreenState();
}

class _PtitSyncScreenState extends ConsumerState<PtitSyncScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _showCredentialsForm = false;
  List<CalendarAccount> _calendars = [];
  String? _selectedCalendarId;
  bool _loadingCalendars = false;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    final controller = ref.read(ptitSyncControllerProvider.notifier);
    final hasCreds = await controller.hasCredentials();

    setState(() {
      _showCredentialsForm = !hasCreds;
    });

    await _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    setState(() => _loadingCalendars = true);
    final controller = ref.read(ptitSyncControllerProvider.notifier);
    final cals = await controller.getWritableCalendars();
    if (mounted) {
      setState(() {
        _calendars = cals;
        _loadingCalendars = false;
        // Auto-select default calendar
        if (_selectedCalendarId == null) {
          final def = cals.where((c) => c.isDefault).firstOrNull ?? cals.firstOrNull;
          _selectedCalendarId = def?.id;
        }
      });
    }
  }

  Future<void> _startSync() async {
    // Validate form if visible
    if (_showCredentialsForm && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedCalendarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lịch để ghi vào')),
      );
      return;
    }

    final ctrl = ref.read(ptitSyncControllerProvider.notifier);
    await ctrl.startSync(
      targetCalendarId: _selectedCalendarId!,
      username: _showCredentialsForm ? _usernameCtrl.text.trim() : null,
      password: _showCredentialsForm ? _passwordCtrl.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(ptitSyncControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryColor = Color(0xFF2563EB);
    const successColor = Color(0xFF16A34A);
    const errorColor = Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Đồng bộ Thời Khóa Biểu PTIT',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            // Hero banner
            // ----------------------------------------------------------------
            _HeroBanner(isDark: isDark),
            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Credentials form (shown if no saved creds)
            // ----------------------------------------------------------------
            if (_showCredentialsForm) ...[
              _SectionCard(
                isDark: isDark,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Tài khoản PTIT', isDark: isDark),
                      const SizedBox(height: 12),
                      _StyledTextField(
                        controller: _usernameCtrl,
                        label: 'Mã sinh viên',
                        hint: 'VD: K26DTCN210',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nhập mã sinh viên' : null,
                      ),
                      const SizedBox(height: 12),
                      _StyledTextField(
                        controller: _passwordCtrl,
                        label: 'Mật khẩu',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isDark: isDark,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔒 Thông tin được lưu an toàn trên thiết bị, không chia sẻ đi đâu.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Show saved creds indicator
            if (!_showCredentialsForm) ...[
              _SectionCard(
                isDark: isDark,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: successColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đã lưu thông tin đăng nhập',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Nhấn "Thay đổi" để nhập lại',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showCredentialsForm = true),
                      child: const Text('Thay đổi', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ----------------------------------------------------------------
            // Calendar selector
            // ----------------------------------------------------------------
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Ghi vào lịch', isDark: isDark),
                  const SizedBox(height: 12),
                  if (_loadingCalendars)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_calendars.isEmpty)
                    const Text(
                      'Không tìm thấy lịch nào có thể ghi. Vui lòng cấp quyền lịch.',
                      style: TextStyle(
                        fontSize: 13,
                        color: errorColor,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCalendarId,
                          isExpanded: true,
                          hint: const Text('Chọn lịch…'),
                          items: _calendars
                              .map((cal) => DropdownMenuItem(
                                    value: cal.id,
                                    child: Text(
                                      cal.accountName != null
                                          ? '${cal.name} (${cal.accountName})'
                                          : cal.name,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedCalendarId = val),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Progress display
            // ----------------------------------------------------------------
            if (syncState.isRunning || syncState.isSuccess || syncState.hasError) ...[
              _SyncProgressCard(
                syncState: syncState,
                isDark: isDark,
                primaryColor: primaryColor,
                successColor: successColor,
                errorColor: errorColor,
              ),
              const SizedBox(height: 24),
            ],

            // ----------------------------------------------------------------
            // Action button
            // ----------------------------------------------------------------
            if (syncState.isSuccess)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(ptitSyncControllerProvider.notifier).reset();
                    setState(() => _showCredentialsForm = false);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Đồng bộ lại'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: syncState.isRunning ? null : _startSync,
                  icon: syncState.isRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(syncState.isRunning ? 'Đang đồng bộ…' : 'Bắt đầu đồng bộ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Info note
            Center(
              child: Text(
                'TKB sẽ được ghi vào lịch thiết bị.\nAutoZoom sẽ tự động đọc và nhắc nhở.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  final bool isDark;
  const _HeroBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đồng bộ TKB tự động',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Lấy toàn bộ lịch học từ cổng PTIT\nvà ghi vào lịch thiết bị.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
    );
  }
}

class _SyncProgressCard extends StatelessWidget {
  final PtitSyncState syncState;
  final bool isDark;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;

  const _SyncProgressCard({
    required this.syncState,
    required this.isDark,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = syncState.isSuccess
        ? successColor
        : syncState.hasError
            ? errorColor
            : primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                syncState.isSuccess
                    ? Icons.check_circle_rounded
                    : syncState.hasError
                        ? Icons.error_rounded
                        : Icons.sync_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  syncState.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          if (syncState.isRunning) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: syncState.progress > 0 ? syncState.progress : null,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(syncState.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],

          if (syncState.hasError && syncState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              syncState.errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: errorColor.withValues(alpha: 0.8),
              ),
            ),
          ],

          if (syncState.isSuccess && syncState.eventsWritten != null) ...[
            const SizedBox(height: 8),
            Text(
              '✅ ${syncState.eventsWritten} buổi học đã được thêm vào lịch.',
              style: TextStyle(
                fontSize: 12,
                color: successColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
