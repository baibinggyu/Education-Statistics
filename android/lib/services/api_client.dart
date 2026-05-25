import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String serverUrl = 'https://124.222.82.196';
  String? token;
  String? userUuid;
  String? username;
  String? role;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  // -------------------------------------------------------
  // HTTP client (bypass self-signed SSL cert)
  // -------------------------------------------------------
  HttpClient _httpClient() {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => host == '124.222.82.196';
    return client;
  }

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth && token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Uri _uri(String path) => Uri.parse('$serverUrl$path');

  // -------------------------------------------------------
  // HTTP helpers
  // -------------------------------------------------------
  Future<Map<String, dynamic>> getJson(String path) async {
    final client = _httpClient();
    try {
      final req = await client.getUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<List<dynamic>> getJsonArray(String path) async {
    final client = _httpClient();
    try {
      final req = await client.getUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return [];
      return json.decode(body) as List<dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> data) async {
    final client = _httpClient();
    try {
      final req = await client.postUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      req.write(json.encode(data));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> data) async {
    final client = _httpClient();
    try {
      final req = await client.putUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      req.write(json.encode(data));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> data) async {
    final client = _httpClient();
    try {
      final req = await client.patchUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      req.write(json.encode(data));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<void> deleteResource(String path) async {
    final client = _httpClient();
    try {
      final req = await client.deleteUrl(_uri(path));
      _headers().forEach((k, v) => req.headers.set(k, v));
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        final body = await resp.transform(utf8.decoder).join();
        throw ApiException(resp.statusCode, body);
      }
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------
  // Auth
  // -------------------------------------------------------
  Future<Map<String, dynamic>> login(String user, String pass) async {
    final result = await postJson('/api/auth/login', {
      'username': user,
      'password': pass,
    });
    token = result['access_token'] as String?;
    if (token != null) {
      await _fetchCurrentUser();
    }
    return result;
  }

  Future<Map<String, dynamic>> registerUser(String user, String pass, String role,
      {String? studentNo, String? realName}) async {
    final body = <String, dynamic>{
      'username': user,
      'password': pass,
      'role': role,
    };
    if (studentNo != null && studentNo.isNotEmpty) {
      body['student_no'] = studentNo;
    }
    if (realName != null && realName.isNotEmpty) {
      body['real_name'] = realName;
    }
    return await postJson('/api/auth/register', body);
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final result = await getJson('/api/users/me');
      userUuid = result['uuid'] as String?;
      username = result['username'] as String?;
      role = result['role'] as String?;
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final result = await getJson('/api/users/me');
    userUuid = result['uuid'] as String?;
    username = result['username'] as String?;
    role = result['role'] as String?;
    return result;
  }

  void logout() {
    token = null;
    userUuid = null;
    username = null;
    role = null;
  }

  // -------------------------------------------------------
  // Courses
  // -------------------------------------------------------
  Future<List<dynamic>> listCourses() async {
    return await getJsonArray('/api/courses/');
  }

  Future<Map<String, dynamic>> createCourse(String name, String description) async {
    return await postJson('/api/courses/', {
      'name': name,
      'description': description,
    });
  }

  Future<Map<String, dynamic>> getCourseDetail(String courseUuid) async {
    return await getJson('/api/courses/$courseUuid');
  }

  Future<Map<String, dynamic>> updateCourse(String courseUuid,
      {String? name, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    return await patchJson('/api/courses/$courseUuid', body);
  }

  Future<void> deleteCourse(String courseUuid) async {
    await deleteResource('/api/courses/$courseUuid');
  }

  // -------------------------------------------------------
  // Course Members
  // -------------------------------------------------------
  Future<List<dynamic>> listMembers(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/members');
  }

  Future<Map<String, dynamic>> addMember(String courseUuid, String username_) async {
    return await postJson('/api/courses/$courseUuid/members', {
      'username': username_,
    });
  }

  Future<void> removeMember(String courseUuid, String userUuid_) async {
    await deleteResource('/api/courses/$courseUuid/members/$userUuid_');
  }

  // -------------------------------------------------------
  // Units
  // -------------------------------------------------------
  Future<Map<String, dynamic>> getCourseDetailWithUnits(String courseUuid) async {
    return await getJson('/api/courses/$courseUuid');
  }

  // -------------------------------------------------------
  // Scores
  // -------------------------------------------------------
  Future<Map<String, dynamic>> getScoreSummary(String courseUuid) async {
    return await getJson('/api/courses/$courseUuid/scores/summary');
  }

  Future<Map<String, dynamic>> getMyScores(String courseUuid) async {
    return await getJson('/api/courses/$courseUuid/scores/my');
  }

  Future<Map<String, dynamic>> upsertScore(
      String courseUuid, String studentUuid_, int unitId, double score) async {
    return await postJson('/api/courses/$courseUuid/scores/', {
      'student_uuid': studentUuid_,
      'unit_id': unitId,
      'score': score,
    });
  }

  // -------------------------------------------------------
  // Videos
  // -------------------------------------------------------
  Future<List<dynamic>> listVideos(String courseUuid) async {
    return await getJsonArray('/api/videos/course/$courseUuid');
  }

  Future<Map<String, dynamic>> getVideoDetail(String videoUuid) async {
    return await getJson('/api/videos/$videoUuid');
  }

  // -------------------------------------------------------
  // Play Records
  // -------------------------------------------------------
  Future<Map<String, dynamic>> updatePlayRecord(
      String videoUuid, int progress, bool completed) async {
    return await postJson('/api/play-records/update', {
      'video_uuid': videoUuid,
      'progress': progress,
      'completed': completed,
    });
  }

  Future<Map<String, dynamic>> getPlayRecord(String videoUuid) async {
    return await getJson('/api/play-records/$videoUuid');
  }

  // -------------------------------------------------------
  // Announcements
  // -------------------------------------------------------
  Future<List<dynamic>> listAnnouncements(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/announcements');
  }

  Future<Map<String, dynamic>> publishAnnouncement(
      String courseUuid, String title, String content,
      {String annType = '课程通知', bool pinned = false, bool notify = true}) async {
    return await postJson('/api/courses/$courseUuid/announcements', {
      'title': title,
      'content': content,
      'ann_type': annType,
      'pinned': pinned,
      'notify': notify,
    });
  }

  Future<void> deleteAnnouncement(String courseUuid, String announcementUuid) async {
    await deleteResource('/api/courses/$courseUuid/announcements/$announcementUuid');
  }

  // -------------------------------------------------------
  // Messages
  // -------------------------------------------------------
  Future<List<dynamic>> listMessages(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/messages');
  }

  Future<Map<String, dynamic>> sendMessage(
      String courseUuid, String content,
      {String msgType = '其他', String? subject, String? recipientUsername}) async {
    final body = <String, dynamic>{
      'content': content,
      'msg_type': msgType,
    };
    if (subject != null && subject.isNotEmpty) body['subject'] = subject;
    if (recipientUsername != null && recipientUsername.isNotEmpty) {
      body['recipient_username'] = recipientUsername;
    }
    return await postJson('/api/courses/$courseUuid/messages', body);
  }

  Future<void> markMessageRead(String courseUuid, String messageUuid) async {
    await putJson('/api/courses/$courseUuid/messages/$messageUuid/read', {});
  }

  Future<void> deleteMessage(String courseUuid, String messageUuid) async {
    await deleteResource('/api/courses/$courseUuid/messages/$messageUuid');
  }

  Future<List<dynamic>> fetchConversation(String courseUuid, String otherUserUuid) async {
    return await getJsonArray(
        '/api/courses/$courseUuid/messages/conversation/$otherUserUuid');
  }

  // -------------------------------------------------------
  // Attendance
  // -------------------------------------------------------
  Future<List<dynamic>> listAttendances(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/attendance');
  }

  Future<Map<String, dynamic>> startAttendance(String courseUuid, String title) async {
    return await postJson('/api/courses/$courseUuid/attendance', {
      'title': title,
    });
  }

  Future<Map<String, dynamic>> getAttendanceDetail(
      String courseUuid, String attendanceUuid) async {
    return await getJson('/api/courses/$courseUuid/attendance/$attendanceUuid');
  }

  Future<Map<String, dynamic>> markAttendance(
      String courseUuid, String attendanceUuid, String studentUuid_,
      String status, String? note) async {
    final body = <String, dynamic>{
      'student_uuid': studentUuid_,
      'status': status,
    };
    if (note != null && note.isNotEmpty) body['note'] = note;
    return await putJson(
        '/api/courses/$courseUuid/attendance/$attendanceUuid/mark', body);
  }

  Future<void> closeAttendance(String courseUuid, String attendanceUuid) async {
    await putJson(
        '/api/courses/$courseUuid/attendance/$attendanceUuid/close', {});
  }

  // -------------------------------------------------------
  // Batch Import
  // -------------------------------------------------------
  Future<Map<String, dynamic>> importStudents(
      String courseUuid, List<Map<String, dynamic>> students) async {
    final client = _httpClient();
    try {
      final req = await client.postUrl(_uri('/api/courses/$courseUuid/import-students'));
      _headers().forEach((k, v) => req.headers.set(k, v));
      req.write(json.encode(students));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------
  // Credential Persistence
  // -------------------------------------------------------
  Future<void> saveCredentials(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', user);
    await prefs.setString('saved_password', pass);
    await prefs.setBool('remember_me', true);
  }

  Future<bool> hasSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_username');
  }

  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_password');
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
  }

  Future<bool> tryAutoLogin() async {
    if (!await hasSavedCredentials()) return false;
    final user = await getSavedUsername();
    final pass = await getSavedPassword();
    if (user == null || pass == null || user.isEmpty || pass.isEmpty) return false;
    try {
      await login(user, pass);
      return isAuthenticated;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  String get message {
    try {
      final json = jsonDecode(body);
      return json['detail'] ?? body;
    } catch (_) {
      return body;
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
