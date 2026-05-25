class CourseModel {
  final String uuid;
  final String name;
  final String? description;
  final String? teacherName;
  final String status;
  final int memberCount;
  final int videoCount;
  final String? myRole;

  CourseModel({
    required this.uuid,
    required this.name,
    this.description,
    this.teacherName,
    required this.status,
    this.memberCount = 0,
    this.videoCount = 0,
    this.myRole,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      teacherName: json['teacher']?['username'] as String?,
      status: json['status'] as String? ?? 'normal',
      memberCount: json['member_count'] as int? ?? 0,
      videoCount: json['video_count'] as int? ?? 0,
      myRole: json['my_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'status': status,
      };
}

class CourseMemberModel {
  final String userUuid;
  final String username;
  final String memberRole;
  final String? studentNo;
  final String? realName;

  CourseMemberModel({
    required this.userUuid,
    required this.username,
    required this.memberRole,
    this.studentNo,
    this.realName,
  });

  factory CourseMemberModel.fromJson(Map<String, dynamic> json) {
    return CourseMemberModel(
      userUuid: json['user_uuid'] as String,
      username: json['username'] as String,
      memberRole: json['member_role'] as String,
      studentNo: json['student']?['student_no'] as String?,
      realName: json['student']?['real_name'] as String?,
    );
  }
}

class UnitModel {
  final int id;
  final String name;
  final double weight;
  final double fullScore;
  final int unitOrder;

  UnitModel({
    required this.id,
    required this.name,
    this.weight = 0,
    this.fullScore = 100,
    this.unitOrder = 0,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] as int,
      name: json['name'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      fullScore: (json['full_score'] as num?)?.toDouble() ?? 100,
      unitOrder: json['unit_order'] as int? ?? 0,
    );
  }
}

class VideoModel {
  final String uuid;
  final String title;
  final int duration;
  final int fileSize;
  final bool hasCover;
  final String status;

  VideoModel({
    required this.uuid,
    required this.title,
    this.duration = 0,
    this.fileSize = 0,
    this.hasCover = false,
    this.status = 'normal',
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      duration: json['duration'] as int? ?? 0,
      fileSize: json['file_size'] as int? ?? 0,
      hasCover: json['has_cover'] as bool? ?? false,
      status: json['status'] as String? ?? 'normal',
    );
  }
}
