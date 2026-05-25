class UserModel {
  final String uuid;
  final String username;
  final String role;
  final String? studentNo;
  final String? realName;

  UserModel({
    required this.uuid,
    required this.username,
    required this.role,
    this.studentNo,
    this.realName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uuid: json['uuid'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      studentNo: json['student']?['student_no'] as String?,
      realName: json['student']?['real_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'username': username,
        'role': role,
      };

  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
}
