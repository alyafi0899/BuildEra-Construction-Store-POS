// ─────────────────────────────────────────────────────────────────────────────
// local_database.dart
// Pure-Dart JSON store backed by shared_preferences.
// Works on Web (localStorage), Windows, macOS, Linux, Android, iOS.
// No code generation, no native plugins, no platform channels beyond SP.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDb {
  static SharedPreferences? _prefs;
  static bool _seeded = false;

  // ── Boot ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs!.containsKey('__db_init')) {
      await _seed();
      await _prefs!.setBool('__db_init', true);
    }
    _seeded = true;
  }

  // ── Generic collection helpers ────────────────────────────────────────────

  /// Read every row in [collection].
  static List<Map<String, dynamic>> _readAll(String collection) {
    final raw = _prefs!.getString(collection);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// Persist [rows] to [collection].
  static Future<void> _writeAll(String collection, List<Map<String, dynamic>> rows) async {
    await _prefs!.setString(collection, jsonEncode(rows));
  }

  // ── Public API (mirrors the old DatabaseHelper signature) ─────────────────

  static List<Map<String, dynamic>> query(
    String collection, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) {
    assert(_seeded, 'Call LocalDb.init() before using the database');
    var rows = _readAll(collection);

    if (where != null && whereArgs != null) {
      rows = _applyWhere(rows, where, whereArgs);
    }

    if (orderBy != null) {
      final parts   = orderBy.trim().split(RegExp(r'\s+'));
      final field   = parts[0];
      final descending = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      rows = List.from(rows)..sort((a, b) {
        final av = a[field];
        final bv = b[field];
        if (av is num && bv is num) {
          return descending ? bv.compareTo(av) : av.compareTo(bv);
        }
        return descending
            ? bv.toString().compareTo(av.toString())
            : av.toString().compareTo(bv.toString());
      });
    }

    return rows;
  }

  static Future<void> insert(
    String collection,
    Map<String, dynamic> values, {
    bool replace = true,
  }) async {
    final rows = _readAll(collection);
    final id   = values['id'] as String?;
    if (id != null && replace) {
      final idx = rows.indexWhere((r) => r['id'] == id);
      if (idx >= 0) {
        rows[idx] = Map.from(values);
        await _writeAll(collection, rows);
        return;
      }
    }
    rows.add(Map.from(values));
    await _writeAll(collection, rows);
  }

  static Future<void> update(
    String collection,
    Map<String, dynamic> updates, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final rows    = _readAll(collection);
    final updated = rows.map((r) {
      if (_rowMatches(r, where, whereArgs)) {
        return {...r, ...updates};
      }
      return r;
    }).toList();
    await _writeAll(collection, updated);
  }

  static Future<void> delete(
    String collection, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    var rows = _readAll(collection);
    if (where != null && whereArgs != null) {
      rows = rows.where((r) => !_rowMatches(r, where, whereArgs)).toList();
    } else {
      rows = [];
    }
    await _writeAll(collection, rows);
  }

  /// Increment/decrement a numeric field in-place (atomic-ish).
  static Future<void> increment(
    String collection,
    String field,
    double delta, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final rows = _readAll(collection);
    final updated = rows.map((r) {
      if (_rowMatches(r, where, whereArgs)) {
        final cur = (r[field] as num?)?.toDouble() ?? 0;
        return {...r, field: cur + delta};
      }
      return r;
    }).toList();
    await _writeAll(collection, updated);
  }

  // ── WHERE mini-parser ────────────────────────────────────────────────────
  // Supports:  col = ?          (equality)
  //            col >= ? AND col < ?  (range – used for date queries)
  //            col IN (?,?,...)  not needed here but left for future

  static List<Map<String, dynamic>> _applyWhere(
    List<Map<String, dynamic>> rows,
    String where,
    List<dynamic> args,
  ) {
    return rows.where((r) => _rowMatches(r, where, args)).toList();
  }

  static bool _rowMatches(
    Map<String, dynamic> row,
    String where,
    List<dynamic> args,
  ) {
    // Split on AND
    final clauses = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    int argIdx = 0;
    for (final clause in clauses) {
      final trimmed = clause.trim();
      if (trimmed.contains('>=')) {
        final parts = trimmed.split('>=').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++].toString();
        if ((row[col]?.toString() ?? '').compareTo(val) < 0) return false;
      } else if (trimmed.contains('<=')) {
        final parts = trimmed.split('<=').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++].toString();
        if ((row[col]?.toString() ?? '').compareTo(val) > 0) return false;
      } else if (trimmed.contains('<')) {
        final parts = trimmed.split('<').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++].toString();
        if ((row[col]?.toString() ?? '').compareTo(val) >= 0) return false;
      } else if (trimmed.contains('>')) {
        final parts = trimmed.split('>').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++].toString();
        if ((row[col]?.toString() ?? '').compareTo(val) <= 0) return false;
      } else if (trimmed.contains('!=')) {
        final parts = trimmed.split('!=').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++];
        if (row[col]?.toString() == val?.toString()) return false;
      } else if (trimmed.contains('=')) {
        // strip trailing ? and whitespace
        final parts = trimmed.replaceAll('?', '').split('=').map((s) => s.trim()).toList();
        final col   = parts[0];
        final val   = args[argIdx++];
        if (row[col]?.toString() != val?.toString()) return false;
      }
    }
    return true;
  }

  // ── Seed data ─────────────────────────────────────────────────────────────

  static Future<void> _seed() async {
    final now = DateTime.now().toIso8601String();

    final products = [
      {'id':'p001','name':'Semen Portland Tiga Roda','category':'Semen & Material', 'barcode':'8991234560001','base_price':1500.0, 'base_unit':'kg',   'stock':500.0,  'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p002','name':'Besi Beton 10mm',         'category':'Besi & Baja',      'barcode':'8991234560002','base_price':12000.0,'base_unit':'meter','stock':200.0,  'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p003','name':'Tali Tambang Nilon 10mm', 'category':'Tali & Kawat',     'barcode':'8991234560003','base_price':8000.0, 'base_unit':'meter','stock':600.0,  'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p004','name':'Cat Tembok Avian 5kg',    'category':'Cat & Pelapis',    'barcode':'8991234560004','base_price':85000.0,'base_unit':'pcs',  'stock':50.0,   'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p005','name':'Pipa PVC AW 4"',          'category':'Pipa & Fitting',   'barcode':'8991234560005','base_price':45000.0,'base_unit':'meter','stock':100.0,  'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p006','name':'Paku Beton 3"',           'category':'Paku & Baut',      'barcode':'8991234560006','base_price':20000.0,'base_unit':'kg',   'stock':80.0,   'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p007','name':'Triplek 9mm 4x8',         'category':'Kayu & Triplek',   'barcode':'8991234560007','base_price':185000.0,'base_unit':'pcs', 'stock':30.0,   'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p008','name':'Kabel NYM 2x2.5mm',       'category':'Alat Listrik',     'barcode':'8991234560008','base_price':7500.0, 'base_unit':'meter','stock':1000.0, 'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p009','name':'Palu Besi 1kg',           'category':'Alat Tangan',      'barcode':'8991234560009','base_price':65000.0,'base_unit':'pcs',  'stock':25.0,   'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p010','name':'Pasir Beton',             'category':'Semen & Material', 'barcode':'8991234560010','base_price':250.0,  'base_unit':'kg',   'stock':5000.0, 'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p011','name':'Keramik 40x40cm',         'category':'Keramik & Granit', 'barcode':'8991234560011','base_price':55000.0,'base_unit':'pcs',  'stock':8.0,    'image_path':null,'created_at':now,'updated_at':now},
      {'id':'p012','name':'Kabel Solar Wire 4mm',    'category':'Alat Listrik',     'barcode':'8991234560012','base_price':15000.0,'base_unit':'meter','stock':500.0,  'image_path':null,'created_at':now,'updated_at':now},
    ];
    for (final p in products) {
      await insert('products', p, replace: false);
    }

    final units = [
      {'id':'u001','product_id':'p001','unit_name':'kg',   'conversion_rate':1.0,  'sell_price':1500.0},
      {'id':'u002','product_id':'p001','unit_name':'sack', 'conversion_rate':40.0, 'sell_price':65000.0},
      {'id':'u003','product_id':'p002','unit_name':'meter','conversion_rate':1.0,  'sell_price':12000.0},
      {'id':'u004','product_id':'p002','unit_name':'pcs',  'conversion_rate':12.0, 'sell_price':140000.0},
      {'id':'u005','product_id':'p003','unit_name':'meter','conversion_rate':1.0,  'sell_price':8000.0},
      {'id':'u006','product_id':'p003','unit_name':'roll', 'conversion_rate':50.0, 'sell_price':380000.0},
      {'id':'u007','product_id':'p004','unit_name':'pcs',  'conversion_rate':1.0,  'sell_price':95000.0},
      {'id':'u008','product_id':'p004','unit_name':'box',  'conversion_rate':6.0,  'sell_price':540000.0},
      {'id':'u009','product_id':'p005','unit_name':'meter','conversion_rate':1.0,  'sell_price':45000.0},
      {'id':'u010','product_id':'p005','unit_name':'pcs',  'conversion_rate':4.0,  'sell_price':170000.0},
      {'id':'u011','product_id':'p006','unit_name':'kg',   'conversion_rate':1.0,  'sell_price':25000.0},
      {'id':'u012','product_id':'p006','unit_name':'box',  'conversion_rate':5.0,  'sell_price':115000.0},
      {'id':'u013','product_id':'p007','unit_name':'pcs',  'conversion_rate':1.0,  'sell_price':195000.0},
      {'id':'u014','product_id':'p008','unit_name':'meter','conversion_rate':1.0,  'sell_price':7500.0},
      {'id':'u015','product_id':'p008','unit_name':'roll', 'conversion_rate':100.0,'sell_price':720000.0},
      {'id':'u016','product_id':'p009','unit_name':'pcs',  'conversion_rate':1.0,  'sell_price':75000.0},
      {'id':'u017','product_id':'p010','unit_name':'kg',   'conversion_rate':1.0,  'sell_price':300.0},
      {'id':'u018','product_id':'p010','unit_name':'sack', 'conversion_rate':40.0, 'sell_price':10000.0},
      {'id':'u019','product_id':'p011','unit_name':'pcs',  'conversion_rate':1.0,  'sell_price':65000.0},
      {'id':'u020','product_id':'p011','unit_name':'box',  'conversion_rate':16.0, 'sell_price':975000.0},
      {'id':'u021','product_id':'p012','unit_name':'meter','conversion_rate':1.0,  'sell_price':15000.0},
      {'id':'u022','product_id':'p012','unit_name':'roll', 'conversion_rate':100.0,'sell_price':1400000.0},
    ];
    for (final u in units) {
      await insert('product_units', u, replace: false);
    }
  }
}
