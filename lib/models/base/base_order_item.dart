import '../../utils/currency_utils.dart';

/// Abstract base class for order item models.
/// Used by: ProductOrderItem, FoodOrderItem
///
/// Provides common properties for items in an order/cart context.
abstract class BaseOrderItem {
  /// Unique identifier for the item being ordered
  String get itemId;

  /// Display name of the item
  String get name;

  /// Price per unit
  double get price;

  /// Quantity ordered
  int get quantity;

  /// Calculate total for this item (price * quantity)
  double get total => price * quantity;

  /// Convert to Firestore map
  Map<String, dynamic> toMap();

  /// Create a copy with updated quantity
  BaseOrderItem copyWithQuantity(int newQuantity);

  /// Check if quantity is valid
  bool get isValidQuantity => quantity > 0;

  /// Format price as string
  String formattedPrice(String currency) => CurrencyUtils.format(price, currency);

  /// Format total as string
  String formattedTotal(String currency) => CurrencyUtils.format(total, currency);
}

/// Mixin for common order item serialization
mixin OrderItemSerializationMixin {
  String get itemId;
  String get name;
  double get price;
  int get quantity;

  /// Convert base order item fields to map
  Map<String, dynamic> baseOrderItemToMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  /// Parse base order item fields from map
  static Map<String, dynamic> parseBaseFields(Map<String, dynamic> map) {
    return {
      'name': map['name'] ?? '',
      'price': (map['price'] ?? 0).toDouble(),
      'quantity': map['quantity'] ?? 1,
    };
  }
}
