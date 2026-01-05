import 'package:flutter/material.dart';

/// Unified status badge for orders, bookings, and items.
/// Consolidates duplicate status display implementations.
class StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final bool showIcon;
  final bool filled;
  final EdgeInsets? padding;

  const StatusBadge({
    super.key,
    required this.status,
    required this.color,
    this.icon,
    this.fontSize = 12,
    this.showIcon = true,
    this.filled = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: fontSize + 2,
              color: filled ? Colors.white : color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  // ============ Order Status Factories ============

  /// Pending status
  factory StatusBadge.pending({bool showIcon = true}) {
    return StatusBadge(
      status: 'Pending',
      color: const Color(0xFFFFA726),
      icon: Icons.schedule,
      showIcon: showIcon,
    );
  }

  /// Confirmed status
  factory StatusBadge.confirmed({bool showIcon = true}) {
    return StatusBadge(
      status: 'Confirmed',
      color: const Color(0xFF42A5F5),
      icon: Icons.check_circle_outline,
      showIcon: showIcon,
    );
  }

  /// Processing/In Progress status
  factory StatusBadge.processing({String? label, bool showIcon = true}) {
    return StatusBadge(
      status: label ?? 'Processing',
      color: const Color(0xFF7E57C2),
      icon: Icons.sync,
      showIcon: showIcon,
    );
  }

  /// Ready status
  factory StatusBadge.ready({String? label, bool showIcon = true}) {
    return StatusBadge(
      status: label ?? 'Ready',
      color: const Color(0xFF26A69A),
      icon: Icons.inventory_2,
      showIcon: showIcon,
    );
  }

  /// Completed status
  factory StatusBadge.completed({String? label, bool showIcon = true}) {
    return StatusBadge(
      status: label ?? 'Completed',
      color: const Color(0xFF66BB6A),
      icon: Icons.check_circle,
      showIcon: showIcon,
    );
  }

  /// Cancelled status
  factory StatusBadge.cancelled({bool showIcon = true}) {
    return StatusBadge(
      status: 'Cancelled',
      color: const Color(0xFFEF5350),
      icon: Icons.cancel,
      showIcon: showIcon,
    );
  }

  /// Rejected status
  factory StatusBadge.rejected({bool showIcon = true}) {
    return StatusBadge(
      status: 'Rejected',
      color: const Color(0xFFE53935),
      icon: Icons.block,
      showIcon: showIcon,
    );
  }

  /// Refunded status
  factory StatusBadge.refunded({bool showIcon = true}) {
    return StatusBadge(
      status: 'Refunded',
      color: const Color(0xFF78909C),
      icon: Icons.replay,
      showIcon: showIcon,
    );
  }

  // ============ Item Status Factories ============

  /// Active/Available status
  factory StatusBadge.active({bool showIcon = true}) {
    return StatusBadge(
      status: 'Active',
      color: const Color(0xFF66BB6A),
      icon: Icons.visibility,
      showIcon: showIcon,
    );
  }

  /// Inactive/Unavailable status
  factory StatusBadge.inactive({bool showIcon = true}) {
    return StatusBadge(
      status: 'Inactive',
      color: const Color(0xFF78909C),
      icon: Icons.visibility_off,
      showIcon: showIcon,
    );
  }

  /// Out of stock status
  factory StatusBadge.outOfStock({bool showIcon = true}) {
    return StatusBadge(
      status: 'Out of Stock',
      color: const Color(0xFFEF5350),
      icon: Icons.inventory_2_outlined,
      showIcon: showIcon,
    );
  }

  /// Low stock status
  factory StatusBadge.lowStock({int? quantity, bool showIcon = true}) {
    return StatusBadge(
      status: quantity != null ? 'Low Stock ($quantity)' : 'Low Stock',
      color: const Color(0xFFFFA726),
      icon: Icons.warning_amber_outlined,
      showIcon: showIcon,
    );
  }

  /// In stock status
  factory StatusBadge.inStock({int? quantity, bool showIcon = true}) {
    return StatusBadge(
      status: quantity != null ? 'In Stock ($quantity)' : 'In Stock',
      color: const Color(0xFF66BB6A),
      icon: Icons.check_circle_outline,
      showIcon: showIcon,
    );
  }

  // ============ Room/Booking Status Factories ============

  /// Available room status
  factory StatusBadge.available({bool showIcon = true}) {
    return StatusBadge(
      status: 'Available',
      color: const Color(0xFF66BB6A),
      icon: Icons.event_available,
      showIcon: showIcon,
    );
  }

  /// Occupied room status
  factory StatusBadge.occupied({bool showIcon = true}) {
    return StatusBadge(
      status: 'Occupied',
      color: const Color(0xFFEF5350),
      icon: Icons.event_busy,
      showIcon: showIcon,
    );
  }

  /// Reserved status
  factory StatusBadge.reserved({bool showIcon = true}) {
    return StatusBadge(
      status: 'Reserved',
      color: const Color(0xFFFFA726),
      icon: Icons.event,
      showIcon: showIcon,
    );
  }

  /// Checked In status
  factory StatusBadge.checkedIn({bool showIcon = true}) {
    return StatusBadge(
      status: 'Checked In',
      color: const Color(0xFF42A5F5),
      icon: Icons.login,
      showIcon: showIcon,
    );
  }

  /// Checked Out status
  factory StatusBadge.checkedOut({bool showIcon = true}) {
    return StatusBadge(
      status: 'Checked Out',
      color: const Color(0xFF66BB6A),
      icon: Icons.logout,
      showIcon: showIcon,
    );
  }

  // ============ Payment Status Factories ============

  /// Paid status
  factory StatusBadge.paid({bool showIcon = true}) {
    return StatusBadge(
      status: 'Paid',
      color: const Color(0xFF66BB6A),
      icon: Icons.payment,
      showIcon: showIcon,
    );
  }

  /// Unpaid status
  factory StatusBadge.unpaid({bool showIcon = true}) {
    return StatusBadge(
      status: 'Unpaid',
      color: const Color(0xFFEF5350),
      icon: Icons.money_off,
      showIcon: showIcon,
    );
  }

  /// Partial payment status
  factory StatusBadge.partialPayment({bool showIcon = true}) {
    return StatusBadge(
      status: 'Partial',
      color: const Color(0xFFFFA726),
      icon: Icons.payments_outlined,
      showIcon: showIcon,
    );
  }

  // ============ Generic Factory from String ============

  /// Create badge from status string
  factory StatusBadge.fromString(String status, {bool showIcon = true}) {
    final lowerStatus = status.toLowerCase().replaceAll('_', ' ').trim();

    switch (lowerStatus) {
      // Order statuses
      case 'pending':
      case 'new':
        return StatusBadge.pending(showIcon: showIcon);
      case 'confirmed':
      case 'accepted':
        return StatusBadge.confirmed(showIcon: showIcon);
      case 'preparing':
      case 'processing':
      case 'in progress':
        return StatusBadge.processing(showIcon: showIcon);
      case 'ready':
      case 'packed':
      case 'shipped':
        return StatusBadge.ready(showIcon: showIcon);
      case 'completed':
      case 'delivered':
        return StatusBadge.completed(showIcon: showIcon);
      case 'cancelled':
        return StatusBadge.cancelled(showIcon: showIcon);
      case 'rejected':
        return StatusBadge.rejected(showIcon: showIcon);
      case 'refunded':
        return StatusBadge.refunded(showIcon: showIcon);

      // Item statuses
      case 'active':
        return StatusBadge.active(showIcon: showIcon);
      case 'inactive':
        return StatusBadge.inactive(showIcon: showIcon);
      case 'out of stock':
        return StatusBadge.outOfStock(showIcon: showIcon);
      case 'low stock':
        return StatusBadge.lowStock(showIcon: showIcon);
      case 'in stock':
        return StatusBadge.inStock(showIcon: showIcon);

      // Room/Booking statuses
      case 'available':
        return StatusBadge.available(showIcon: showIcon);
      case 'occupied':
        return StatusBadge.occupied(showIcon: showIcon);
      case 'reserved':
        return StatusBadge.reserved(showIcon: showIcon);
      case 'checked in':
        return StatusBadge.checkedIn(showIcon: showIcon);
      case 'checked out':
        return StatusBadge.checkedOut(showIcon: showIcon);

      // Payment statuses
      case 'paid':
        return StatusBadge.paid(showIcon: showIcon);
      case 'unpaid':
        return StatusBadge.unpaid(showIcon: showIcon);
      case 'partial':
        return StatusBadge.partialPayment(showIcon: showIcon);

      default:
        // Default grey badge for unknown status
        return StatusBadge(
          status: _capitalizeFirst(status),
          color: const Color(0xFF78909C),
          icon: Icons.info_outline,
          showIcon: showIcon,
        );
    }
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Compact status indicator (just a colored dot)
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool animate;

  const StatusDot({
    super.key,
    required this.color,
    this.size = 8,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: animate
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  factory StatusDot.online() => const StatusDot(color: Color(0xFF66BB6A));
  factory StatusDot.offline() => const StatusDot(color: Color(0xFF78909C));
  factory StatusDot.busy() => const StatusDot(color: Color(0xFFEF5350));
  factory StatusDot.away() => const StatusDot(color: Color(0xFFFFA726));
}

/// Status badge with text underneath
class StatusBadgeWithLabel extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadgeWithLabel({
    super.key,
    required this.status,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusBadge(
          status: status,
          color: color,
          icon: icon,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Status timeline item
class StatusTimelineItem extends StatelessWidget {
  final String status;
  final String? time;
  final Color color;
  final IconData icon;
  final bool isActive;
  final bool isLast;

  const StatusTimelineItem({
    super.key,
    required this.status,
    this.time,
    required this.color,
    required this.icon,
    this.isActive = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isActive ? color : (isDarkMode ? Colors.white24 : Colors.grey[300]!);

    return Row(
      children: [
        // Timeline line and dot
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activeColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: activeColor,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: activeColor.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? (isDarkMode ? Colors.white : Colors.black87)
                      : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                ),
              ),
              if (time != null)
                Text(
                  time!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
