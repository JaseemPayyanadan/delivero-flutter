import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductUnit.fromStorage', () {
    test('maps stored strings back to enum', () {
      expect(ProductUnit.fromStorage('quantity'), ProductUnit.quantity);
      expect(ProductUnit.fromStorage('kg'), ProductUnit.kilogram);
      expect(ProductUnit.fromStorage('gram'), ProductUnit.gram);
      expect(ProductUnit.fromStorage('litre'), ProductUnit.litre);
    });

    test('defaults to quantity for null/unknown', () {
      expect(ProductUnit.fromStorage(null), ProductUnit.quantity);
      expect(ProductUnit.fromStorage(''), ProductUnit.quantity);
      expect(ProductUnit.fromStorage('gallons'), ProductUnit.quantity);
    });

    test('round-trips through storageValue', () {
      for (final u in ProductUnit.values) {
        expect(ProductUnit.fromStorage(u.storageValue), u);
      }
    });
  });

  group('ProductUnit.formatAmount', () {
    test('quantity keeps the legacy Nx form', () {
      expect(ProductUnit.quantity.formatAmount(2), '2x');
    });
    test('kilogram, gram and litre use a spaced suffix', () {
      expect(ProductUnit.kilogram.formatAmount(2), '2 kg');
      expect(ProductUnit.gram.formatAmount(2), '2 g');
      expect(ProductUnit.litre.formatAmount(2), '2 L');
    });
  });

  group('label getters', () {
    test('priceSuffix', () {
      expect(ProductUnit.quantity.priceSuffix, '');
      expect(ProductUnit.kilogram.priceSuffix, '/ kg');
      expect(ProductUnit.gram.priceSuffix, '/ g');
      expect(ProductUnit.litre.priceSuffix, '/ L');
    });
    test('productionWord', () {
      expect(ProductUnit.quantity.productionWord, 'units');
      expect(ProductUnit.kilogram.productionWord, 'kg');
      expect(ProductUnit.gram.productionWord, 'g');
      expect(ProductUnit.litre.productionWord, 'L');
    });
    test('chipLabel', () {
      expect(ProductUnit.quantity.chipLabel, 'Qty');
      expect(ProductUnit.kilogram.chipLabel, 'Kg');
      expect(ProductUnit.gram.chipLabel, 'Gram');
      expect(ProductUnit.litre.chipLabel, 'Litre');
    });
  });
}
