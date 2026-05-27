import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class CheckInPage extends StatefulWidget {
  final AuthProvider auth;
  final String courseUuid;
  final String attendanceUuid;

  const CheckInPage({
    super.key,
    required this.auth,
    required this.courseUuid,
    required this.attendanceUuid,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _attendance;
  List<dynamic> _records = [];
  Map<String, dynamic>? _myRecord;
  String? _filePath;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final detail = await widget.auth.api
          .getAttendanceDetail(widget.courseUuid, widget.attendanceUuid);
      if (mounted) {
        setState(() {
          _attendance = detail;
          _records = (detail['records'] as List<dynamic>?) ?? [];
          _findMyRecord();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _findMyRecord() {
    final myUuid = widget.auth.userUuid;
    for (final r in _records) {
      if (r['student_uuid'] == myUuid) {
        _myRecord = Map<String, dynamic>.from(r);
        return;
      }
    }
    _myRecord = null;
  }

  bool get _isCheckedIn =>
      _myRecord != null && _myRecord!['status'] == 'present';
  bool get _isClosed =>
      _attendance != null && _attendance!['status'] == 'closed';
  bool get _isPhotoMode =>
      _attendance != null && _attendance!['mode'] == 'photo';

  Future<void> _doCheckIn() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.auth.api
          .checkIn(widget.courseUuid, widget.attendanceUuid);
      if (mounted) {
        setState(() {
          _submitting = false;
          _myRecord = result;
          // Update in records list
          for (int i = 0; i < _records.length; i++) {
            if (_records[i]['student_uuid'] == result['student_uuid']) {
              _records[i] = result;
              break;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickAndCheckIn() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (mounted) {
        setState(() {
          _filePath = file.path;
          _fileName = file.name;
        });
      }

      // Upload immediately
      setState(() => _submitting = true);
      try {
        final apiResult = await widget.auth.api.checkInWithPhoto(
          widget.courseUuid,
          widget.attendanceUuid,
          file.path!,
        );
        if (mounted) {
          setState(() {
            _submitting = false;
            _myRecord = apiResult;
            for (int i = 0; i < _records.length; i++) {
              if (_records[i]['student_uuid'] == apiResult['student_uuid']) {
                _records[i] = apiResult;
                break;
              }
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _filePath = null;
            _fileName = null;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final title = _attendance?['title'] as String? ?? '签到';
    final presentCount = _attendance?['present_count'] as int? ?? 0;
    final total = _attendance?['total'] as int? ?? 0;

    return Container(
      color: colors.background,
      child: SafeArea(
        child: _loading
            ? const Center(child: FCircularProgress())
            : Column(
                children: [
                  FHeader.nested(
                    title: Text(title),
                    prefixes: [
                      FButton.icon(
                        onPress: () => Navigator.pop(context),
                        variant: FButtonVariant.ghost,
                        child: const Icon(FIcons.arrowLeft),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(r.hPadding),
                      children: [
                        // Status card
                        GlassCard(
                          padding: EdgeInsets.all(r.clamped(20, 14, 24)),
                          child: Column(
                            children: [
                              // Mode icon
                              Container(
                                width: r.clamped(64, 48, 72),
                                height: r.clamped(64, 48, 72),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isPhotoMode
                                      ? AppColors.primary.withAlpha(25)
                                      : AppColors.success.withAlpha(25),
                                ),
                                child: Icon(
                                  _isPhotoMode
                                      ? FIcons.camera
                                      : FIcons.check,
                                  size: r.clamped(32, 24, 36),
                                  color: _isPhotoMode
                                      ? AppColors.primary
                                      : AppColors.success,
                                ),
                              ),
                              SizedBox(height: r.clamped(12, 8, 16)),
                              Text(
                                _isPhotoMode ? '拍照签到' : '简单签到',
                                style: AppTextStyles.scaled(
                                    AppTextStyles.subheading, r.scale),
                              ),
                              SizedBox(height: r.clamped(4, 2, 6)),
                              Text(
                                _isClosed
                                    ? '签到已结束'
                                    : _isCheckedIn
                                        ? '已签到'
                                        : '请完成签到',
                                style: TextStyle(
                                  fontSize: r.clamped(12, 10, 14),
                                  color: _isClosed
                                      ? AppColors.danger
                                      : _isCheckedIn
                                          ? AppColors.success
                                          : colors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: r.clamped(8, 6, 12)),
                              Text(
                                '已签到 $presentCount / $total 人',
                                style: AppTextStyles.scaled(
                                    AppTextStyles.caption, r.scale),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: r.clamped(20, 14, 28)),

                        // Check-in action
                        if (!_isClosed && !_isCheckedIn) ...[
                          if (!_isPhotoMode) ...[
                            // Simple mode: big check-in button
                            SizedBox(
                              width: double.infinity,
                              height: r.clamped(120, 80, 140),
                              child: FButton(
                                onPress: _submitting ? null : _doCheckIn,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: FCircularProgress(),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            FIcons.check,
                                            size: r.clamped(36, 28, 40),
                                          ),
                                          SizedBox(
                                              height: r.clamped(8, 6, 10)),
                                          Text(
                                            '签 到',
                                            style: TextStyle(
                                              fontSize:
                                                  r.clamped(18, 14, 22),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ] else ...[
                            // Photo mode: pick photo and submit
                            GlassCard(
                              padding:
                                  EdgeInsets.all(r.clamped(16, 12, 20)),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '请拍摄或选择一张照片作为签到凭证',
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.body, r.scale),
                                  ),
                                  SizedBox(
                                      height: r.clamped(12, 8, 16)),
                                  FButton(
                                    onPress: _submitting
                                        ? null
                                        : _pickAndCheckIn,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FIcons.camera,
                                            size: r.clamped(
                                                18, 14, 20)),
                                        SizedBox(
                                            width: r.clamped(8, 6, 10)),
                                        Text('选择照片并签到'),
                                      ],
                                    ),
                                  ),
                                  if (_fileName != null) ...[
                                    SizedBox(
                                        height: r.clamped(12, 8, 16)),
                                    Container(
                                      width: double.infinity,
                                      height: r.clamped(180, 120, 240),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        color: colors.text
                                            .withAlpha(13),
                                      ),
                                      child: _filePath != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                              child: Image.network(
                                                _filePath!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __,
                                                        ___) =>
                                                    const Icon(
                                                        FIcons.image),
                                              ),
                                            )
                                          : Center(
                                              child: Text(_fileName!),
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],

                        // Already checked in
                        if (_isCheckedIn) ...[
                          GlassCard(
                            padding:
                                EdgeInsets.all(r.clamped(16, 12, 20)),
                            child: Row(
                              children: [
                                const Icon(FIcons.check,
                                    color: AppColors.success),
                                SizedBox(width: r.clamped(8, 6, 12)),
                                Text(
                                  '签到成功',
                                  style: AppTextStyles.scaled(
                                      AppTextStyles.bodyBold, r.scale),
                                ),
                                if (_myRecord?['has_photo'] == true) ...[
                                  const Spacer(),
                                  Text(
                                    '已上传照片',
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.caption, r.scale),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Closed
                        if (_isClosed && !_isCheckedIn) ...[
                          GlassCard(
                            padding:
                                EdgeInsets.all(r.clamped(16, 12, 20)),
                            child: Row(
                              children: [
                                const Icon(FIcons.x,
                                    color: AppColors.danger),
                                SizedBox(width: r.clamped(8, 6, 12)),
                                Text(
                                  '签到已结束，您未完成签到',
                                  style: AppTextStyles.scaled(
                                      AppTextStyles.bodyBold, r.scale),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
