import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class MessagesPage extends StatefulWidget {
  final AuthProvider auth;
  const MessagesPage({super.key, required this.auth});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<dynamic> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final courses = await widget.auth.api.listCourses();
      final all = <Map<String, dynamic>>[];
      for (final c in courses) {
        try {
          final msgs =
              await widget.auth.api.listMessages(c['uuid'] as String);
          for (final m in msgs) {
            all.add({
              ...m as Map<String, dynamic>,
              'course_uuid': c['uuid'],
              'course_name': c['name'],
            });
          }
        } catch (_) {}
      }
      all.sort((a, b) {
        final da = a['created_at'] as String? ?? '';
        final db = b['created_at'] as String? ?? '';
        return db.compareTo(da);
      });
      if (mounted) {
        setState(() {
          _messages = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(r.hPadding, r.vPadding, r.hPadding, 0),
            child: Text('消息',
                style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
          ),
          SizedBox(height: r.clamped(12, 8, 16)),
          _buildSearchBar(context),
          SizedBox(height: r.clamped(12, 8, 16)),
          if (_loading)
            const Expanded(child: Center(child: FCircularProgress()))
          else
            Expanded(child: _buildConversationList(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: FTextField(
        hint: '搜索消息...',
        prefixBuilder: (context, style, _) =>
            Icon(FIcons.search, color: colors.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    if (_messages.isEmpty) {
      return Center(
        child: Text('暂无消息',
            style: AppTextStyles.scaled(
                AppTextStyles.caption, context.responsive.scale)),
      );
    }

    final grouped = <String, List<dynamic>>{};
    for (final m in _messages) {
      final sender = m['sender']?['username'] as String? ?? '系统';
      final key = '${m['course_uuid']}_$sender';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final conversations = grouped.entries.toList();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conversations.length,
      separatorBuilder: (_, _) {
        final r = context.responsive;
        return Divider(indent: r.clamped(76, 60, 90), endIndent: r.hPadding);
      },
      itemBuilder: (context, index) {
        final entry = conversations[index];
        final msgs = entry.value;
        final last = msgs.first;
        final unread =
            msgs.where((m) => (m['is_read'] as bool? ?? true) == false).length;
        final senderName =
            last['sender']?['username'] as String? ?? '系统';
        return ConversationTile(
          name: '${last['course_name']} - $senderName',
          lastMessage: last['content'] as String? ?? '',
          time: _formatTime(last['created_at'] as String?),
          unreadCount: unread,
          avatar: senderName.isNotEmpty ? senderName[0] : '系',
          onTap: () {
            final courseUuid = last['course_uuid'] as String;
            // Instantly mark as read locally so badge disappears
            for (final m in msgs) {
              m['is_read'] = true;
            }
            setState(() {});
            // Fire API calls in background
            for (final m in msgs) {
              widget.auth.api.markMessageRead(
                  courseUuid, m['uuid'] as String);
            }
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, a, b) => _ChatDetailScreen(
                  name: senderName,
                  courseUuid: courseUuid,
                  auth: widget.auth,
                ),
              ),
            ).then((_) => _loadMessages());
          },
        );
      },
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _ChatDetailScreen extends StatefulWidget {
  final String name;
  final String courseUuid;
  final AuthProvider auth;

  const _ChatDetailScreen({
    required this.name,
    required this.courseUuid,
    required this.auth,
  });

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _myUsername = widget.auth.username;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await widget.auth.api.listMessages(widget.courseUuid);
      if (mounted) {
        setState(() {
          _messages = msgs.reversed.toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    try {
      await widget.auth.api.sendMessage(widget.courseUuid, text);
      await _loadMessages();
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    return Container(
      color: colors.background,
      child: SafeArea(
        child: Column(
        children: [
          FHeader.nested(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FAvatar.raw(
                  size: r.clamped(28, 24, 36),
                  child: Container(
                    color: AppColors.primary,
                    alignment: Alignment.center,
                    child: Text(
                        widget.name.isNotEmpty ? widget.name[0] : '?',
                        style: const TextStyle(
                            color: Color(0xFFFFFFFF), fontSize: 12)),
                  ),
                ),
                SizedBox(width: r.clamped(8, 6, 10)),
                Text(widget.name),
              ],
            ),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: FCircularProgress())
                : _buildMessages(context),
          ),
          _buildInputBar(context),
        ],
      ),
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    if (_messages.isEmpty) {
      return Center(
        child: Text('暂无消息',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.all(r.hPadding),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final senderName = msg['sender']?['username'] as String? ?? '';
        final sent = senderName == _myUsername;
        final content = msg['content'] as String? ?? '';
        return Align(
          alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(bottom: r.clamped(12, 8, 16)),
            padding: EdgeInsets.symmetric(
              horizontal: r.clamped(14, 10, 18),
              vertical: r.clamped(10, 8, 12),
            ),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: sent ? AppColors.primary : colors.surfaceLight,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: sent ? const Radius.circular(16) : Radius.zero,
                bottomRight: sent ? Radius.zero : const Radius.circular(16),
              ),
              border: sent ? null : Border.all(color: colors.border),
            ),
            child: Text(
              content,
              style: TextStyle(
                  color: sent
                      ? const Color(0xFFFFFFFF)
                      : colors.text,
                  fontSize: r.clamped(14, 12, 16)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.clamped(12, 8, 16),
          vertical: r.clamped(10, 8, 12)),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: FTextField(
                control: FTextFieldControl.managed(controller: _msgCtrl),
                hint: '输入消息...',
              ),
            ),
            SizedBox(width: r.clamped(8, 6, 10)),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: r.clamped(40, 34, 46),
                height: r.clamped(40, 34, 46),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(r.clamped(20, 17, 23)),
                ),
                child: Icon(FIcons.send,
                    color: const Color(0xFFFFFFFF),
                    size: r.clamped(18, 16, 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
