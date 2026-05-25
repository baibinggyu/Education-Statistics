class MessageModel {
  final String uuid;
  final String? subject;
  final String content;
  final String msgType;
  final bool isRead;
  final String? senderName;
  final String? recipientName;
  final String? createdAt;

  MessageModel({
    required this.uuid,
    this.subject,
    required this.content,
    required this.msgType,
    this.isRead = false,
    this.senderName,
    this.recipientName,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      uuid: json['uuid'] as String,
      subject: json['subject'] as String?,
      content: json['content'] as String,
      msgType: json['msg_type'] as String? ?? '其他',
      isRead: json['is_read'] as bool? ?? false,
      senderName: json['sender']?['username'] as String?,
      recipientName: json['recipient']?['username'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
