import 'package:database/database.dart';
import 'package:desktop/src/catalog/csv_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvCatalogService - Bulk Catalog Import/Export & RFC 4180 Validation', () {
    test('generateSampleCsvTemplate produces valid grocery CSV with headers', () {
      final template = CsvCatalogService.generateSampleCsvTemplate();
      expect(template, contains('Name,Variant,Barcode,SecondaryBarcode,SKU'));
      expect(template, contains('Tata Salt,1kg Pouch'));
      expect(template, contains('Fresh Potatoes,Loose Weighed'));

      final parsed = CsvCatalogService.parseCsv(template);
      expect(parsed.length, equals(4));
      for (final row in parsed) {
        expect(row.isValid, isTrue, reason: 'Row ${row.lineNumber} should be valid');
      }
    });

    test('parseCsv handles RFC 4180 commas and quoted values correctly', () {
      const csv = '''Name,Variant,Barcode,SecondaryBarcode,SKU,Category,SellingPrice,CostPrice,StockQuantity,Unit,TaxRate,HSNCode,MinStockAlert
"Atta, Whole Wheat",5kg Bag,8901234500111,,SKU-ATT-5,"Flour, Grains & Staples",240.00,205.00,20,kg,5.0,1101,5
"Milk, Full Cream",1 Litre,8901234500222,,SKU-MLK-1,Dairy,66.00,58.00,30,l,0.0,0401,10
''';
      final rows = CsvCatalogService.parseCsv(csv);
      expect(rows.length, equals(2));

      expect(rows[0].name, equals('Atta, Whole Wheat'));
      expect(rows[0].categoryName, equals('Flour, Grains & Staples'));
      expect(rows[0].sellingPrice, equals(240.0));
      expect(rows[0].costPrice, equals(205.0));
      expect(rows[0].isValid, isTrue);

      expect(rows[1].name, equals('Milk, Full Cream'));
      expect(rows[1].unit, equals('l'));
    });

    test('parseCsv flags validation errors on invalid rows', () {
      const csv = '''Name,Variant,Barcode,SecondaryBarcode,SKU,Category,SellingPrice,CostPrice,StockQuantity,Unit,TaxRate,HSNCode,MinStockAlert
,Empty Name,8901234500000,,SKU-ERR-1,Dairy,50.00,40.00,10,pcs,5.0,,5
Bad Price,1kg,8901234500001,,SKU-ERR-2,Dairy,INVALID,40.00,10,pcs,5.0,,5
Negative Stock,1kg,8901234500002,,SKU-ERR-3,Dairy,50.00,40.00,-5,pcs,5.0,,5
''';
      final rows = CsvCatalogService.parseCsv(csv);
      expect(rows.length, equals(3));

      expect(rows[0].isValid, isFalse);
      expect(rows[0].errors, contains('Product Name is required'));

      expect(rows[1].isValid, isFalse);
      expect(rows[1].errors, contains('Selling price must be a positive number'));

      expect(rows[2].isValid, isFalse);
      expect(rows[2].errors, contains('Stock quantity must be non-negative'));
    });

    test('exportToCsv produces correct CSV format matching database entities', () {
      final now = DateTime.now();
      final categories = [
        Category(
          id: 'cat-spices',
          name: 'Spices & Condiments',
          description: null,
          defaultTaxRate: 5.0,
          defaultHsnCode: '0910',
        ),
      ];

      final products = [
        Product(
          id: 'prod-turmeric',
          name: 'Turmeric Powder',
          variantName: '200g Pouch',
          barcode: '8901234500999',
          secondaryBarcode: null,
          sku: 'SKU-TUR-200',
          categoryId: 'cat-spices',
          sellingPrice: 58.00,
          purchasePrice: 44.00,
          stockQuantity: 45.0,
          unit: 'g',
          taxRate: 5.0,
          hsnCode: '0910',
          minStockAlert: 10.0,
          isActive: true,
          updatedAt: now,
          parentProductId: null,
        ),
      ];

      final csv = CsvCatalogService.exportToCsv(products, categories);
      expect(csv, contains('Name,Variant,Barcode,SecondaryBarcode,SKU,Category'));
      expect(csv, contains('Turmeric Powder,200g Pouch,8901234500999,,SKU-TUR-200,Spices & Condiments,58.00,44.00,45.0,g,5.0,0910,10.0'));
    });
  });
}

