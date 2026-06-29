/// How a product is measured. Stored per-product on [FoodItem] and
/// snapshotted onto each order line.
enum ProductUnit {
  quantity,
  kilogram,
  litre;

  /// Value persisted to Firestore / JSON.
  String get storageValue => switch (this) {
        ProductUnit.quantity => 'quantity',
        ProductUnit.kilogram => 'kg',
        ProductUnit.litre => 'litre',
      };

  /// Decode a stored value. Unknown / null falls back to [quantity] so
  /// legacy products and order lines render exactly as before.
  static ProductUnit fromStorage(dynamic value) {
    switch (value?.toString()) {
      case 'kg':
        return ProductUnit.kilogram;
      case 'litre':
        return ProductUnit.litre;
      default:
        return ProductUnit.quantity;
    }
  }

  /// Renders an amount next to a number, e.g. `2x`, `2 kg`, `2 L`.
  String formatAmount(int n) => switch (this) {
        ProductUnit.quantity => '${n}x',
        ProductUnit.kilogram => '$n kg',
        ProductUnit.litre => '$n L',
      };

  /// Suffix appended to a price line, e.g. `₹50 / kg`. Empty for quantity.
  String get priceSuffix => switch (this) {
        ProductUnit.quantity => '',
        ProductUnit.kilogram => '/ kg',
        ProductUnit.litre => '/ L',
      };

  /// Noun used in production-summary totals (e.g. `12 units`, `12 kg`).
  String get productionWord => switch (this) {
        ProductUnit.quantity => 'units',
        ProductUnit.kilogram => 'kg',
        ProductUnit.litre => 'L',
      };

  /// Short label shown on the product form's selector chips.
  String get chipLabel => switch (this) {
        ProductUnit.quantity => 'Qty',
        ProductUnit.kilogram => 'Kg',
        ProductUnit.litre => 'Litre',
      };
}
