class ScoreSummaryModel {
  final String courseName;
  final List<String> unitNames;
  final List<double> unitWeights;
  final List<ScoreStudentModel> students;

  ScoreSummaryModel({
    required this.courseName,
    required this.unitNames,
    required this.unitWeights,
    required this.students,
  });

  factory ScoreSummaryModel.fromJson(Map<String, dynamic> json) {
    return ScoreSummaryModel(
      courseName: json['course_name'] as String,
      unitNames: (json['unit_names'] as List).cast<String>(),
      unitWeights: (json['unit_weights'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      students: (json['students'] as List)
          .map((e) => ScoreStudentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ScoreStudentModel {
  final String studentUuid;
  final String studentNo;
  final String realName;
  final List<double?> scores;
  final double? weightedTotal;
  final int? rank;

  ScoreStudentModel({
    required this.studentUuid,
    required this.studentNo,
    required this.realName,
    required this.scores,
    this.weightedTotal,
    this.rank,
  });

  factory ScoreStudentModel.fromJson(Map<String, dynamic> json) {
    return ScoreStudentModel(
      studentUuid: json['student_uuid'] as String,
      studentNo: json['student_no'] as String,
      realName: json['real_name'] as String,
      scores: (json['scores'] as List)
          .map((e) => e != null ? (e as num).toDouble() : null)
          .toList(),
      weightedTotal: (json['weighted_total'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
    );
  }
}

class AttendanceModel {
  final String uuid;
  final String title;
  final String status;
  final int total;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final String? createdAt;

  AttendanceModel({
    required this.uuid,
    required this.title,
    required this.status,
    this.total = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.leaveCount = 0,
    this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'open',
      total: json['total'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      leaveCount: json['leave_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}
