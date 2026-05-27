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
      final headers = _headers();
      for (final entry in headers.entries) {
        req.headers.set(entry.key, entry.value);
      }
      final bytes = utf8.encode(json.encode(data));
      req.add(bytes);
      final resp = await req.close();
      final bodyBytes = await resp.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final body = utf8.decode(bodyBytes);
      if (resp.statusCode >= 400) {
        throw ApiException(resp.statusCode, body);
      }
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// POST to an SSE streaming endpoint, accumulate all tokens into final result.
  /// Returns the same shape as the old JSON endpoint: {content, model}.
  Future<Map<String, dynamic>> postJsonStream(String path, Map<String, dynamic> data) async {
    final client = _httpClient();
    try {
      final req = await client.postUrl(_uri(path));
      final headers = _headers();
      // Accept SSE
      req.headers.set('Accept', 'text/event-stream');
      for (final entry in headers.entries) {
        req.headers.set(entry.key, entry.value);
      }
      req.add(utf8.encode(json.encode(data)));
      final resp = await req.close();

      if (resp.statusCode >= 400) {
        final bodyBytes = await resp.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        final body = utf8.decode(bodyBytes);
        throw ApiException(resp.statusCode, body);
      }

      final contentBuffer = StringBuffer();
      var model = '';
      var hasError = false;
      var errorMsg = '';

      var buffer = '';
      await for (final chunk in resp.transform(utf8.decoder)) {
        buffer += chunk;
        // Normalize \r\n → \n for cross-platform SSE parsing
        buffer = buffer.replaceAll('\r\n', '\n');
        // SSE frames are separated by \n\n
        while (true) {
          final idx = buffer.indexOf('\n\n');
          if (idx == -1) break;
          final frame = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          for (final line in frame.split('\n')) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data: ')) continue;
            final jsonStr = trimmed.substring(6);
            try {
              final obj = json.decode(jsonStr) as Map<String, dynamic>;
              if (obj.containsKey('error')) {
                hasError = true;
                errorMsg = obj['error'] as String? ?? 'Unknown streaming error';
              } else if (obj.containsKey('token')) {
                contentBuffer.write(obj['token'] as String? ?? '');
              } else if (obj.containsKey('done')) {
                model = obj['model'] as String? ?? '';
              }
            } catch (_) {}
          }
        }
      }

      if (hasError) {
        throw ApiException(502, errorMsg);
      }

      return {
        'content': contentBuffer.toString(),
        'model': model,
      };
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

  Future<Map<String, dynamic>> updateMe({String? username}) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    return await patchJson('/api/users/me', body);
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

  String getVideoDownloadUrl(String videoUuid, {bool watermark = false}) {
    final t = token ?? '';
    final wm = watermark ? '&watermark=true' : '';
    return '$serverUrl/api/videos/$videoUuid/download?token=$t$wm';
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

  Future<List<dynamic>> getMyCoursePlayRecords(String courseUuid) async {
    return await getJsonArray('/api/play-records/course/$courseUuid/my');
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
  // Resources
  // -------------------------------------------------------
  Future<List<dynamic>> listResources(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/resources');
  }

  String getResourceDownloadUrl(String courseUuid, String resourceUuid) {
    final t = token ?? '';
    return '$serverUrl/api/courses/$courseUuid/resources/$resourceUuid/download?token=$t';
  }

  Future<Map<String, dynamic>> generateLearningReport(String learningData) async {
    return await postJsonStream('/api/ai/learning-report', {
      'learning_data': learningData,
    });
  }

  Future<Map<String, dynamic>> analyzeStudent(String studentData) async {
    return await postJsonStream('/api/ai/student-analysis', {
      'student_data': studentData,
    });
  }

  /// Download a file from the given URL to [savePath].
  /// Uses HttpClient with SSL bypass + Authorization header.
  /// Checks HTTP status; throws [ApiException] on failure.
  Future<void> downloadToFile(String url, String savePath,
      {void Function(int received, int total)? onProgress}) async {
    final client = _httpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      if (token != null) {
        req.headers.set('Authorization', 'Bearer $token');
      }
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        final body = await resp.transform(utf8.decoder).join();
        throw ApiException(resp.statusCode, body);
      }
      final total = resp.contentLength;
      var received = 0;
      final file = File(savePath);
      final sink = file.openWrite();
      await for (final chunk in resp) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  Future<void> deleteCourseResource(String courseUuid, String resourceUuid) async {
    await deleteResource('/api/courses/$courseUuid/resources/$resourceUuid');
  }

  Future<Map<String, dynamic>> uploadResource(
      String courseUuid, String filePath, String fileName,
      {String title = '', String description = ''}) async {
    final client = _httpClient();
    try {
      final uri = _uri('/api/courses/$courseUuid/resources');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/json');

      final bytes = await File(filePath).readAsBytes();
      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

      final parts = <List<int>>[];
      void addField(String name, String value) {
        parts.add(utf8.encode('--$boundary\r\n'));
        parts.add(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
        parts.add(utf8.encode('$value\r\n'));
      }

      addField('title', title.isNotEmpty ? title : fileName);
      if (description.isNotEmpty) addField('description', description);

      parts.add(utf8.encode('--$boundary\r\n'));
      parts.add(utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="$fileName"\r\n'));
      parts.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
      parts.add(bytes);
      parts.add(utf8.encode('\r\n--$boundary--\r\n'));

      for (final part in parts) {
        request.add(part);
      }

      final resp = await request.close();
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
  // Assignments
  // -------------------------------------------------------
  Future<Map<String, dynamic>> createAssignment(
      String courseUuid, Map<String, dynamic> data) async {
    return await postJson('/api/courses/$courseUuid/assignments', data);
  }

  Future<List<dynamic>> listAssignments(String courseUuid) async {
    return await getJsonArray('/api/courses/$courseUuid/assignments');
  }

  Future<Map<String, dynamic>> getAssignmentDetail(
      String courseUuid, String assignmentUuid) async {
    return await getJson(
        '/api/courses/$courseUuid/assignments/$assignmentUuid');
  }

  Future<Map<String, dynamic>> submitHomework(
      String courseUuid, String assignmentUuid,
      {String content = '', String? filePath, String? fileName}) async {
    final client = _httpClient();
    try {
      final uri = _uri(
          '/api/courses/$courseUuid/assignments/$assignmentUuid/submissions');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/json');

      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
          'Content-Type', 'multipart/form-data; boundary=$boundary');

      final parts = <List<int>>[];
      void addField(String name, String value) {
        parts.add(utf8.encode('--$boundary\r\n'));
        parts.add(utf8.encode(
            'Content-Disposition: form-data; name="$name"\r\n\r\n'));
        parts.add(utf8.encode('$value\r\n'));
      }

      if (content.isNotEmpty) {
        addField('content', content);
      }

      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fName = fileName ?? filePath.split('/').last;
          parts.add(utf8.encode('--$boundary\r\n'));
          parts.add(utf8.encode(
              'Content-Disposition: form-data; name="file"; filename="$fName"\r\n'));
          parts.add(utf8.encode(
              'Content-Type: application/octet-stream\r\n\r\n'));
          parts.add(bytes);
          parts.add(utf8.encode('\r\n'));
        }
      }

      parts.add(utf8.encode('--$boundary--\r\n'));

      for (final part in parts) {
        request.add(part);
      }

      final resp = await request.close();
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

  Future<dynamic> getMySubmission(
      String courseUuid, String assignmentUuid) async {
    return await getJson(
        '/api/courses/$courseUuid/assignments/$assignmentUuid/submissions/my');
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
    await postJson('/api/courses/$courseUuid/messages/$messageUuid/read', {});
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

  Future<Map<String, dynamic>> startAttendance(
      String courseUuid, String title, {String mode = 'simple'}) async {
    return await postJson('/api/courses/$courseUuid/attendance', {
      'title': title,
      'mode': mode,
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

  Future<Map<String, dynamic>> checkIn(
      String courseUuid, String attendanceUuid) async {
    return await postJson(
        '/api/courses/$courseUuid/attendance/$attendanceUuid/check-in', {});
  }

  Future<Map<String, dynamic>> checkInWithPhoto(
      String courseUuid, String attendanceUuid, String filePath) async {
    final client = _httpClient();
    try {
      final uri = _uri(
          '/api/courses/$courseUuid/attendance/$attendanceUuid/check-in-photo');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/json');

      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
          'Content-Type', 'multipart/form-data; boundary=$boundary');

      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException(400, 'File not found');
      }

      final bytes = await file.readAsBytes();
      final fName = filePath.split('/').last;

      final parts = <List<int>>[];
      parts.add(utf8.encode('--$boundary\r\n'));
      parts.add(utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="$fName"\r\n'));
      parts.add(utf8.encode(
          'Content-Type: image/jpeg\r\n\r\n'));
      parts.add(bytes);
      parts.add(utf8.encode('\r\n'));
      parts.add(utf8.encode('--$boundary--\r\n'));

      for (final part in parts) {
        request.add(part);
      }

      final resp = await request.close();
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
  // AI Chat
  // -------------------------------------------------------
  Future<Map<String, dynamic>> aiChat(List<Map<String, String>> messages) async {
    return await postJson('/api/ai/chat', {'messages': messages});
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
