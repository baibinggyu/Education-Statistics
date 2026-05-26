class Assignment {
  final String uuid;
  final String title;
  final String? description;
  final String? dueDate;
  final double? totalPoints;
  final bool hasAttachment;
  final String? attachmentName;
  final String status;
  final String? authorName;
  final int submissionCount;
  final String? createdAt;

  Assignment({
    required this.uuid,
    required this.title,
    this.description,
    this.dueDate,
    this.totalPoints,
    this.hasAttachment = false,
    this.attachmentName,
    this.status = 'open',
    this.authorName,
    this.submissionCount = 0,
    this.createdAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      uuid: json['uuid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dueDate: json['due_date'] as String?,
      totalPoints: (json['total_points'] as num?)?.toDouble(),
      hasAttachment: json['has_attachment'] as bool? ?? false,
      attachmentName: json['attachment_name'] as String?,
      status: json['status'] as String? ?? 'open',
      authorName: json['author']?['username'] as String?,
      submissionCount: json['submission_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}

class Submission {
  final String uuid;
  final String assignmentUuid;
  final String studentUuid;
  final String studentName;
  final String? studentNo;
  final String? content;
  final String? fileName;
  final String? submittedAt;
  final double? score;
  final String? feedback;
  final String status;

  Submission({
    required this.uuid,
    required this.assignmentUuid,
    required this.studentUuid,
    required this.studentName,
    this.studentNo,
    this.content,
    this.fileName,
    this.submittedAt,
    this.score,
    this.feedback,
    this.status = 'draft',
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      uuid: json['uuid'] as String? ?? '',
      assignmentUuid: json['assignment_uuid'] as String? ?? '',
      studentUuid: json['student_uuid'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      studentNo: json['student_no'] as String?,
      content: json['content'] as String?,
      fileName: json['file_name'] as String?,
      submittedAt: json['submitted_at'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      status: json['status'] as String? ?? 'draft',
    );
  }

  bool get isGraded => status == 'graded';
  bool get isSubmitted => status == 'submitted' || status == 'late' || status == 'graded';
}
