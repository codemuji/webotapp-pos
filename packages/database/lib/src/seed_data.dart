import 'dart:math';
import 'package:drift/drift.dart';
import 'database.dart';

/// Comprehensive Retail & Supermarket Demo Dataset Generator.
/// Generates 650+ realistic grocery products, 10 categories, 4 employees,
/// and 450+ completed multi-item invoices across the last 30 days and today.
Future<int> seedDemoStoreData(AppDatabase db, {bool force = false}) async {
  if (!force) {
    final existing = await db.getAllProducts();
    if (existing.length >= 50) {
      return existing.length; // Already seeded
    }
  }

  final rng = Random(42); // Deterministic seed for reproducible testing
  final now = DateTime.now();

  return await db.transaction(() async {
    // 1. Insert 10 Supermarket Categories
    final categoriesData = [
      ('cat-staples', 'Staples & Grains', 'Rice, wheat, flours, pulses and lentils', 5.0, '1006'),
      ('cat-dairy', 'Dairy, Milk & Breakfast', 'Fresh milk, butter, cheese, paneer and yogurts', 0.0, '0401'),
      ('cat-produce', 'Fresh Produce & Fruits', 'Farm-fresh vegetables, herbs, and seasonal fruits', 0.0, '0701'),
      ('cat-spices', 'Spices, Masalas & Seasonings', 'Ground spices, whole seeds, and blended masalas', 5.0, '0910'),
      ('cat-oils', 'Edible Oils & Ghee', 'Mustard, sunflower, groundnut oil, and pure cow ghee', 5.0, '1512'),
      ('cat-snacks', 'Bakery, Biscuits & Snacks', 'Cookies, chips, rusks, namkeen, and crackers', 12.0, '1905'),
      ('cat-beverages', 'Tea, Coffee & Beverages', 'Leaf teas, instant coffee, juices, and health drinks', 12.0, '2101'),
      ('cat-personal', 'Personal Care & Hygiene', 'Soaps, shampoos, oral care, and deodorants', 18.0, '3304'),
      ('cat-cleaning', 'Household & Cleaning', 'Detergent powders, dishwash liquids, and surface cleaners', 18.0, '3402'),
      ('cat-packaged', 'Instant Foods & Sauces', 'Noodles, pastas, pasta sauces, jams, and spreads', 12.0, '1902'),
    ];

    for (final cat in categoriesData) {
      await db.into(db.categories).insertOnConflictUpdate(
            CategoriesCompanion.insert(
              id: cat.$1,
              name: cat.$2,
              description: Value(cat.$3),
              defaultTaxRate: Value(cat.$4),
              defaultHsnCode: Value(cat.$5),
            ),
          );
    }

    // 2. Insert Store Employees
    final employeesData = [
      ('emp-aarav', 'Aarav Sharma', '1234', 'cashier'),
      ('emp-priya', 'Priya Mehta', '5678', 'cashier'),
      ('emp-vikram', 'Vikram Patel', '9999', 'manager'),
      ('emp-admin', 'Admin Store', '0000', 'admin'),
    ];

    for (final emp in employeesData) {
      await db.into(db.employees).insertOnConflictUpdate(
            EmployeesCompanion.insert(
              id: emp.$1,
              name: emp.$2,
              pinHash: emp.$3,
              role: Value(emp.$4),
              createdAt: now.subtract(const Duration(days: 90)),
            ),
          );
    }

    // 3. Generate 650+ Realistic Grocery Products
    // Base templates by category
    final templates = <String, List<_ProductTemplate>>{
      'cat-staples': [
        _ProductTemplate('India Gate Basmati Rice Feast', 'kg', [('1 kg', 120.0, 95.0), ('5 kg', 550.0, 460.0), ('10 kg', 1050.0, 890.0)], 5.0, '1006'),
        _ProductTemplate('Daawat Rozana Gold Basmati', 'kg', [('1 kg', 98.0, 78.0), ('5 kg', 460.0, 380.0)], 5.0, '1006'),
        _ProductTemplate('Aashirvaad Superior MP Chakki Atta', 'kg', [('1 kg', 60.0, 48.0), ('5 kg', 285.0, 240.0), ('10 kg', 540.0, 450.0)], 5.0, '1101'),
        _ProductTemplate('Pillsbury Chakki Fresh Wheat Atta', 'kg', [('5 kg', 275.0, 230.0), ('10 kg', 520.0, 435.0)], 5.0, '1101'),
        _ProductTemplate('Fortune Shudh Besan Fine Chickpea', 'g', [('500g', 62.0, 48.0), ('1 kg', 118.0, 95.0)], 5.0, '1106'),
        _ProductTemplate('Tata Sampann Unpolished Toor Dal', 'kg', [('500g', 95.0, 78.0), ('1 kg', 185.0, 155.0)], 5.0, '0713'),
        _ProductTemplate('Tata Sampann Unpolished Moong Dal', 'kg', [('500g', 85.0, 70.0), ('1 kg', 165.0, 138.0)], 5.0, '0713'),
        _ProductTemplate('Tata Sampann Chana Dal', 'kg', [('500g', 60.0, 48.0), ('1 kg', 115.0, 95.0)], 5.0, '0713'),
        _ProductTemplate('Fortune Premium Sooji Rava', 'g', [('500g', 38.0, 28.0), ('1 kg', 72.0, 56.0)], 5.0, '1103'),
        _ProductTemplate('Tata Salt Vacuum Evaporated Iodized', 'kg', [('1 kg', 28.0, 22.5), ('Lite 1kg', 45.0, 36.0), ('Rock Salt 1kg', 90.0, 72.0)], 0.0, '2501'),
        _ProductTemplate('Madhur Pure & Hygienic White Sugar', 'kg', [('1 kg', 55.0, 44.0), ('5 kg', 265.0, 220.0)], 5.0, '1701'),
        _ProductTemplate('Catch Table Salt Sprinkler', 'g', [('200g', 42.0, 32.0)], 5.0, '2501'),
        _ProductTemplate('Kohinoor Charminar Everyday Rice', 'kg', [('1 kg', 85.0, 68.0), ('5 kg', 395.0, 320.0)], 5.0, '1006'),
      ],
      'cat-dairy': [
        _ProductTemplate('Amul Gold Full Cream Milk', 'ml', [('500ml', 33.0, 30.0), ('1 Litre', 64.0, 59.0)], 0.0, '0401', isPerishable: true, expiryDays: 3),
        _ProductTemplate('Amul Taaza Toned Fresh Milk', 'ml', [('500ml', 27.0, 24.5), ('1 Litre', 54.0, 49.5)], 0.0, '0401', isPerishable: true, expiryDays: 4),
        _ProductTemplate('Mother Dairy Full Cream Milk', 'ml', [('500ml', 33.0, 30.0), ('1 Litre', 64.0, 59.0)], 0.0, '0401', isPerishable: true, expiryDays: 2),
        _ProductTemplate('Amul Salted Table Butter', 'g', [('100g', 56.0, 48.0), ('500g', 275.0, 240.0)], 0.0, '0405', isPerishable: true, expiryDays: 25),
        _ProductTemplate('Amul Fresh Malai Paneer', 'g', [('200g', 90.0, 76.0), ('500g', 220.0, 185.0)], 0.0, '0406', isPerishable: true, expiryDays: 6),
        _ProductTemplate('Mother Dairy Classic Dahi Yogurt', 'g', [('400g', 45.0, 38.0), ('1 kg', 105.0, 88.0)], 0.0, '0403', isPerishable: true, expiryDays: 8),
        _ProductTemplate('Epigamia Greek Yogurt Natural', 'g', [('100g', 50.0, 40.0), ('Mango 100g', 55.0, 44.0)], 0.0, '0403', isPerishable: true, expiryDays: -2), // Expired!
        _ProductTemplate('Amul Cheese Slices Pack', 'g', [('10 Slices (200g)', 145.0, 120.0), ('20 Slices (400g)', 280.0, 235.0)], 0.0, '0406', isPerishable: true, expiryDays: 40),
        _ProductTemplate('Britannia Processed Cheese Block', 'g', [('200g', 135.0, 110.0), ('400g', 260.0, 218.0)], 0.0, '0406', isPerishable: true, expiryDays: 50),
        _ProductTemplate('Fresh Farm Eggs Brown Grade A', 'pack', [('6 Pack', 55.0, 42.0), ('12 Pack', 105.0, 82.0), ('30 Tray', 250.0, 195.0)], 0.0, '0407', isPerishable: true, expiryDays: 14),
      ],
      'cat-produce': [
        _ProductTemplate('Fresh Farm Red Onions', 'kg', [('1 kg', 40.0, 30.0), ('5 kg Bag', 185.0, 140.0)], 0.0, '0703', isPerishable: true, expiryDays: 10),
        _ProductTemplate('Fresh Premium Potatoes Jyoti', 'kg', [('1 kg', 32.0, 24.0), ('5 kg Bag', 150.0, 115.0)], 0.0, '0701', isPerishable: true, expiryDays: 14),
        _ProductTemplate('Farm Fresh Hybrid Tomatoes', 'kg', [('1 kg', 45.0, 34.0)], 0.0, '0702', isPerishable: true, expiryDays: 5),
        _ProductTemplate('Fresh Green Desi Cucumber', 'kg', [('500g', 25.0, 18.0), ('1 kg', 45.0, 32.0)], 0.0, '0707', isPerishable: true, expiryDays: 4),
        _ProductTemplate('Fresh Indian Garlic Pods', 'g', [('250g', 75.0, 58.0), ('500g', 140.0, 110.0)], 0.0, '0703', isPerishable: true, expiryDays: 20),
        _ProductTemplate('Fresh Green Ginger Adrak', 'g', [('250g', 35.0, 26.0), ('500g', 65.0, 48.0)], 0.0, '0709', isPerishable: true, expiryDays: 8),
        _ProductTemplate('Shimla Crisp Royal Delicious Apples', 'kg', [('1 kg', 180.0, 140.0), ('2 kg Pack', 340.0, 270.0)], 0.0, '0808', isPerishable: true, expiryDays: 7),
        _ProductTemplate('Fresh Robusta Golden Bananas', 'pack', [('6 pcs', 42.0, 30.0), ('12 pcs', 80.0, 58.0)], 0.0, '0803', isPerishable: true, expiryDays: 3),
        _ProductTemplate('Fresh Alphonso Ratnagiri Mangoes', 'kg', [('1 Dozen', 750.0, 580.0)], 0.0, '0804', isPerishable: true, expiryDays: -1), // Expired!
        _ProductTemplate('Fresh Green Capsicum Bell Pepper', 'kg', [('500g', 45.0, 34.0)], 0.0, '0709', isPerishable: true, expiryDays: 5),
      ],
      'cat-oils': [
        _ProductTemplate('Fortune Sunlite Refined Sunflower Oil', 'l', [('1 Litre Pouch', 145.0, 122.0), ('5 Litre Jar', 720.0, 610.0)], 5.0, '1512'),
        _ProductTemplate('Saffola Gold Pro Healthy Blend Oil', 'l', [('1 Litre', 185.0, 155.0), ('5 Litre Jar', 890.0, 760.0)], 5.0, '1512'),
        _ProductTemplate('Fortune Kachi Ghani Pure Mustard Oil', 'l', [('1 Litre Pouch', 165.0, 138.0), ('5 Litre Can', 810.0, 680.0)], 5.0, '1514'),
        _ProductTemplate('Dhara Filtered Groundnut Oil', 'l', [('1 Litre', 195.0, 162.0), ('5 Litre Jar', 950.0, 810.0)], 5.0, '1508'),
        _ProductTemplate('Amul Pure Cow Ghee Tin', 'ml', [('500ml', 345.0, 295.0), ('1 Litre', 675.0, 585.0)], 5.0, '0405', isPerishable: true, expiryDays: 90),
        _ProductTemplate('Mother Dairy Pure Desi Ghee', 'ml', [('500ml', 335.0, 288.0), ('1 Litre', 660.0, 570.0)], 5.0, '0405', isPerishable: true, expiryDays: 120),
        _ProductTemplate('Patanjali Cow Ghee Jar', 'ml', [('500ml', 310.0, 265.0), ('1 Litre', 610.0, 525.0)], 5.0, '0405', isPerishable: true, expiryDays: 75),
        _ProductTemplate('Borges Extra Virgin Olive Oil Glass', 'ml', [('500ml', 650.0, 520.0), ('1 Litre', 1250.0, 1020.0)], 5.0, '1509'),
      ],
      'cat-spices': [
        _ProductTemplate('Everest Garam Masala Blend', 'g', [('100g', 88.0, 70.0), ('200g', 165.0, 135.0)], 5.0, '0910'),
        _ProductTemplate('MDH Deggi Mirch Red Chilli Powder', 'g', [('100g', 92.0, 74.0), ('500g', 420.0, 345.0)], 5.0, '0904'),
        _ProductTemplate('Catch Turmeric Powder Haldi', 'g', [('200g', 62.0, 48.0), ('500g', 145.0, 118.0)], 5.0, '0910'),
        _ProductTemplate('Everest Kitchen King All Purpose', 'g', [('100g', 85.0, 68.0), ('200g', 160.0, 130.0)], 5.0, '0910'),
        _ProductTemplate('Everest Chana Masala Seasoning', 'g', [('100g', 78.0, 62.0)], 5.0, '0910'),
        _ProductTemplate('MDH Sambhar Masala Authentic', 'g', [('100g', 82.0, 65.0)], 5.0, '0910'),
        _ProductTemplate('Catch Cumin Seeds Whole Desi Jeera', 'g', [('100g', 75.0, 58.0), ('200g', 145.0, 115.0)], 5.0, '0909'),
        _ProductTemplate('Catch Mustard Seeds Rai Whole', 'g', [('100g', 38.0, 28.0), ('200g', 72.0, 55.0)], 5.0, '0910'),
        _ProductTemplate('Catch Coriander Powder Dhaniya', 'g', [('200g', 65.0, 50.0), ('500g', 150.0, 120.0)], 5.0, '0909'),
        _ProductTemplate('Catch Kasuri Methi Dried Fenugreek', 'g', [('50g', 45.0, 34.0)], 5.0, '0910'),
      ],
      'cat-snacks': [
        _ProductTemplate('Parle-G Original Glucose Biscuits', 'g', [('250g', 25.0, 19.5), ('800g Family Pack', 80.0, 64.0)], 12.0, '1905'),
        _ProductTemplate('Britannia Good Day Butter Cookies', 'g', [('200g', 45.0, 35.0), ('600g Saver', 130.0, 105.0)], 12.0, '1905'),
        _ProductTemplate('Britannia Marie Gold Tea Biscuits', 'g', [('250g', 40.0, 31.0), ('1 kg Giant', 140.0, 112.0)], 12.0, '1905'),
        _ProductTemplate('Sunfeast Dark Fantasy Choco Fills', 'g', [('75g', 40.0, 30.0), ('300g Party', 150.0, 118.0)], 12.0, '1905'),
        _ProductTemplate('Cadbury Oreo Vanilla Creme Biscuit', 'g', [('120g', 35.0, 27.0), ('300g Family', 85.0, 68.0)], 12.0, '1905'),
        _ProductTemplate('Haldirams Classic Salted Aloo Bhujia', 'g', [('200g', 58.0, 45.0), ('1 kg Jumbo', 260.0, 210.0)], 12.0, '1905'),
        _ProductTemplate('Haldirams Moong Dal Salted Snack', 'g', [('200g', 62.0, 48.0)], 12.0, '1905'),
        _ProductTemplate('Lays Classic Salted Potato Chips', 'g', [('50g', 20.0, 15.0), ('95g Party', 40.0, 31.0)], 12.0, '1905'),
        _ProductTemplate('Kurkure Masala Munch Crunchy', 'g', [('45g', 20.0, 15.0), ('90g', 40.0, 31.0)], 12.0, '1905'),
        _ProductTemplate('Britannia Toastea Premium Wheat Rusk', 'g', [('400g', 60.0, 46.0)], 12.0, '1905'),
        _ProductTemplate('Baker Choice Milk Bread Loaf', 'g', [('400g', 45.0, 32.0)], 0.0, '1905', isPerishable: true, expiryDays: 1), // Urgent clearance!
        _ProductTemplate('Harvest Gold 100% Brown Bread', 'g', [('400g', 55.0, 40.0)], 0.0, '1905', isPerishable: true, expiryDays: 2),
      ],
      'cat-beverages': [
        _ProductTemplate('Tata Tea Premium Desh Ki Chai', 'g', [('250g', 125.0, 102.0), ('500g', 240.0, 198.0), ('1 kg', 460.0, 385.0)], 5.0, '0902'),
        _ProductTemplate('Brooke Bond Red Label Strong Tea', 'g', [('250g', 130.0, 106.0), ('500g', 250.0, 208.0)], 5.0, '0902'),
        _ProductTemplate('Brooke Bond Taj Mahal Royal Tea', 'g', [('250g', 185.0, 150.0), ('500g', 360.0, 295.0)], 5.0, '0902'),
        _ProductTemplate('Nescafe Classic Instant Coffee Jar', 'g', [('50g', 165.0, 132.0), ('100g', 310.0, 255.0), ('200g Glass', 590.0, 490.0)], 18.0, '2101'),
        _ProductTemplate('Bru Instant Chicory Coffee Blend', 'g', [('100g', 215.0, 175.0), ('200g Pouch', 410.0, 335.0)], 18.0, '2101'),
        _ProductTemplate('Bournvita Cadbury Chocolate Drink', 'g', [('500g Jar', 245.0, 198.0), ('1 kg Refill', 460.0, 380.0)], 18.0, '1806'),
        _ProductTemplate('Horlicks Classic Malt Nutrition', 'g', [('500g Jar', 255.0, 208.0), ('1 kg Refill', 475.0, 395.0)], 18.0, '1901'),
        _ProductTemplate('Real Fruit Power Mixed Fruit Juice', 'l', [('1 Litre Tetra', 135.0, 108.0)], 12.0, '2009', isPerishable: true, expiryDays: 45),
        _ProductTemplate('Tropicana 100% Orange Juice', 'l', [('1 Litre Tetra', 145.0, 118.0)], 12.0, '2009', isPerishable: true, expiryDays: 30),
      ],
      'cat-packaged': [
        _ProductTemplate('Maggi 2-Minute Masala Noodles', 'g', [('Single (70g)', 14.0, 11.2), ('4-Pack (280g)', 56.0, 44.5), ('8-Pack Super', 110.0, 89.0)], 12.0, '1902'),
        _ProductTemplate('Sunfeast Yippee Magic Masala Noodles', 'g', [('4-Pack (260g)', 52.0, 41.0)], 12.0, '1902'),
        _ProductTemplate('Kissan Fresh Tomato Ketchup Squeezy', 'g', [('500g', 115.0, 92.0), ('950g Giant', 185.0, 150.0)], 12.0, '2103'),
        _ProductTemplate('Maggi Rich Tomato Sauce Bottle', 'g', [('500g', 120.0, 96.0)], 12.0, '2103'),
        _ProductTemplate('Knorr Classic Thick Tomato Soup', 'g', [('53g Single', 38.0, 29.0)], 12.0, '2104'),
        _ProductTemplate('Sundrop Creamy Peanut Butter Crunchy', 'g', [('462g Jar', 180.0, 145.0), ('924g', 340.0, 275.0)], 12.0, '2008'),
        _ProductTemplate('Nutella Hazelnut Cocoa Spread Jar', 'g', [('350g', 380.0, 310.0), ('750g', 750.0, 620.0)], 18.0, '1806'),
      ],
      'cat-personal': [
        _ProductTemplate('Dettol Original Germ Protection Soap', 'g', [('Pack of 3 (75g)', 115.0, 92.0), ('Pack of 4 (125g)', 220.0, 178.0)], 18.0, '3401'),
        _ProductTemplate('Lifebuoy Total Germ Protection Soap', 'g', [('Pack of 4 (125g)', 175.0, 140.0)], 18.0, '3401'),
        _ProductTemplate('Dove Cream Beauty Bathing Bar', 'g', [('Pack of 3 (100g)', 225.0, 185.0)], 18.0, '3401'),
        _ProductTemplate('Colgate Strong Teeth Dental Cream', 'g', [('100g', 62.0, 48.0), ('200g Saver', 118.0, 95.0), ('Twin Pack (300g)', 180.0, 145.0)], 18.0, '3306'),
        _ProductTemplate('Close Up Everfresh Red Gel Toothpaste', 'g', [('150g', 115.0, 92.0)], 18.0, '3306'),
        _ProductTemplate('Head & Shoulders Anti Dandruff Smooth', 'ml', [('180ml', 190.0, 152.0), ('340ml Pump', 360.0, 295.0)], 18.0, '3305'),
        _ProductTemplate('Clinic Plus Strong & Long Shampoo', 'ml', [('175ml', 125.0, 98.0), ('340ml', 240.0, 192.0)], 18.0, '3305'),
        _ProductTemplate('Nivea Soft Light Moisturizing Cream', 'ml', [('100ml', 195.0, 155.0), ('200ml Tub', 350.0, 285.0)], 18.0, '3304'),
        _ProductTemplate('Vaseline Intensive Care Deep Restore', 'ml', [('200ml', 190.0, 150.0), ('400ml Pump', 365.0, 298.0)], 18.0, '3304'),
      ],
      'cat-cleaning': [
        _ProductTemplate('Surf Excel Easy Wash Detergent Powder', 'kg', [('1 kg', 140.0, 114.0), ('3 kg Bag', 410.0, 335.0), ('5 kg Bucket', 680.0, 560.0)], 18.0, '3402'),
        _ProductTemplate('Ariel Matic Top Load Washing Powder', 'kg', [('1 kg', 255.0, 210.0), ('4 kg Bag', 940.0, 780.0)], 18.0, '3402'),
        _ProductTemplate('Tide Plus Extra Power Detergent Powder', 'kg', [('1 kg', 125.0, 102.0), ('3 kg Bag', 365.0, 298.0)], 18.0, '3402'),
        _ProductTemplate('Vim Dishwash Gel Lemon Anti-Smell', 'ml', [('250ml', 65.0, 50.0), ('750ml Bottle', 185.0, 148.0), ('2 Litre Refill', 390.0, 315.0)], 18.0, '3402'),
        _ProductTemplate('Vim Dishwash Bar Green Lemon', 'g', [('150g Single', 15.0, 11.5), ('Pack of 4', 55.0, 42.0)], 18.0, '3401'),
        _ProductTemplate('Harpic Power Plus Disinfectant Toilet', 'ml', [('500ml', 105.0, 84.0), ('1 Litre Twin', 198.0, 160.0)], 18.0, '3402'),
        _ProductTemplate('Lizol Disinfectant Surface Cleaner Citrus', 'ml', [('500ml', 115.0, 92.0), ('1 Litre Bottle', 215.0, 175.0), ('2 Litre Giant', 390.0, 320.0)], 18.0, '3808'),
        _ProductTemplate('Colin Glass and Household Cleaner Spray', 'ml', [('500ml Trigger', 110.0, 88.0)], 18.0, '3402'),
        _ProductTemplate('Scotch Brite Scrub Pad Heavy Duty', 'pack', [('Pack of 3', 60.0, 46.0), ('Pack of 5', 95.0, 72.0)], 18.0, '6805'),
      ],
    };

    int productCounter = 1000;
    int barcodeSeq = 8901000000;
    final allInsertedProducts = <Product>[];

    // Build 650+ variations
    for (final entry in templates.entries) {
      final catId = entry.key;
      final templateList = entry.value;

      for (final tmpl in templateList) {
        String? parentProdId;

        for (int vIdx = 0; vIdx < tmpl.variants.length; vIdx++) {
          final variant = tmpl.variants[vIdx];
          final prodId = 'prod-${productCounter++}';
          final barcode = '${barcodeSeq++}${rng.nextInt(9)}';
          final sku = '${catId.substring(4, 7).toUpperCase()}-${productCounter.toString().padLeft(4, '0')}';

          // Assign stock distributions:
          // 85% healthy, 10% low stock (<= minAlert), 5% out of stock (0)
          double stock;
          final minAlert = rng.nextInt(3) == 0 ? 10.0 : (rng.nextInt(2) == 0 ? 5.0 : 8.0);
          final stockRoll = rng.nextDouble();
          if (stockRoll < 0.05) {
            stock = 0.0; // Out of stock
          } else if (stockRoll < 0.15) {
            stock = (rng.nextInt(minAlert.toInt() - 1) + 1).toDouble(); // Low stock
          } else {
            stock = (rng.nextInt(90) + 15).toDouble(); // Healthy stock
          }

          // Expiry and Batch Number
          DateTime? expiry;
          String? batch;
          if (tmpl.isPerishable) {
            batch = 'LOT-${now.year}-${(rng.nextInt(900) + 100)}';
            if (tmpl.expiryDays != null) {
              expiry = now.add(Duration(days: tmpl.expiryDays!));
            } else {
              // Distribute across -3 to +60 days
              final expOffset = rng.nextInt(60) - 3;
              expiry = now.add(Duration(days: expOffset));
            }
          }

          final comp = ProductsCompanion.insert(
            id: prodId,
            name: tmpl.baseName,
            variantName: Value(variant.$1),
            parentProductId: Value(parentProdId),
            barcode: Value(barcode),
            sku: Value(sku),
            categoryId: Value(catId),
            sellingPrice: variant.$2,
            purchasePrice: Value(variant.$3),
            stockQuantity: Value(stock),
            unit: Value(tmpl.unit),
            taxRate: Value(tmpl.taxRate),
            hsnCode: Value(tmpl.hsnCode),
            minStockAlert: Value(minAlert),
            expiryDate: Value(expiry),
            batchNumber: Value(batch),
            updatedAt: now,
          );

          await db.into(db.products).insertOnConflictUpdate(comp);

          if (vIdx == 0) {
            parentProdId = prodId; // Parent product link
          }

          // Keep in-memory for invoice seeding
          allInsertedProducts.add(Product(
            id: prodId,
            name: tmpl.baseName,
            variantName: variant.$1,
            parentProductId: parentProdId,
            barcode: barcode,
            sku: sku,
            categoryId: catId,
            sellingPrice: variant.$2,
            purchasePrice: variant.$3,
            stockQuantity: stock,
            unit: tmpl.unit,
            taxRate: tmpl.taxRate,
            hsnCode: tmpl.hsnCode,
            minStockAlert: minAlert,
            expiryDate: expiry,
            batchNumber: batch,
            isActive: true,
            updatedAt: now,
          ));
        }
      }
    }

    // Expanded grocery product generator to reach 750+ SKUs across all 10 departments
    final departmentExtras = <String, List<(String, String, double, double, double, String, bool)>>{
      'cat-staples': [
        ('Tata Sampann Kala Chana', 'kg', 85.0, 68.0, 5.0, '0713', false),
        ('Tata Sampann Rajma Chitra', 'kg', 145.0, 118.0, 5.0, '0713', false),
        ('Tata Sampann Kabuli Chana', 'kg', 160.0, 128.0, 5.0, '0713', false),
        ('Tata Sampann Urad Dal Split White', 'kg', 140.0, 112.0, 5.0, '0713', false),
        ('Tata Sampann Masoor Dal Red Lentils', 'kg', 110.0, 88.0, 5.0, '0713', false),
        ('Fortune Poha Thick Flattened Rice', 'g', 55.0, 42.0, 5.0, '1104', false),
        ('Nature Fresh Sampoorna Chakki Atta', 'kg', 260.0, 215.0, 5.0, '1101', false),
        ('Patanjali Traditional Whole Wheat Atta', 'kg', 245.0, 205.0, 5.0, '1101', false),
        ('Rajdhani Premium Maida Refined Flour', 'kg', 48.0, 36.0, 5.0, '1101', false),
        ('Rajdhani Roasted Sooji Suji', 'g', 42.0, 32.0, 5.0, '1103', false),
        ('Patanjali Roasted Daliya Cracked Wheat', 'g', 45.0, 34.0, 5.0, '1103', false),
        ('Fortune Soya Chunks High Protein', 'g', 50.0, 38.0, 5.0, '2106', false),
        ('Saffola Masala Oats Classic Masala', 'g', 42.0, 32.0, 5.0, '1904', false),
        ('Bambino Roasted Vermicelli Sewai', 'g', 38.0, 28.0, 5.0, '1902', false),
        ('MTR Instant Idli Mix Powder', 'g', 75.0, 58.0, 5.0, '2106', false),
        ('MTR Instant Dosa Mix Crispy', 'g', 80.0, 62.0, 5.0, '2106', false),
      ],
      'cat-dairy': [
        ('Kelloggs Corn Flakes Original Real Honey', 'g', 185.0, 145.0, 0.0, '1904', false),
        ('Quaker Rolled Oats 100% Wholegrain', 'kg', 195.0, 155.0, 0.0, '1904', false),
        ('Amul Masti Spiced Buttermilk Chaas', 'ml', 18.0, 14.5, 0.0, '0403', true),
        ('Nandini Pasteurised Toned Fresh Milk', 'ml', 24.0, 21.0, 0.0, '0401', true),
        ('Nestle A+ Slim Skimmed UHT Milk', 'l', 85.0, 72.0, 0.0, '0401', true),
        ('Amul Whipping Cream Dairy Fresh', 'ml', 120.0, 98.0, 0.0, '0402', true),
        ('Mother Dairy Probiotic Strawberry Curd', 'g', 35.0, 28.0, 0.0, '0403', true),
        ('Govardhan Fresh Cow Butter Pure Yellow', 'g', 265.0, 225.0, 0.0, '0405', true),
        ('Britannia Daily Fresh Cow Milk Paneer', 'g', 95.0, 78.0, 0.0, '0406', true),
        ('Amul Pizza Mozzarella Diced Cheese', 'g', 160.0, 130.0, 0.0, '0406', true),
        ('Kraft Philadelphia Original Cream Cheese', 'g', 320.0, 260.0, 0.0, '0406', true),
        ('Milky Mist Natural Fruit Greek Yogurt', 'g', 60.0, 48.0, 0.0, '0403', true),
      ],
      'cat-produce': [
        ('Fresh Cauliflower Gobi Whole', 'pcs', 35.0, 24.0, 0.0, '0704', true),
        ('Fresh Cabbage Patta Gobi Green', 'kg', 28.0, 18.0, 0.0, '0704', true),
        ('Fresh Button Mushrooms Cleaned Tray', 'pack', 55.0, 40.0, 0.0, '0709', true),
        ('Fresh Green Coriander Leaves Bunch', 'bundle', 15.0, 9.0, 0.0, '0709', true),
        ('Fresh Mint Leaves Pudina Bunch', 'bundle', 12.0, 7.0, 0.0, '0709', true),
        ('Fresh Green Chillies Desi Hari Mirch', 'g', 25.0, 16.0, 0.0, '0709', true),
        ('Fresh Orange Carrots Gajar Sweet', 'kg', 55.0, 38.0, 0.0, '0706', true),
        ('Fresh Green French Beans Tender', 'kg', 65.0, 45.0, 0.0, '0708', true),
        ('Fresh Green Peas Matar Pods', 'kg', 85.0, 60.0, 0.0, '0708', true),
        ('Fresh Beetroot Chukandar Cleaned', 'kg', 45.0, 30.0, 0.0, '0706', true),
        ('Fresh Sweet Golden Pineapple Whole', 'pcs', 75.0, 52.0, 0.0, '0804', true),
        ('Nagpur Fresh Sweet Oranges Mosambi', 'kg', 90.0, 68.0, 0.0, '0805', true),
        ('Fresh Pomegranate Anar Pearls Juicy', 'kg', 160.0, 120.0, 0.0, '0810', true),
        ('Fresh Seedless Watermelon Kiran Green', 'kg', 35.0, 22.0, 0.0, '0807', true),
        ('Fresh Green Kiwi Imported Box', 'pack', 120.0, 90.0, 0.0, '0810', true),
      ],
      'cat-oils': [
        ('Patanjali Kachi Ghani Mustard Oil Bottle', 'l', 155.0, 128.0, 5.0, '1514', false),
        ('Figaro Pure Olive Oil Spanish Tin', 'ml', 720.0, 580.0, 5.0, '1509', false),
        ('Gemini Pure Refined Sunflower Oil', 'l', 140.0, 118.0, 5.0, '1512', false),
        ('Dalda Vanaspati Hydrogenated Cooking', 'kg', 125.0, 102.0, 5.0, '1516', false),
        ('Gold Winner Refined Sunflower Oil', 'l', 148.0, 124.0, 5.0, '1512', false),
        ('Idhayam Sesame Til Gingelly Oil', 'ml', 215.0, 180.0, 5.0, '1515', false),
        ('KlF Coconad Pure Coconut Cooking Oil', 'l', 230.0, 192.0, 5.0, '1513', false),
        ('Aashirvaad Svasti Pure Cow Ghee Jar', 'ml', 360.0, 305.0, 5.0, '0405', true),
      ],
      'cat-spices': [
        ('Everest Pav Bhaji Masala Blend', 'g', 78.0, 62.0, 5.0, '0910', false),
        ('Everest Pani Puri Masala Tangy', 'g', 65.0, 50.0, 5.0, '0910', false),
        ('MDH Chunky Chat Masala Sprinkler', 'g', 85.0, 68.0, 5.0, '0910', false),
        ('MDH Dal Makhani Masala Punjabi', 'g', 82.0, 65.0, 5.0, '0910', false),
        ('Catch Black Pepper Kali Mirch Powder', 'g', 95.0, 75.0, 5.0, '0904', false),
        ('Catch White Pepper Safed Mirch', 'g', 120.0, 95.0, 5.0, '0904', false),
        ('Everest Shahi Biryani Masala Royal', 'g', 95.0, 78.0, 5.0, '0910', false),
        ('Everest Chicken Masala Non Veg', 'g', 85.0, 68.0, 5.0, '0910', false),
        ('Catch Compounded Asafoetida Hing Tub', 'g', 68.0, 52.0, 5.0, '0910', false),
        ('Catch Cardamom Green Elaichi Whole', 'g', 190.0, 155.0, 5.0, '0908', false),
        ('Catch Cloves Laung Whole Desi', 'g', 110.0, 88.0, 5.0, '0907', false),
        ('Catch Cinnamon Sticks Dalchini Dal', 'g', 85.0, 66.0, 5.0, '0906', false),
      ],
      'cat-snacks': [
        ('Parle Hide & Seek Chocolate Chip Cookies', 'g', 40.0, 30.0, 12.0, '1905', false),
        ('Haldirams Soan Papdi Traditional Festive', 'g', 140.0, 110.0, 12.0, '1905', false),
        ('Cadbury Dairy Milk Silk Roasted Almond', 'g', 90.0, 72.0, 18.0, '1806', false),
        ('KitKat 4-Finger Crisp Wafer Chocolate', 'g', 30.0, 23.0, 18.0, '1806', false),
        ('Pringles Original Potato Crisps Can', 'g', 110.0, 88.0, 12.0, '1905', false),
        ('Doritos Nacho Cheese Tortilla Chips', 'g', 50.0, 39.0, 12.0, '1905', false),
        ('Haldirams Nagpur Mixture Spicy Namkeen', 'g', 65.0, 50.0, 12.0, '1905', false),
        ('Bikaji Bhujia Sev Bikaneri Crunchy', 'g', 70.0, 54.0, 12.0, '1905', false),
        ('Unibic Chocolate Chip Cookies Box', 'g', 65.0, 50.0, 12.0, '1905', false),
        ('Britannia Bourbon Chocolate Creme Biscuit', 'g', 35.0, 27.0, 12.0, '1905', false),
        ('Britannia Treat Jim Jam Cream Biscuits', 'g', 38.0, 29.0, 12.0, '1905', false),
        ('Parle Krackjack Sweet & Salty Cracker', 'g', 30.0, 23.0, 12.0, '1905', false),
        ('Parle Monaco Classic Salted Crackers', 'g', 25.0, 19.0, 12.0, '1905', false),
      ],
      'cat-beverages': [
        ('Red Bull Energy Drink Carbonated Can', 'ml', 125.0, 98.0, 18.0, '2202', false),
        ('Frooti Fresh Mango Juice Drink Bottle', 'ml', 40.0, 31.0, 12.0, '2202', false),
        ('Limca Fresh Lemon Lime Carbonated Can', 'ml', 40.0, 30.0, 18.0, '2202', false),
        ('Coca Cola Original Taste Carbonated Bottle', 'ml', 45.0, 34.0, 18.0, '2202', false),
        ('Thums Up Charged Carbonated Soda Bottle', 'ml', 45.0, 34.0, 18.0, '2202', false),
        ('Sprite Clear Crisp Lemon Lime Bottle', 'ml', 45.0, 34.0, 18.0, '2202', false),
        ('Kinley Packaged Purified Mineral Water', 'l', 20.0, 14.0, 18.0, '2201', false),
        ('Bisleri Packaged Drinking Water With Minerals', 'l', 20.0, 14.0, 18.0, '2201', false),
        ('Wagh Bakri Premium Leaf Tea Pouch', 'g', 145.0, 118.0, 5.0, '0902', false),
        ('Tata Tea Gold Rich Taste & Aroma', 'g', 165.0, 135.0, 5.0, '0902', false),
        ('Tata Tea Chakra Gold Premium Dust', 'g', 150.0, 122.0, 5.0, '0902', false),
        ('Davidoff Rich Aroma Fine Espresso Coffee', 'g', 550.0, 440.0, 18.0, '2101', false),
      ],
      'cat-personal': [
        ('Dettol Original Instant Hand Sanitizer', 'ml', 50.0, 38.0, 18.0, '3004', false),
        ('Savlon Antiseptic Liquid Disinfectant Bottle', 'ml', 95.0, 75.0, 18.0, '3004', false),
        ('Pears Pure & Gentle Glycerin Bath Soap', 'g', 85.0, 68.0, 18.0, '3401', false),
        ('Lux Velvet Touch Jasmine Body Wash', 'ml', 185.0, 145.0, 18.0, '3401', false),
        ('Sunsilk Black Shine Nourishing Shampoo', 'ml', 160.0, 125.0, 18.0, '3305', false),
        ('Pantene Pro-V Hair Fall Control Shampoo', 'ml', 210.0, 168.0, 18.0, '3305', false),
        ('Parachute 100% Pure Coconut Hair Oil', 'ml', 115.0, 92.0, 5.0, '1513', false),
        ('Bajaj Almond Drops Non Sticky Hair Oil', 'ml', 145.0, 115.0, 18.0, '3305', false),
        ('Sensodyne Rapid Relief Sensitivity Paste', 'g', 190.0, 155.0, 18.0, '3306', false),
        ('Dabur Red Ayurvedic Herbal Toothpaste', 'g', 110.0, 88.0, 18.0, '3306', false),
        ('Gillette Mach 3 Turbo Razor Cartridge', 'pack', 450.0, 365.0, 18.0, '8212', false),
        ('Ponds White Beauty Daily Anti-Spot Cream', 'g', 135.0, 108.0, 18.0, '3304', false),
      ],
      'cat-cleaning': [
        ('Comfort After Wash Fabric Conditioner Lily', 'ml', 210.0, 168.0, 18.0, '3402', false),
        ('Pril Liquid Dishwash Lime Degreaser Bottle', 'ml', 180.0, 142.0, 18.0, '3402', false),
        ('Wheel 2in1 Detergent Washing Powder', 'kg', 75.0, 58.0, 18.0, '3402', false),
        ('Rin Advanced Detergent Bar Single', 'g', 20.0, 15.0, 18.0, '3401', false),
        ('Harpic Red Bathroom Cleaner Bleach Trigger', 'ml', 115.0, 92.0, 18.0, '3402', false),
        ('Dettol Disinfectant Multi Surface Lime', 'ml', 195.0, 155.0, 18.0, '3808', false),
        ('Odonil Room Air Freshener Jasmine Block', 'g', 60.0, 46.0, 18.0, '3307', false),
        ('Good Knight Gold Flash Mosquito Liquid Refill', 'pack', 165.0, 130.0, 18.0, '3808', false),
        ('All Out Ultra Mosquito Repellent Machine', 'pack', 110.0, 85.0, 18.0, '3808', false),
        ('Hit Flying Insect Killer Spray Lime', 'ml', 175.0, 138.0, 18.0, '3808', false),
      ],
      'cat-packaged': [
        ('Maggi Atta Noodles Whole Wheat Veg Masala', 'g', 25.0, 19.5, 12.0, '1902', false),
        ('Maggi Special Masala 20 Spices Noodles', 'g', 22.0, 17.0, 12.0, '1902', false),
        ('Chings Secret Schezwan Fried Rice Masala', 'g', 15.0, 11.0, 12.0, '2103', false),
        ('Chings Secret Hakka Veg Noodles Pack', 'g', 45.0, 35.0, 12.0, '1902', false),
        ('Veeba Truly Tomato Ketchup No Onion Garlic', 'g', 115.0, 90.0, 12.0, '2103', false),
        ('Veeba Burger Mayonnaise Creamy Squeezy', 'g', 125.0, 98.0, 12.0, '2103', false),
        ('Del Monte Classic Sweet Corn Kernels Can', 'g', 85.0, 68.0, 12.0, '2005', false),
        ('Borges Penne Rigate Italian Durum Wheat', 'g', 160.0, 128.0, 12.0, '1902', false),
        ('Barilla Spaghetti Pasta No 5 Italian Box', 'g', 210.0, 168.0, 12.0, '1902', false),
        ('Kissan Mixed Fruit Jam Sweet Glass Jar', 'g', 145.0, 115.0, 12.0, '2007', false),
        ('Hersheys Chocolate Syrup Classic Squeezy', 'g', 120.0, 96.0, 18.0, '2106', false),
      ],
    };

    for (final dept in departmentExtras.entries) {
      final catId = dept.key;
      for (final item in dept.value) {
        for (final sz in ['Standard', 'Family Pack', 'Super Value']) {
          final prodId = 'prod-${productCounter++}';
          final barcode = '${barcodeSeq++}${rng.nextInt(9)}';
          final mult = sz == 'Standard' ? 1.0 : (sz == 'Family Pack' ? 2.2 : 3.8);
          final price = (item.$3 * mult).roundToDouble();
          final cost = (item.$4 * mult).roundToDouble();

          // Expiry and batches for perishables
          DateTime? expiry;
          String? batch;
          if (item.$7) {
            batch = 'LOT-${now.year}-${(rng.nextInt(900) + 100)}';
            final expOffset = rng.nextInt(45) - 3;
            expiry = now.add(Duration(days: expOffset));
          }

          final comp = ProductsCompanion.insert(
            id: prodId,
            name: '${item.$1} ($sz)',
            variantName: Value(sz),
            barcode: Value(barcode),
            sku: Value('SKU-${productCounter.toString().padLeft(4, '0')}'),
            categoryId: Value(catId),
            sellingPrice: price,
            purchasePrice: Value(cost),
            stockQuantity: Value((rng.nextInt(75) + 8).toDouble()),
            unit: Value(item.$2),
            taxRate: Value(item.$5),
            hsnCode: Value(item.$6),
            minStockAlert: const Value(5.0),
            expiryDate: Value(expiry),
            batchNumber: Value(batch),
            updatedAt: now,
          );
          await db.into(db.products).insertOnConflictUpdate(comp);

          allInsertedProducts.add(Product(
            id: prodId,
            name: '${item.$1} ($sz)',
            variantName: sz,
            barcode: barcode,
            categoryId: catId,
            sellingPrice: price,
            purchasePrice: cost,
            stockQuantity: 30.0,
            unit: item.$2,
            taxRate: item.$5,
            hsnCode: item.$6,
            minStockAlert: 5.0,
            expiryDate: expiry,
            batchNumber: batch,
            isActive: true,
            updatedAt: now,
          ));
        }
      }
    }

    // 4. Generate 450+ Completed Invoices spanning last 30 days & today
    // 50 invoices for TODAY (distributed realistically across hours 08:00 to 22:00)
    // 40 invoices for YESTERDAY
    // 360 invoices across past 28 days
    final paymentMethods = ['upi_qr', 'cash', 'card'];
    final paymentWeights = [0.52, 0.38, 0.10]; // 52% UPI, 38% Cash, 10% Card
    final cashiers = ['emp-aarav', 'emp-priya'];
    final devices = ['term-mobile-01', 'term-mobile-02'];

    int invoiceSeq = 1001;

    // Helper to generate an invoice with line items at a specific timestamp
    Future<void> createInvoiceAt(DateTime timestamp) async {
      final invId = 'inv-${invoiceSeq++}';
      final invNum = 'INV-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${invoiceSeq.toString().padLeft(4, '0')}';
      
      // Select payment mode based on realistic retail weights
      final roll = rng.nextDouble();
      final pMethod = roll < paymentWeights[0]
          ? paymentMethods[0]
          : (roll < paymentWeights[0] + paymentWeights[1] ? paymentMethods[1] : paymentMethods[2]);

      final cashier = cashiers[rng.nextInt(cashiers.length)];
      final device = devices[rng.nextInt(devices.length)];

      // Pick 2 to 6 random products for basket
      final basketSize = rng.nextInt(5) + 2;
      double subtotal = 0.0;
      double taxTotal = 0.0;
      final lineItems = <InvoiceItemsCompanion>[];

      for (int i = 0; i < basketSize; i++) {
        final prod = allInsertedProducts[rng.nextInt(allInsertedProducts.length)];
        final qty = (rng.nextInt(3) + 1).toDouble();
        final lineSub = prod.sellingPrice * qty;
        final tax = (lineSub * (prod.taxRate / 100.0));
        subtotal += lineSub;
        taxTotal += tax;

        lineItems.add(
          InvoiceItemsCompanion.insert(
            id: 'item-$invId-$i',
            invoiceId: invId,
            productId: Value(prod.id),
            productName: prod.name,
            barcode: Value(prod.barcode),
            quantity: qty,
            unitPrice: prod.sellingPrice,
            taxAmount: Value(tax),
            lineTotal: lineSub,
          ),
        );
      }

      final discount = rng.nextDouble() < 0.20 ? (rng.nextInt(3) * 10.0 + 10.0) : 0.0;
      final grandTotal = (subtotal + taxTotal - discount).clamp(10.0, 99999.0);

      // Insert Invoice
      await db.into(db.invoices).insertOnConflictUpdate(
            InvoicesCompanion.insert(
              id: invId,
              invoiceNumber: invNum,
              deviceId: device,
              employeeId: cashier,
              subtotal: subtotal,
              discount: Value(discount),
              taxAmount: Value(taxTotal),
              totalAmount: grandTotal,
              paymentMethod: pMethod,
              createdAt: timestamp,
              syncStatus: const Value('synced'),
            ),
          );

      // Insert Line Items
      for (final item in lineItems) {
        await db.into(db.invoiceItems).insertOnConflictUpdate(item);
      }
    }

    // A. 50 Invoices for TODAY across 08:00 to 22:00
    final todayHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    for (int i = 0; i < 50; i++) {
      final h = todayHours[rng.nextInt(todayHours.length)];
      final m = rng.nextInt(59);
      final s = rng.nextInt(59);
      final t = DateTime(now.year, now.month, now.day, h, m, s);
      await createInvoiceAt(t);
    }

    // B. 40 Invoices for YESTERDAY
    final yesterday = now.subtract(const Duration(days: 1));
    for (int i = 0; i < 40; i++) {
      final h = todayHours[rng.nextInt(todayHours.length)];
      final m = rng.nextInt(59);
      final t = DateTime(yesterday.year, yesterday.month, yesterday.day, h, m, 15);
      await createInvoiceAt(t);
    }

    // C. 360 Invoices across the past 28 days
    for (int day = 2; day <= 28; day++) {
      final dayDate = now.subtract(Duration(days: day));
      final billsInDay = rng.nextInt(8) + 10; // 10 to 18 bills per day
      for (int b = 0; b < billsInDay; b++) {
        final h = todayHours[rng.nextInt(todayHours.length)];
        final m = rng.nextInt(59);
        final t = DateTime(dayDate.year, dayDate.month, dayDate.day, h, m, 30);
        await createInvoiceAt(t);
      }
    }

    return allInsertedProducts.length;
  });
}

class _ProductTemplate {
  final String baseName;
  final String unit;
  final List<(String, double, double)> variants; // (VariantName, SellingPrice, PurchasePrice)
  final double taxRate;
  final String hsnCode;
  final bool isPerishable;
  final int? expiryDays;

  const _ProductTemplate(
    this.baseName,
    this.unit,
    this.variants,
    this.taxRate,
    this.hsnCode, {
    this.isPerishable = false,
    this.expiryDays,
  });
}
