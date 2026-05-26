import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_client.dart';
import 'video_player_page.dart';

class DownloadTask {
  final String uuid;
  final String title;
  final String courseName;
  final String kind; // 'video' | 'resource'
  final String url;
  double progress; // 0.0 - 1.0
  DownloadStatus status;
  String? localPath;

  DownloadTask({
    required this.uuid,
    required this.title,
    required this.courseName,
    required this.kind,
    required this.url,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'title': title,
        'courseName': courseName,
        'kind': kind,
        'url': url,
        'progress': progress,
        'status': status.index,
        'localPath': localPath ?? '',
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      courseName: json['courseName'] as String,
      kind: json['kind'] as String,
      url: json['url'] as String,
      progress: (json['progress'] as num).toDouble(),
      status: DownloadStatus.values[json['status'] as int],
      localPath:
          (json['localPath'] as String?)?.isEmpty == true ? null : json['localPath'] as String?,
    );
  }
}

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadsPage extends StatefulWidget {
  final ApiClient api;
  const DownloadsPage({super.key, required this.api});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<DownloadTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final courses = await widget.api.listCourses();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('download_tasks') ?? [];
      final savedTasks = saved
          .map((s) {
            final decoded = _tryDecode(s);
            return DownloadTask.fromJson(
                Map<String, dynamic>.from(decoded ?? {}));
          })
          .where((t) => t.uuid.isNotEmpty)
          .toList();
      final savedUuids = savedTasks.map((t) => t.uuid).toSet();

      final available = <DownloadTask>[];
      for (final c in courses) {
        final courseUuid = c['uuid'] as String;
        final courseName = c['name'] as String? ?? '';
        try {
          final videos = await widget.api.listVideos(courseUuid);
          for (final v in videos) {
            final vuuid = v['uuid'] as String;
            if (!savedUuids.contains(vuuid)) {
              available.add(DownloadTask(
                uuid: vuuid,
                title: v['title'] as String? ?? '',
                courseName: courseName,
                kind: 'video',
                url: widget.api.getVideoDownloadUrl(vuuid),
              ));
            }
          }
        } catch (_) {}
        try {
          final resources = await widget.api.listResources(courseUuid);
          for (final r in resources) {
            final ruuid = r['uuid'] as String;
            if (!savedUuids.contains(ruuid)) {
              available.add(DownloadTask(
                uuid: ruuid,
                title: r['title'] as String? ?? r['file_name'] as String? ?? '',
                courseName: courseName,
                kind: 'resource',
                url: widget.api.getResourceDownloadUrl(courseUuid, ruuid),
              ));
            }
          }
        } catch (_) {}
      }

      // Merge: saved tasks first, then new available ones
      final merged = [...savedTasks, ...available];
      if (mounted) {
        setState(() {
          _tasks = merged;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _tryDecode(String s) {
    try {
      final parts = s.split('|||');
      if (parts.length == 7) {
        return {
          'uuid': parts[0],
          'title': parts[1],
          'courseName': parts[2],
          'kind': parts[3],
          'url': parts[4],
          'progress': double.tryParse(parts[5]) ?? 0.0,
          'status': int.tryParse(parts[6]) ?? 0,
          'localPath': '',
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _tasks.map((t) {
      return '${t.uuid}|||${t.title}|||${t.courseName}|||${t.kind}|||${t.url}|||${t.progress}|||${t.status.index}';
    }).toList();
    await prefs.setStringList('download_tasks', data);
  }

  Future<void> _startDownload(DownloadTask task) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = task.kind == 'video' ? '.mp4' : '';
    final fileName = '${task.uuid}$ext';
    final filePath = '${dir.path}/downloads/$fileName';

    await Directory('${dir.path}/downloads').create(recursive: true);

    setState(() {
      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
    });
    await _saveTasks();

    try {
      await widget.api.downloadToFile(
        task.url,
        filePath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              task.progress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          task.status = DownloadStatus.completed;
          task.localPath = filePath;
          task.progress = 1.0;
        });
        await _saveTasks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          task.status = DownloadStatus.failed;
        });
        await _saveTasks();
      }
      try { await File(filePath).delete(); } catch (_) {}
    }
  }

  Future<void> _deleteTask(DownloadTask task) async {
    if (task.localPath != null) {
      try {
        await File(task.localPath!).delete();
      } catch (_) {}
    }
    setState(() {
      _tasks.remove(task);
    });
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;

    final downloading =
        _tasks.where((t) => t.status == DownloadStatus.downloading).toList();
    final completed =
        _tasks.where((t) => t.status == DownloadStatus.completed).toList();
    final available = _tasks
        .where((t) =>
            t.status == DownloadStatus.pending ||
            t.status == DownloadStatus.failed)
        .toList();

    return Container(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            FHeader.nested(
              title: const Text('离线下载'),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
            suffixes: [
              FButton.icon(
                onPress: _loadTasks,
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.refreshCw),
              ),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: FCircularProgress()))
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(r.hPadding),
                children: [
                  if (downloading.isNotEmpty) ...[
                    SectionHeader(title: '下载中'),
                    ...downloading.map((t) => _buildTaskItem(t, r, colors)),
                    SizedBox(height: r.clamped(16, 10, 24)),
                  ],
                  if (completed.isNotEmpty) ...[
                    SectionHeader(title: '已下载'),
                    ...completed.map((t) => _buildTaskItem(t, r, colors)),
                    SizedBox(height: r.clamped(16, 10, 24)),
                  ],
                  if (available.isNotEmpty) ...[
                    SectionHeader(title: '可下载'),
                    ...available.map((t) => _buildTaskItem(t, r, colors)),
                  ],
                  if (_tasks.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(r.clamped(32, 20, 48)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FIcons.download,
                                size: 48, color: colors.textMuted),
                            const SizedBox(height: 16),
                            Text('暂无下载内容',
                                style: AppTextStyles.scaled(
                                    AppTextStyles.caption, r.scale)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildTaskItem(
      DownloadTask task, Responsive r, AppColors colors) {
    final icon = task.kind == 'video' ? FIcons.video : FIcons.file;
    final kindLabel = task.kind == 'video' ? '视频' : '资料';

    Widget? trailing;
    switch (task.status) {
      case DownloadStatus.pending:
        trailing = FButton.icon(
          onPress: () => _startDownload(task),
          variant: FButtonVariant.ghost,
          child: Icon(FIcons.download, color: AppColors.primary),
        );
        break;
      case DownloadStatus.downloading:
        trailing = SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FDeterminateProgress(value: task.progress),
              SizedBox(height: r.clamped(2, 1, 4)),
              Text('${(task.progress * 100).toInt()}%',
                  style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
            ],
          ),
        );
        break;
      case DownloadStatus.completed:
        trailing = FButton.icon(
          onPress: () => _deleteTask(task),
          variant: FButtonVariant.ghost,
          child: Icon(FIcons.trash, color: AppColors.danger),
        );
        break;
      case DownloadStatus.failed:
        trailing = FButton.icon(
          onPress: () => _startDownload(task),
          variant: FButtonVariant.ghost,
          child: Icon(FIcons.rotateCcw, color: AppColors.warning),
        );
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.clamped(8, 4, 12)),
      padding: EdgeInsets.all(r.clamped(12, 8, 16)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(r.radius),
        border: Border.all(color: colors.border),
      ),
      child: GestureDetector(
        onTap: task.status == DownloadStatus.completed && task.kind == 'video'
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerPage(videoUuid: task.uuid),
                  ),
                )
            : null,
        child: Row(
          children: [
            Icon(icon, size: r.clamped(22, 18, 26), color: AppColors.primary),
            SizedBox(width: r.clamped(10, 6, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: AppTextStyles.scaled(
                          AppTextStyles.bodyBold, r.scale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: r.clamped(2, 1, 4)),
                  Text('$kindLabel · ${task.courseName}',
                      style: AppTextStyles.scaled(
                          AppTextStyles.small, r.scale)),
                  if (task.status == DownloadStatus.failed) ...[
                    SizedBox(height: r.clamped(2, 1, 4)),
                    Text('下载失败，点击重试',
                        style: AppTextStyles.scaled(
                            AppTextStyles.small.copyWith(
                                color: AppColors.danger), r.scale)),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.only(bottom: r.clamped(8, 4, 12)),
      child: Text(title,
          style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
    );
  }
}
