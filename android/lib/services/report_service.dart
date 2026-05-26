import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SavedReport {
  final String id;
  final String type; // 'learning-report' | 'student-analysis'
  final String title;
  final String content;
  final String model;
  final String? courseName;
  final String? studentName;
  final DateTime createdAt;

  SavedReport({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.model,
    this.courseName,
    this.studentName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'content': content,
        'model': model,
        'courseName': courseName,
        'studentName': studentName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedReport.fromJson(Map<String, dynamic> json) => SavedReport(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        model: json['model'] as String? ?? '',
        courseName: json['courseName'] as String?,
        studentName: json['studentName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<Directory> _reportDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${dir.path}/reports');
    if (!reportDir.existsSync()) {
      reportDir.createSync(recursive: true);
    }
    return reportDir;
  }

  Future<SavedReport> save({
    required String type,
    required String title,
    required String content,
    required String model,
    String? courseName,
    String? studentName,
  }) async {
    final dir = await _reportDir();
    final id = DateTime.now().toIso8601String().replaceAll(':', '-');
    final report = SavedReport(
      id: id,
      type: type,
      title: title,
      content: content,
      model: model,
      courseName: courseName,
      studentName: studentName,
      createdAt: DateTime.now(),
    );
    final file = File('${dir.path}/$id.json');
    await file.writeAsString(jsonEncode(report.toJson()), flush: true);
    return report;
  }

  Future<List<SavedReport>> loadAll() async {
    final dir = await _reportDir();
    final reports = <SavedReport>[];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        reports.add(SavedReport.fromJson(data));
      } catch (_) {}
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  Future<void> delete(String id) async {
    final dir = await _reportDir();
    final file = File('${dir.path}/$id.json');
    if (file.existsSync()) await file.delete();
  }

  Future<void> deleteAll() async {
    final dir = await _reportDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final f in files) {
      await f.delete();
    }
  }

  /// Export from raw content (no SavedReport needed).
  Future<String> exportToFileFromContent({
    required String title,
    required String content,
    required String model,
    String? courseName,
    String? studentName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filename = '$safeTitle-$ts.md';
    final file = File('${exportDir.path}/$filename');
    final buf = StringBuffer();
    buf.writeln('# $safeTitle');
    buf.writeln();
    buf.writeln('> 生成时间: ${_formatTime(DateTime.now())}');
    buf.writeln('> 模型: $model');
    if (courseName != null) buf.writeln('> 课程: $courseName');
    if (studentName != null) buf.writeln('> 学生: $studentName');
    buf.writeln();
    buf.writeln(content);
    await file.writeAsString(buf.toString(), flush: true);
    return file.path;
  }

  /// Export a report as a .md file to the downloads directory.
  /// Returns the file path.
  Future<String> exportToFile(SavedReport report) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final safeTitle = report.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filename = '$safeTitle-${report.id}.md';
    final file = File('${exportDir.path}/$filename');
    final buf = StringBuffer();
    buf.writeln('# $safeTitle');
    buf.writeln();
    buf.writeln('> 生成时间: ${_formatTime(report.createdAt)}');
    buf.writeln('> 模型: ${report.model}');
    if (report.courseName != null) {
      buf.writeln('> 课程: ${report.courseName}');
    }
    if (report.studentName != null) {
      buf.writeln('> 学生: ${report.studentName}');
    }
    buf.writeln();
    buf.writeln(report.content);
    await file.writeAsString(buf.toString(), flush: true);
    return file.path;
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
