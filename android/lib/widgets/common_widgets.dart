import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

/// Glass-style card with subtle border and background
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding ?? EdgeInsets.all(r.hPadding),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius ?? r.radius),
          border: Border.all(color: theme.dividerColor),
        ),
        child: child,
      ),
    );
  }
}

/// Stat card showing a title and value (centered)
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return GlassCard(
      radius: 14,
      padding: EdgeInsets.symmetric(vertical: r.clamped(16, 12, 22), horizontal: r.clamped(12, 8, 18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: r.clamped(24, 20, 30), color: AppColors.primary),
            SizedBox(height: r.clamped(8, 6, 10)),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: r.clamped(22, 18, 28),
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: r.clamped(4, 2, 6)),
          Text(
            title,
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Section header with optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(8, 6, 12)),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: r.clamped(13, 11, 15),
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Course card for the course grid
class CourseCard extends StatelessWidget {
  final String title;
  final String teacher;
  final String category;
  final double progress;
  final Color coverColor;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.title,
    required this.teacher,
    required this.category,
    this.progress = 0.0,
    this.coverColor = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return GlassCard(
      radius: 14,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: r.clamped(94, 80, 130),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(
                colors: [coverColor.withAlpha(204), coverColor.withAlpha(77)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(Icons.school, size: r.clamped(40, 32, 48), color: Colors.white.withAlpha(204)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(r.clamped(10, 6, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: r.clamped(3, 1, 6)),
                Text('$category · $teacher', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (progress > 0) ...[
                  SizedBox(height: r.clamped(8, 4, 14)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      minHeight: r.clamped(4, 3, 5),
                    ),
                  ),
                  SizedBox(height: r.clamped(3, 1, 6)),
                  Text('${(progress * 100).toInt()}%', style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conversation list tile for messages
class ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String avatar;
  final VoidCallback? onTap;

  const ConversationTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.avatar = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final avatarRadius = r.clamped(24, 20, 30);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(6, 4, 8)),
      leading: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: AppColors.primary,
        child: Text(
          avatar.isNotEmpty ? avatar : name[0],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: r.clamped(16, 14, 20),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(name, style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale))),
          Text(time, style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(lastMessage, style: AppTextStyles.scaled(AppTextStyles.caption, r.scale), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (unreadCount > 0)
            Container(
              margin: EdgeInsets.only(left: r.clamped(8, 4, 10)),
              padding: EdgeInsets.symmetric(horizontal: r.clamped(7, 5, 9), vertical: r.clamped(2, 1, 3)),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.clamped(10, 9, 12),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Badge chip for labels (pinned, categories, statuses)
class BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const BadgeChip({
    super.key,
    required this.label,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.clamped(8, 6, 10), vertical: r.clamped(3, 2, 4)),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: r.clamped(10, 9, 12),
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
