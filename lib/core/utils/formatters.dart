class Formatters {
  static String currency(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}
