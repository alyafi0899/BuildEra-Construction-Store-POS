// lib/data/hive/hive_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_models.dart';

const _kProducts      = 'products';
const _kTransactions  = 'transactions';
const _kMeta          = 'meta';

class HiveService {
  static Box<HiveProduct>?     _productBox;
  static Box<HiveTransaction>? _txBox;
  static Box<dynamic>?         _metaBox;

  // ─── INIT ───────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters (check first to avoid duplicate registration)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HiveProductUnitAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HiveProductAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HiveTransactionItemAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HiveTransactionAdapter());

    _productBox     = await Hive.openBox<HiveProduct>(_kProducts);
    _txBox          = await Hive.openBox<HiveTransaction>(_kTransactions);
    _metaBox        = await Hive.openBox<dynamic>(_kMeta);
  }

  static Box<HiveProduct>     get productBox => _productBox!;
  static Box<HiveTransaction> get txBox      => _txBox!;
  static Box<dynamic>         get metaBox    => _metaBox!;

  // ─── ID COUNTERS ────────────────────────────────────────────────────────────

  static int nextProductId() {
    final id = (metaBox.get('nextProductId', defaultValue: 1) as int);
    metaBox.put('nextProductId', id + 1);
    return id;
  }

  static int nextTransactionId() {
    final id = (metaBox.get('nextTransactionId', defaultValue: 1) as int);
    metaBox.put('nextTransactionId', id + 1);
    return id;
  }

  static bool get isSeeded => metaBox.get('seeded', defaultValue: false) as bool;
  static Future<void> markSeeded() => metaBox.put('seeded', true);

  // ─── PRODUCTS ───────────────────────────────────────────────────────────────

  static List<HiveProduct> getAllProducts() {
    return productBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<HiveProduct> insertProduct(HiveProduct product) async {
    final id = nextProductId();
    final unitIdBase = id * 100; // unique unit IDs per product

    final saved = HiveProduct(
      id: id,
      name: product.name,
      category: product.category,
      barcode: product.barcode,
      basePrice: product.basePrice,
      baseUnit: product.baseUnit,
      stockQuantity: product.stockQuantity,
      description: product.description,
      isActive: product.isActive,
      units: product.units.asMap().entries.map((e) => HiveProductUnit(
        id: unitIdBase + e.key,
        productId: id,
        unitName: e.value.unitName,
        conversionRatio: e.value.conversionRatio,
        sellingPrice: e.value.sellingPrice,
        isBaseUnit: e.value.isBaseUnit,
      )).toList(),
    );
    await productBox.put(id, saved);
    return saved;
  }

  static Future<void> updateProduct(HiveProduct product) async {
    await productBox.put(product.id, product);
  }

  static Future<void> deleteProduct(int id) async {
    await productBox.delete(id);
  }

  static Future<void> updateStock(int productId, double newStock) async {
    final product = productBox.get(productId);
    if (product != null) {
      await productBox.put(productId, product.copyWith(stockQuantity: newStock));
    }
  }

  static HiveProduct? getProductById(int id) => productBox.get(id);

  // ─── TRANSACTIONS ────────────────────────────────────────────────────────────

  static List<HiveTransaction> getAllTransactions() {
    return txBox.values.toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  static Future<HiveTransaction> insertTransaction(HiveTransaction tx) async {
    final id = nextTransactionId();
    final saved = HiveTransaction(
      id: id,
      transactionCode: tx.transactionCode,
      transactionDate: tx.transactionDate,
      subtotal: tx.subtotal,
      discountAmount: tx.discountAmount,
      taxAmount: tx.taxAmount,
      totalAmount: tx.totalAmount,
      paidAmount: tx.paidAmount,
      changeAmount: tx.changeAmount,
      paymentMethod: tx.paymentMethod,
      notes: tx.notes,
      status: tx.status,
      cashierName: tx.cashierName,
      items: tx.items.asMap().entries.map((e) => HiveTransactionItem(
        id: id * 1000 + e.key,
        transactionId: id,
        productId: e.value.productId,
        productName: e.value.productName,
        unitName: e.value.unitName,
        quantity: e.value.quantity,
        pricePerUnit: e.value.pricePerUnit,
        subtotal: e.value.subtotal,
        conversionRatio: e.value.conversionRatio,
      )).toList(),
    );
    await txBox.put(id, saved);
    return saved;
  }

  // ─── SEED DATA ───────────────────────────────────────────────────────────────

  static Future<void> seed() async {
    if (isSeeded) return;

    final dummy = _buildDummyProducts();
    for (final p in dummy) {
      await productBox.put(p.id, p);
    }
    await metaBox.put('nextProductId', dummy.length + 1);
    await markSeeded();
  }

  static List<HiveProduct> _buildDummyProducts() => [
    _p(1, 'Palu Besi 500gr',    'Alat Tangan',        '8991234560001', 45000, 'pcs', 50,
       'Palu besi berkualitas tinggi, gagang kayu',
       [_u(1,1,'pcs',1,45000,true)]),
    _p(2, 'Semen Portland',     'Material Bangunan',  '8991234560002', 1800,  'kg',  2500,
       'Semen Portland tipe I',
       [_u(2,2,'kg',1,1800,true), _u(3,2,'sak',40,75000,false)]),
    _p(3, 'Tali Tambang 10mm',  'Pengencang & Baut',  '8991234560003', 8500,  'meter',500,
       'Tali tambang polypropylene 10mm',
       [_u(4,3,'meter',1,8500,true), _u(5,3,'roll',50,400000,false)]),
    _p(4, 'Cat Tembok Dulux',   'Cat & Kimia',        '8991234560004', 55000, 'liter',200,
       'Cat tembok interior Dulux',
       [_u(6,4,'liter',1,55000,true), _u(7,4,'kaleng 5L',5,265000,false), _u(8,4,'kaleng 25L',25,1300000,false)]),
    _p(5, 'Besi Beton 10mm',    'Material Bangunan',  '8991234560005', 12000, 'meter',1000,
       'Besi beton ulir diameter 10mm',
       [_u(9,5,'meter',1,12000,true), _u(10,5,'batang',12,140000,false)]),
    _p(6, 'Bor Listrik Bosch',  'Alat Listrik',       '8991234560006', 650000,'pcs', 15,
       'Bor listrik Bosch 650W',
       [_u(11,6,'pcs',1,650000,true)]),
    _p(7, 'Pipa PVC 4 inch',    'Pipa & Fitting',     '8991234560007', 35000, 'meter',300,
       'Pipa PVC schedule 40 diameter 4 inch',
       [_u(12,7,'meter',1,35000,true), _u(13,7,'batang 4m',4,135000,false)]),
    _p(8, 'Helm Safety',        'Keamanan & APD',     '8991234560008', 85000, 'pcs', 30,
       'Helm safety SNI warna kuning',
       [_u(14,8,'pcs',1,85000,true)]),
    _p(9, 'Meteran Besi 5m',    'Pengukuran',         '8991234560009', 28000, 'pcs', 40,
       'Meteran besi otomatis 5 meter',
       [_u(15,9,'pcs',1,28000,true)]),
    _p(10,'Kawat Bendrat',      'Pengencang & Baut',  '8991234560010', 15000, 'kg',  150,
       'Kawat bendrat ikat besi',
       [_u(16,10,'kg',1,15000,true), _u(17,10,'roll 5kg',5,72000,false)]),
    _p(11,'Amplas Lembar',      'Alat Tangan',        '8991234560011', 3500,  'lembar',8,
       'Amplas lembar grit 120',
       [_u(18,11,'lembar',1,3500,true), _u(19,11,'lusin',12,40000,false)]),
    _p(12,'Thinner A Special',  'Cat & Kimia',        '8991234560012', 18000, 'liter',100,
       'Thinner A special untuk cat minyak',
       [_u(20,12,'liter',1,18000,true), _u(21,12,'jerigen 5L',5,85000,false)]),
  ];

  static HiveProduct _p(int id, String name, String cat, String barcode,
      double price, String unit, double stock, String desc,
      List<HiveProductUnit> units) =>
      HiveProduct(id: id, name: name, category: cat, barcode: barcode,
          basePrice: price, baseUnit: unit, stockQuantity: stock,
          description: desc, isActive: true, units: units);

  static HiveProductUnit _u(int id, int pid, String name, double ratio,
      double price, bool isBase) =>
      HiveProductUnit(id: id, productId: pid, unitName: name,
          conversionRatio: ratio, sellingPrice: price, isBaseUnit: isBase);
}
