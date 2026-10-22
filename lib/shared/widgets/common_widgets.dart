import 'package:flutter/material.dart';

import '../../core/network/api_service.dart';

// ---------- Nhãn trạng thái (luôn có icon + chữ, phong cách hiện đại) ----------

enum StatusTone { success, warning, danger, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.icon, this.tone = StatusTone.neutral});

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (textColor, bgColor) = switch (tone) {
      StatusTone.success => dark
          ? (const Color(0xFF34D399), const Color(0x26059669))
          : (const Color(0xFF047857), const Color(0xFFECFDF5)),
      StatusTone.warning => dark
          ? (const Color(0xFFFBBF24), const Color(0x26D97706))
          : (const Color(0xFFB45309), const Color(0xFFFFFBEB)),
      StatusTone.danger => dark
          ? (const Color(0xFFF87171), const Color(0x26DC2626))
          : (const Color(0xFFB91C1C), const Color(0xFFFEF2F2)),
      StatusTone.info => dark
          ? (const Color(0xFF60A5FA), const Color(0x262563EB))
          : (const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
      StatusTone.neutral => dark
          ? (const Color(0xFF94A3B8), const Color(0x26475569))
          : (const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

StatusChip leaveStatusChip(String status) {
  switch (status) {
    case 'Approved':
      return const StatusChip(label: 'Được duyệt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
    case 'Rejected':
      return const StatusChip(label: 'Từ chối', icon: Icons.cancel_rounded, tone: StatusTone.danger);
    default:
      return const StatusChip(label: 'Chờ duyệt', icon: Icons.schedule_rounded, tone: StatusTone.warning);
  }
}

// ---------- Avatar chữ cái đầu với Gradient nhận diện thương hiệu ----------

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 46});

  final String name;
  final double size;

  static const List<List<Color>> _gradientPresets = [
    [Color(0xFF1D4ED8), Color(0xFF3B82F6)], // Sapphire to Cobalt
    [Color(0xFF0369A1), Color(0xFF0EA5E9)], // Deep Sky to Tech Cyan
    [Color(0xFF4338CA), Color(0xFF6366F1)], // Deep Indigo to Violet
    [Color(0xFF0F766E), Color(0xFF14B8A6)], // Deep Teal to Mint
    [Color(0xFF1E3A8A), Color(0xFF2563EB)], // Royal Navy to Electric Blue
    [Color(0xFF047857), Color(0xFF10B981)], // Forest to Emerald
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // Tên tiếng Việt: lấy chữ cái đầu của tên (từ cuối cùng).
    final initial = words.isEmpty ? '?' : words.last.characters.first.toUpperCase();
    final gradientIndex = name.hashCode.abs() % _gradientPresets.length;
    final gradientColors = _gradientPresets[gradientIndex];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

// ---------- Trạng thái rỗng / lỗi / đang tải ----------

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2), width: 2),
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text('Thử lại'),
        ),
      ),
    );
  }
}

// Khung xương khi đang tải. Tắt hiệu ứng nhấp nháy nếu người dùng bật giảm chuyển động.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.4, upperBound: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.7;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        );
    return Semantics(
      label: 'Đang tải',
      child: FadeTransition(
        opacity: _controller,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color),
            ),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(160, 14), const SizedBox(height: 8), bar(100, 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Danh sách tải từ API: xử lý đang tải, lỗi, rỗng, kéo để làm mới ----------

class AsyncListView extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.headerBuilder,
    this.bottomPadding = 24,
  });

  final Future<List<Json>> future;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, Json item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget Function(List<Json> items)? headerBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Json>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SkeletonList();
        if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: () => onRefresh());
        final items = snap.data!;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
            children: [
              if (headerBuilder != null) ...[headerBuilder!(items), const SizedBox(height: 16)],
              if (items.isEmpty)
                EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
              else
                for (final item in items)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: itemBuilder(context, item)),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Thẻ bấm được ----------

class TapCard extends StatelessWidget {
  const TapCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? scheme.surfaceContainerLow : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: scheme.primary.withValues(alpha: 0.1),
          highlightColor: scheme.primary.withValues(alpha: 0.05),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// Một dòng thông tin nhỏ có icon, dùng trong thẻ.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color))),
        ],
      ),
    );
  }
}

// ---------- Hộp thoại dùng chung ----------

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

// Hiện hộp thoại chờ trong lúc chạy tác vụ, tự đóng khi xong (kể cả khi lỗi).
Future<T> runWithProgress<T>(BuildContext context, String message, Future<T> Function() task) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}

Future<void> showResultDialog(BuildContext context, {required bool success, required String title, required String message}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle_rounded : Icons.error_rounded,
        size: 56,
        color: success ? const Color(0xFF16A34A) : scheme.error,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
        ),
      ],
    ),
  );
}
