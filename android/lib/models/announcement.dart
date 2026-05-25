class AnnouncementModel {
  final String uuid;
  final String title;
  final String content;
  final String annType;
  final bool pinned;
  final String? authorName;
  final String? createdAt;

  AnnouncementModel({
    required this.uuid,
    required this.title,
    required this.content,
    required this.annType,
    this.pinned = false,
    this.authorName,
    this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      annType: json['ann_type'] as String? ?? '课程通知',
      pinned: json['pinned'] as bool? ?? false,
      authorName: json['author']?['username'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
