import '../../utils/currency_utils.dart';

/// Mixin for items that have pricing with discount support.
/// Used by: ProductModel, MenuItemModel, RoomModel, ServiceModel
mixin Priceable {
  /// Current selling price
  double get price;

  /// Original price before discount (if any)
  double? get originalPrice;

  /// Currency code (e.g., 'INR', 'USD')
  String get currency;

  /// Format price with currency symbol
  String get formattedPrice => CurrencyUtils.format(price, currency);

  /// Format original price with currency symbol
  String? get formattedOriginalPrice =>
      originalPrice != null ? CurrencyUtils.format(originalPrice!, currency) : null;

  /// Calculate discount percentage
  int? get discountPercent => CurrencyUtils.calculateDiscountPercent(price, originalPrice);

  /// Check if item has a discount
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;

  /// Get discount amount
  double? get discountAmount => CurrencyUtils.calculateDiscountAmount(price, originalPrice);

  /// Format discount amount
  String? get formattedDiscountAmount {
    if (discountAmount == null) return null;
    return CurrencyUtils.format(discountAmount!, currency);
  }

  /// Get discount badge text (e.g., "20% OFF")
  String? get discountBadgeText {
    if (discountPercent == null) return null;
    return CurrencyUtils.formatDiscount(discountPercent!);
  }

  /// Static method to format any price (delegates to CurrencyUtils)
  static String formatPrice(double amount, String currency) =>
      CurrencyUtils.format(amount, currency);

  /// Get currency symbol from currency code (delegates to CurrencyUtils)
  static String getCurrencySymbol(String currency) =>
      CurrencyUtils.getSymbol(currency);

  /// Format price range (for variable pricing)
  static String formatPriceRange(double min, double max, String currency) =>
      CurrencyUtils.formatRange(min, max, currency);
}

/// Extension for price-related utility functions
extension PriceUtils on double {
  /// Format as currency
  String asCurrency(String currency) => Priceable.formatPrice(this, currency);

  /// Format with specific decimal places
  String toDecimal(int places) => toStringAsFixed(places);
}
