import 'dart:io';
import 'package:database/database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Single row parsed from an imported CSV file with validation outcome.
class CsvProductRow {
  final int lineNumber;
  final String name;
  final String? variant;
  final String? barcode;
  final String? secondaryBarcode;
  final String? sku;
  final String? categoryName;
  final double sellingPrice;
  final double? costPrice;
  final double stockQuantity;
  final String unit;
  final double taxRate;
  final String? hsnCode;
  final double minStockAlert;
  final List<String> errors;

  const CsvProductRow({
    required this.lineNumber,
    required this.name,
    this.variant,
    this.barcode,
    this.secondaryBarcode,
    this.sku,
    this.categoryName,
    required this.sellingPrice,
    this.costPrice,
    required this.stockQuantity,
    required this.unit,
    required this.taxRate,
    this.hsnCode,
    required this.minStockAlert,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;
}

/// Service for importing, exporting, and validating retail grocery catalog CSV files.
class CsvCatalogService {
  static const List<String> headers = [
    'Name',
    'Variant',
    'Barcode',
    'SecondaryBarcode',
    'SKU',
    'Category',
    'SellingPrice',
    'CostPrice',
    'StockQuantity',
    'Unit',
    'TaxRate',
    'HSNCode',
    'MinStockAlert',
  ];

  /// Generates a starter CSV template containing real grocery examples.
  static String generateSampleCsvTemplate() {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    // Example 1: Packaged staple with EAN barcode
    buffer.writeln(
      'Tata Salt,1kg Pouch,8901234001001,,SKU-SALT-1K,Staples & Grains,28.00,22.50,50,kg,5.0,2501,10',
    );
    // Example 2: Weighed loose produce
    buffer.writeln(
      'Fresh Potatoes,Loose Weighed,,,SKU-POTATO-L,Vegetables & Fruits,35.00,26.00,100,kg,0.0,0701,20',
    );
    // Example 3: Cooking Oil with carton case barcode
    buffer.writeln(
      'Fortune Sunlite Oil,5L Jar,8901234002001,8901234002099,SKU-OIL-5L,Cooking Oils,640.00,560.00,15,l,5.0,1507,5',
    );
    // Example 4: FMCG Personal care
    buffer.writeln(
      'Dettol Original Soap,Pack of 4,8901234003001,,SKU-SOAP-4P,Personal Care,160.00,132.00,25,pack,18.0,3401,5',
    );

    return buffer.toString();
  }

  /// Exports current products and categories into RFC 4180 compliant CSV text.
  static String exportToCsv(List<Product> products, List<Category> categories) {
    final categoryMap = {for (final c in categories) c.id: c.name};
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final p in products) {
      final catName = p.categoryId != null ? (categoryMap[p.categoryId] ?? '') : '';
      final row = [
        _escapeCsv(p.name),
        _escapeCsv(p.variantName ?? ''),
        _escapeCsv(p.barcode ?? ''),
        _escapeCsv(p.secondaryBarcode ?? ''),
        _escapeCsv(p.sku ?? ''),
        _escapeCsv(catName),
        p.sellingPrice.toStringAsFixed(2),
        p.purchasePrice != null ? p.purchasePrice!.toStringAsFixed(2) : '',
        p.stockQuantity.toString(),
        _escapeCsv(p.unit),
        p.taxRate.toStringAsFixed(1),
        _escapeCsv(p.hsnCode ?? ''),
        p.minStockAlert.toString(),
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Parses CSV text and validates each row for data integrity.
  static List<CsvProductRow> parseCsv(String csvContent) {
    final lines = _splitLines(csvContent);
    if (lines.isEmpty) return [];

    final result = <CsvProductRow>[];
    bool isFirstLine = true;
    int lineNum = 0;

    for (final line in lines) {
      lineNum++;
      if (line.trim().isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (isFirstLine) {
        // Skip header row if it matches 'Name' or headers
        if (fields.isNotEmpty && fields[0].toLowerCase().contains('name')) {
          isFirstLine = false;
          continue;
        }
        isFirstLine = false;
      }

      final errors = <String>[];
      final name = fields.isNotEmpty ? fields[0].trim() : '';
      if (name.isEmpty) {
        errors.add('Product Name is required');
      }

      final variant = fields.length > 1 && fields[1].trim().isNotEmpty ? fields[1].trim() : null;
      final barcode = fields.length > 2 && fields[2].trim().isNotEmpty ? fields[2].trim() : null;
      final secBarcode = fields.length > 3 && fields[3].trim().isNotEmpty ? fields[3].trim() : null;
      final sku = fields.length > 4 && fields[4].trim().isNotEmpty ? fields[4].trim() : null;
      final category = fields.length > 5 && fields[5].trim().isNotEmpty ? fields[5].trim() : null;

      double sellingPrice = 0.0;
      if (fields.length > 6 && fields[6].trim().isNotEmpty) {
        final parsed = double.tryParse(fields[6].trim());
        if (parsed != null && parsed > 0) {
          sellingPrice = parsed;
        } else {
          errors.add('Selling price must be a positive number');
        }
      } else {
        errors.add('Selling price is required');
      }

      double? costPrice;
      if (fields.length > 7 && fields[7].trim().isNotEmpty) {
        costPrice = double.tryParse(fields[7].trim());
        if (costPrice == null || costPrice < 0) {
          errors.add('Cost price must be a non-negative number');
        }
      }

      double stockQuantity = 0.0;
      if (fields.length > 8 && fields[8].trim().isNotEmpty) {
        final parsed = double.tryParse(fields[8].trim());
        if (parsed != null && parsed >= 0) {
          stockQuantity = parsed;
        } else {
          errors.add('Stock quantity must be non-negative');
        }
      }

      String unit = 'pcs';
      if (fields.length > 9 && fields[9].trim().isNotEmpty) {
        unit = fields[9].trim().toLowerCase();
      }

      double taxRate = 0.0;
      if (fields.length > 10 && fields[10].trim().isNotEmpty) {
        final parsed = double.tryParse(fields[10].trim());
        if (parsed != null && parsed >= 0) {
          taxRate = parsed;
        }
      }

      final hsn = fields.length > 11 && fields[11].trim().isNotEmpty ? fields[11].trim() : null;

      double minStock = 5.0;
      if (fields.length > 12 && fields[12].trim().isNotEmpty) {
        final parsed = double.tryParse(fields[12].trim());
        if (parsed != null && parsed >= 0) {
          minStock = parsed;
        }
      }

      result.add(
        CsvProductRow(
          lineNumber: lineNum,
          name: name,
          variant: variant,
          barcode: barcode,
          secondaryBarcode: secBarcode,
          sku: sku,
          categoryName: category,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          stockQuantity: stockQuantity,
          unit: unit,
          taxRate: taxRate,
          hsnCode: hsn,
          minStockAlert: minStock,
          errors: errors,
        ),
      );
    }

    return result;
  }

  /// Writes CSV string to the user's Downloads or Documents directory.
  static Future<File> saveCsvToFile(String baseName, String content) async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filePath = p.join(dir.path, '${baseName}_$dateStr.csv');
    final file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  // --- Internal RFC 4180 Helpers ---
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  static List<String> _splitLines(String text) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        insideQuotes = !insideQuotes;
        buffer.write(ch);
      } else if ((ch == '\n' || ch == '\r') && !insideQuotes) {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \r\n
        }
        lines.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }

    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }

    return lines;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip escaped quote
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (ch == ',' && !insideQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}

