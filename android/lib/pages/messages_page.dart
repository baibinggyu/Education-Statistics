import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.hPadding, r.vPadding, r.hPadding, 0),
              child: Text('消息', style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
            ),
            SizedBox(height: r.clamped(12, 8, 16)),
            _buildSearchBar(context),
            SizedBox(height: r.clamped(12, 8, 16)),
            Expanded(child: _buildConversationList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索消息...',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    final conversations = <Map<String, dynamic>>[
      {'name': '王教授', 'last': '同学们，下周一的课记得预习第三章', 'time': '10:32', 'unread': 2, 'avatar': '王'},
      {'name': '课程助手', 'last': '您有一份新的作业待提交', 'time': '昨天', 'unread': 1, 'avatar': '助'},
      {'name': '李老师', 'last': '好的，有问题随时联系我', 'time': '昨天', 'unread': 0, 'avatar': '李'},
      {'name': '班级群 · 电子技术', 'last': '张三：实验报告模板已上传', 'time': '周一', 'unread': 5, 'avatar': '群'},
      {'name': '张教授', 'last': '期中考试成绩已公布，请查看', 'time': '周日', 'unread': 0, 'avatar': '张'},
      {'name': '赵教授', 'last': '教学计划更新通知', 'time': '周六', 'unread': 0, 'avatar': '赵'},
      {'name': '学习小组', 'last': '刘：周五讨论第三章的习题', 'time': '周五', 'unread': 3, 'avatar': '组'},
      {'name': '陈老师', 'last': '实验安排有调整，请看通知', 'time': '周四', 'unread': 0, 'avatar': '陈'},
    ];

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conversations.length,
      separatorBuilder: (_, _) {
        final r = context.responsive;
        return Divider(indent: r.clamped(76, 60, 90), endIndent: r.hPadding);
      },
      itemBuilder: (context, index) {
        final c = conversations[index];
        return ConversationTile(
          name: c['name'] as String,
          lastMessage: c['last'] as String,
          time: c['time'] as String,
          unreadCount: c['unread'] as int,
          avatar: c['avatar'] as String,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => _ChatDetailScreen(name: c['name'] as String),
            ));
          },
        );
      },
    );
  }
}

class _ChatDetailScreen extends StatelessWidget {
  final String name;
  const _ChatDetailScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: r.clamped(14, 12, 18),
              backgroundColor: AppColors.primary,
              child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            SizedBox(width: r.clamped(8, 6, 10)),
            Text(name),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(context)),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final r = context.responsive;
    final messages = [
      {'text': '老师好，请问第三章的实验报告什么时候交？', 'sent': true},
      {'text': '下周五之前提交就可以，有什么不懂的随时来问我。', 'sent': false},
      {'text': '好的，谢谢老师！那实验数据需要用什么格式提交？', 'sent': true},
      {'text': '用PDF格式提交，实验数据可以附在报告末尾。如果数据量大，可以打包成zip。', 'sent': false},
      {'text': '明白了，谢谢老师！', 'sent': true},
    ];

    return ListView.builder(
      padding: EdgeInsets.all(r.hPadding),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final sent = msg['sent'] as bool;
        return Align(
          alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(bottom: r.clamped(12, 8, 16)),
            padding: EdgeInsets.symmetric(
              horizontal: r.clamped(14, 10, 18),
              vertical: r.clamped(10, 8, 12),
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: sent ? AppColors.primary : Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: sent ? const Radius.circular(16) : Radius.zero,
                bottomRight: sent ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Text(
              msg['text'] as String,
              style: TextStyle(color: sent ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: r.clamped(14, 12, 16)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final r = context.responsive;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.clamped(12, 8, 16), vertical: r.clamped(10, 8, 12)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: theme.textTheme.bodySmall?.color ?? AppColors.textSecondary, size: r.clamped(26, 22, 30)),
            SizedBox(width: r.clamped(8, 6, 10)),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(width: r.clamped(8, 6, 10)),
            Container(
              width: r.clamped(40, 34, 46),
              height: r.clamped(40, 34, 46),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(r.clamped(20, 17, 23)),
              ),
              child: Icon(Icons.send, color: Colors.white, size: r.clamped(18, 16, 20)),
            ),
          ],
        ),
      ),
    );
  }
}
