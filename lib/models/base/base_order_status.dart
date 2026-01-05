import 'package:flutter/material.dart';
import '../../utils/currency_utils.dart';

/// Base class for all order/booking status enums.
/// Provides common status properties and helper methods.
abstract class BaseOrderStatus {
  /// Display name for UI
  String get displayName;

  /// Value stored in database
  String get value;

  /// Status color for badges/indicators
  Color get color;

  /// Status icon
  IconData get icon;

  /// Whether this is a final/terminal state
  bool get isFinal;

  /// Whether this status indicates success
  bool get isSuccess;

  /// Whether this status indicates failure/cancellation
  bool get isFailure;

  /// Whether the order is still in progress
  bool get isInProgress => !isFinal;

  /// Parse status from string
  static T? fromString<T extends BaseOrderStatus>(
    String? value,
    List<T> values,
  ) {
    if (value == null) return null;
    try {
      return values.firstWhere((s) => s.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// Common order status colors
class OrderStatusColors {
  static const Color pending = Color(0xFFFFA726); // Orange
  static const Color confirmed = Color(0xFF42A5F5); // Blue
  static const Color inProgress = Color(0xFF7E57C2); // Purple
  static const Color ready = Color(0xFF26A69A); // Teal
  static const Color completed = Color(0xFF66BB6A); // Green
  static const Color cancelled = Color(0xFFEF5350); // Red
  static const Color rejected = Color(0xFFE53935); // Dark Red
  static const Color refunded = Color(0xFF78909C); // Grey

  /// Get color for any status value
  static Color fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
        return pending;
      case 'confirmed':
      case 'accepted':
        return confirmed;
      case 'preparing':
      case 'processing':
      case 'in_progress':
        return inProgress;
      case 'ready':
      case 'packed':
      case 'shipped':
        return ready;
      case 'completed':
      case 'delivered':
      case 'checked_out':
        return completed;
      case 'cancelled':
        return cancelled;
      case 'rejected':
        return rejected;
      case 'refunded':
        return refunded;
      default:
        return Colors.grey;
    }
  }
}

/// Common order status icons
class OrderStatusIcons {
  static const IconData pending = Icons.schedule;
  static const IconData confirmed = Icons.check_circle_outline;
  static const IconData inProgress = Icons.sync;
  static const IconData ready = Icons.inventory_2;
  static const IconData completed = Icons.check_circle;
  static const IconData cancelled = Icons.cancel;
  static const IconData rejected = Icons.block;
  static const IconData refunded = Icons.replay;

  /// Get icon for any status value
  static IconData fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
        return pending;
      case 'confirmed':
      case 'accepted':
        return confirmed;
      case 'preparing':
      case 'processing':
      case 'in_progress':
        return inProgress;
      case 'ready':
      case 'packed':
      case 'shipped':
        return ready;
      case 'completed':
      case 'delivered':
      case 'checked_out':
        return completed;
      case 'cancelled':
        return cancelled;
      case 'rejected':
        return rejected;
      case 'refunded':
        return refunded;
      default:
        return Icons.help_outline;
    }
  }
}

/// Mixin for order total calculations
mixin OrderCalculations {
  double get subtotal;
  double get tax;
  double get deliveryFee;
  double get discount;
  String get currency;

  /// Calculate grand total
  double get total => subtotal + tax + deliveryFee - discount;

  /// Format subtotal
  String get formattedSubtotal => CurrencyUtils.format(subtotal, currency);

  /// Format tax
  String get formattedTax => CurrencyUtils.format(tax, currency);

  /// Format delivery fee
  String get formattedDeliveryFee => CurrencyUtils.format(deliveryFee, currency);

  /// Format discount
  String get formattedDiscount => CurrencyUtils.format(discount, currency);

  /// Format total
  String get formattedTotal => CurrencyUtils.format(total, currency);
}

/// Mixin for order timestamps
mixin OrderTimestamps {
  DateTime get createdAt;
  DateTime? get updatedAt;
  DateTime? get confirmedAt;
  DateTime? get completedAt;
  DateTime? get cancelledAt;

  /// Time since order was created
  Duration get timeSinceCreated => DateTime.now().difference(createdAt);

  /// Get processing time (creation to completion)
  Duration? get processingTime {
    if (completedAt == null) return null;
    return completedAt!.difference(createdAt);
  }

  /// Get formatted date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Get formatted time
  String get formattedTime {
    final hour = createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour;
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${createdAt.minute.toString().padLeft(2, '0')} $period';
  }

  /// Get formatted date and time
  String get formattedDateTime => '$formattedDate at $formattedTime';

  /// Get relative time string (e.g., "2 hours ago")
  String get relativeTime {
    final diff = timeSinceCreated;
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
