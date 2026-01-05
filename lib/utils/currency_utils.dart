/// Centralized currency formatting utilities.
/// Use this class for ALL currency-related formatting across the app.
class CurrencyUtils {
  // Private constructor to prevent instantiation
  CurrencyUtils._();

  /// Supported currency symbols
  static const Map<String, String> _currencySymbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AED': 'د.إ',
    'SAR': '﷼',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'SGD': 'S\$',
    'CHF': 'CHF',
    'CNY': '¥',
    'KRW': '₩',
    'MYR': 'RM',
    'THB': '฿',
    'PHP': '₱',
    'IDR': 'Rp',
    'VND': '₫',
    'BDT': '৳',
    'PKR': '₨',
    'LKR': 'Rs',
    'NPR': 'रू',
  };

  /// Get currency symbol from currency code
  static String getSymbol(String currency) {
    return _currencySymbols[currency.toUpperCase()] ?? currency;
  }

  /// Format amount with currency symbol
  static String format(double amount, String currency) {
    final symbol = getSymbol(currency);
    // Remove decimal places if it's a whole number
    final formatted = amount.truncateToDouble() == amount
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '$symbol$formatted';
  }

  /// Format price range (for variable pricing)
  static String formatRange(double min, double max, String currency) {
    if (min == max) return format(min, currency);
    return '${format(min, currency)} - ${format(max, currency)}';
  }

  /// Format with suffix (e.g., "/hr", "/night")
  static String formatWithSuffix(double amount, String currency, String suffix) {
    return '${format(amount, currency)}$suffix';
  }

  /// Format as "Starting from" price
  static String formatStartingFrom(double amount, String currency) {
    return 'From ${format(amount, currency)}';
  }

  /// Format as price per unit
  static String formatPerUnit(double amount, String currency, String unit) {
    return '${format(amount, currency)}/$unit';
  }

  /// Format discount percentage
  static String formatDiscount(int percent) {
    return '$percent% OFF';
  }

  /// Calculate discount percentage
  static int? calculateDiscountPercent(double price, double? originalPrice) {
    if (originalPrice == null || originalPrice <= price) return null;
    return (((originalPrice - price) / originalPrice) * 100).round();
  }

  /// Calculate discount amount
  static double? calculateDiscountAmount(double price, double? originalPrice) {
    if (originalPrice == null || originalPrice <= price) return null;
    return originalPrice - price;
  }

  /// Get all supported currencies
  static List<String> get supportedCurrencies => _currencySymbols.keys.toList();

  /// Check if currency is supported
  static bool isSupported(String currency) {
    return _currencySymbols.containsKey(currency.toUpperCase());
  }
}

/// Extension methods for double to format as currency
extension CurrencyExtension on double {
  /// Format as currency
  String asCurrency(String currency) => CurrencyUtils.format(this, currency);

  /// Format as currency per hour
  String asPerHour(String currency) =>
      CurrencyUtils.formatWithSuffix(this, currency, '/hr');

  /// Format as currency per night
  String asPerNight(String currency) =>
      CurrencyUtils.formatWithSuffix(this, currency, '/night');

  /// Format as currency per unit
  String asPerUnit(String currency, String unit) =>
      CurrencyUtils.formatPerUnit(this, currency, unit);
}
