import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static String hashPassword(String password) {
    final bytes = utf8.encode('lpsm_salt_$password');
    return sha256.convert(bytes).toString();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lpsm_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (Platform.isWindows || Platform.isLinux) {
      final appDocDir = await getApplicationDocumentsDirectory();
      path = p.join(appDocDir.path, 'LaptopInventory', filePath);
      final dir = Directory(p.dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, filePath);
    }

    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) async {
        await _createAdditionalTables(db);
      },
    );
    try {
      await _createAdditionalTables(db);
    } catch (e) {
      debugPrint('createAdditionalTables notice: $e');
    }
    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. AppUser table
    await db.execute('''
      CREATE TABLE app_users (
        user_id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Category table
    await db.execute('''
      CREATE TABLE categories (
        category_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. Product table
    await db.execute('''
      CREATE TABLE products (
        product_id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        sku TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        specs TEXT NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        alert_threshold INTEGER NOT NULL DEFAULT 5,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
      )
    ''');

    // 4. Supplier table
    await db.execute('''
      CREATE TABLE suppliers (
        supplier_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        address TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 5. StockReceipt table
    await db.execute('''
      CREATE TABLE stock_receipts (
        receipt_id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        status TEXT NOT NULL,
        received_at TEXT NOT NULL,
        total_cost REAL NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id),
        FOREIGN KEY (created_by) REFERENCES app_users (user_id)
      )
    ''');

    // 6. StockReceiptItem table
    await db.execute('''
      CREATE TABLE stock_receipt_items (
        receipt_item_id TEXT PRIMARY KEY,
        receipt_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        qty INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        FOREIGN KEY (receipt_id) REFERENCES stock_receipts (receipt_id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (product_id)
      )
    ''');

    // 7. StockMovement table
    await db.execute('''
      CREATE TABLE stock_movements (
        movement_id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        type TEXT NOT NULL,
        qty_delta INTEGER NOT NULL,
        ref TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (product_id),
        FOREIGN KEY (created_by) REFERENCES app_users (user_id)
      )
    ''');

    // 8. Customer table
    await db.execute('''
      CREATE TABLE customers (
        customer_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        address TEXT,
        total_orders INTEGER NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0
      )
    ''');

    // 9. SalesOrder table
    await db.execute('''
      CREATE TABLE sales_orders (
        order_id TEXT PRIMARY KEY,
        customer_id TEXT,
        created_by TEXT NOT NULL,
        status TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
        FOREIGN KEY (created_by) REFERENCES app_users (user_id)
      )
    ''');

    // 10. SalesOrderItem table
    await db.execute('''
      CREATE TABLE sales_order_items (
        order_item_id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price_snapshot REAL NOT NULL,
        cost_snapshot REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES sales_orders (order_id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (product_id)
      )
    ''');

    // 11. Payment table
    await db.execute('''
      CREATE TABLE payments (
        payment_id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        method TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        ref_code TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES sales_orders (order_id)
      )
    ''');

    // 12. SalesReturn table
    await db.execute('''
      CREATE TABLE sales_returns (
        return_id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        approved_by TEXT,
        status TEXT NOT NULL,
        refund_total REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES sales_orders (order_id),
        FOREIGN KEY (approved_by) REFERENCES app_users (user_id)
      )
    ''');

    // 13. SalesReturnItem table
    await db.execute('''
      CREATE TABLE sales_return_items (
        return_item_id TEXT PRIMARY KEY,
        return_id TEXT NOT NULL,
        order_item_id TEXT NOT NULL,
        qty INTEGER NOT NULL,
        restockable INTEGER NOT NULL DEFAULT 1,
        refund_amount REAL NOT NULL,
        FOREIGN KEY (return_id) REFERENCES sales_returns (return_id) ON DELETE CASCADE,
        FOREIGN KEY (order_item_id) REFERENCES sales_order_items (order_item_id)
      )
    ''');

    // 14. AuditLog table
    await db.execute('''
      CREATE TABLE audit_logs (
        audit_id TEXT PRIMARY KEY,
        user_id TEXT,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        details TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES app_users (user_id)
      )
    ''');

    // 15. Store Settings table (Thay thế mục 6 sao lưu kỹ thuật)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_settings (
        id TEXT PRIMARY KEY,
        store_name TEXT NOT NULL,
        tax_code TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        vat_percent REAL NOT NULL DEFAULT 8.0,
        default_warranty_months INTEGER NOT NULL DEFAULT 24,
        invoice_footer TEXT,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5
      )
    ''');

    // 16. Promotions / Vouchers table (Thay thế mục 7 giám sát kỹ thuật)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS promotions (
        promo_id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        min_order_spend REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        valid_until TEXT
      )
    ''');

    // Seed Initial Data
    await _seedDatabase(db);
  }

  Future<void> _createAdditionalTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_settings (
        id TEXT PRIMARY KEY,
        store_name TEXT NOT NULL,
        tax_code TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        vat_percent REAL NOT NULL DEFAULT 8.0,
        default_warranty_months INTEGER NOT NULL DEFAULT 24,
        invoice_footer TEXT,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS promotions (
        promo_id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        min_order_spend REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        valid_until TEXT
      )
    ''');

    // Ensure member accounts exist
    await _seedUsersAndSettings(db);
  }

  Future<void> _upsertUser(
    Database db, {
    required String defaultUserId,
    required String username,
    required String passwordHash,
    required String role,
    required String fullName,
    required String now,
  }) async {
    final existing = await db.query(
      'app_users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (existing.isNotEmpty) {
      // Bảo toàn user_id cũ để tránh vi phạm FOREIGN KEY với audit_logs, stock_receipts, sales_orders
      await db.update(
        'app_users',
        {
          'password_hash': passwordHash,
          'role': role,
          'full_name': fullName,
          'is_active': 1,
        },
        where: 'username = ?',
        whereArgs: [username],
      );
    } else {
      await db.insert('app_users', {
        'user_id': defaultUserId,
        'username': username,
        'password_hash': passwordHash,
        'role': role,
        'full_name': fullName,
        'is_active': 1,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedUsersAndSettings(Database db) async {
    final now = DateTime.now().toIso8601String();
    final adminPass = hashPassword('admin123');
    final minhPass = hashPassword('minh123');
    final truongPass = hashPassword('truong123');
    final salesPass = hashPassword('sales123');

    // Chuyển hướng các khóa ngoại cũ (nếu có) trước khi dọn dẹp để không vi phạm ràng buộc
    try {
      await db.execute(
        "UPDATE audit_logs SET user_id = 'u_admin' WHERE user_id = 'u_ducanh'",
      );
      await db.execute(
        "UPDATE stock_receipts SET created_by = 'u_truong' WHERE created_by = 'u_inventory'",
      );
      await db.execute(
        "UPDATE stock_movements SET created_by = 'u_truong' WHERE created_by = 'u_inventory'",
      );
      await db.execute(
        "UPDATE audit_logs SET user_id = 'u_truong' WHERE user_id = 'u_inventory'",
      );
      // Xóa triệt để các tài khoản thừa/trùng lặp để danh sách chỉ có đúng 4 thành viên
      await db.delete(
        'app_users',
        where: "username IN ('ducanh', 'inventory')",
      );
    } catch (_) {}

    // 4 tài khoản phân hệ thành viên duy nhất - sử dụng upsert an toàn không xóa user_id
    await _upsertUser(
      db,
      defaultUserId: 'u_admin',
      username: 'admin',
      passwordHash: adminPass,
      role: 'admin',
      fullName: 'Đoàn Đức Anh (Quản Trị Hệ Thống)',
      now: now,
    );

    await _upsertUser(
      db,
      defaultUserId: 'u_minh',
      username: 'minh',
      passwordHash: minhPass,
      role: 'master_data',
      fullName: 'Bùi Quang Minh (Quản Lý Danh Mục & Khách Hàng)',
      now: now,
    );

    await _upsertUser(
      db,
      defaultUserId: 'u_truong',
      username: 'truong',
      passwordHash: truongPass,
      role: 'inventory_staff',
      fullName: 'Dương Văn Trường (Quản Lý Kho Hàng & Laptop)',
      now: now,
    );

    await _upsertUser(
      db,
      defaultUserId: 'u_sales',
      username: 'sales',
      passwordHash: salesPass,
      role: 'sales_staff',
      fullName: 'Đỗ Nhật Trương (Bán Hàng POS & Báo Cáo)',
      now: now,
    );

    // Seed default store settings nếu chưa tồn tại
    final existingSettings = await db.query(
      'store_settings',
      where: 'id = ?',
      whereArgs: ['default_shop'],
    );
    if (existingSettings.isEmpty) {
      await db.insert('store_settings', {
        'id': 'default_shop',
        'store_name': 'LPSM — Showroom Laptop & PC Chuyên Nghiệp',
        'tax_code': '0109988776',
        'phone': '0988.888.999',
        'email': 'hotro@lpsm-laptop.vn',
        'address': 'Số 1 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
        'vat_percent': 8.0,
        'default_warranty_months': 24,
        'invoice_footer': 'Cảm ơn quý khách đã tin tưởng mua hàng tại LPSM! Bảo hành chính hãng 1 đổi 1.',
        'low_stock_threshold': 5,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed promotions / vouchers nếu chưa tồn tại
    final existingPromos = await db.query('promotions');
    if (existingPromos.isEmpty) {
      await db.insert('promotions', {
        'promo_id': 'promo_01',
        'code': 'LAPTOP2026',
        'title': 'Ưu đãi Khai xuân Laptop Gaming',
        'discount_percent': 10.0,
        'discount_amount': 0.0,
        'min_order_spend': 15000000.0,
        'is_active': 1,
        'valid_until': '2026-12-31',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.insert('promotions', {
        'promo_id': 'promo_02',
        'code': 'SINHVIEN500K',
        'title': 'Trợ giá Học sinh - Sinh viên',
        'discount_percent': 0.0,
        'discount_amount': 500000.0,
        'min_order_spend': 10000000.0,
        'is_active': 1,
        'valid_until': '2026-12-31',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.insert('promotions', {
        'promo_id': 'promo_03',
        'code': 'VIPROG',
        'title': 'Voucher Tri ân Khách hàng VIP',
        'discount_percent': 5.0,
        'discount_amount': 0.0,
        'min_order_spend': 20000000.0,
        'is_active': 1,
        'valid_until': '2026-12-31',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed mẫu hóa đơn bán hàng đã hoàn thành (nếu chưa có) để phục vụ test chức năng Đổi trả (BR-10) & Báo cáo
    try {
      final completedCount =
          (await db.rawQuery(
                "SELECT COUNT(*) as c FROM sales_orders WHERE status = 'completed'",
              )).first['c']
              as int;
      if (completedCount == 0) {
        // Lấy customer_id và user_id hợp lệ từ DB để đảm bảo Foreign Key
        final custRows = await db.query('customers', limit: 1);
        final salesUserRows = await db.query(
          'app_users',
          where: "role = 'sales_staff' OR username = 'sales'",
          limit: 1,
        );

        if (custRows.isNotEmpty && salesUserRows.isNotEmpty) {
          final custId = custRows.first['customer_id'] as String;
          final salesUserId = salesUserRows.first['user_id'] as String;
          final prodRows = await db.query('products', limit: 1);
          final prodId = prodRows.isNotEmpty
              ? prodRows.first['product_id'] as String
              : 'p_rog_g16';

          final orderDate = DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String();
          await db.insert('sales_orders', {
            'order_id': 'ORD-COMPLETED-01',
            'customer_id': custId,
            'created_by': salesUserId,
            'status': 'completed',
            'subtotal': 31990000.0,
            'discount_percent': 0.0,
            'discount_amount': 0.0,
            'total': 31990000.0,
            'paid': 31990000.0,
            'notes':
                'Đơn hàng mua tại Showroom LPSM - Đã thanh toán chuyển khoản',
            'created_at': orderDate,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          await db.insert('sales_order_items', {
            'order_item_id': 'item_comp_01',
            'order_id': 'ORD-COMPLETED-01',
            'product_id': prodId,
            'qty': 1,
            'price_snapshot': 31990000.0,
            'cost_snapshot': 27500000.0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          await db.insert('payments', {
            'payment_id': 'pay_comp_01',
            'order_id': 'ORD-COMPLETED-01',
            'method': 'transfer',
            'amount': 31990000.0,
            'status': 'completed',
            'ref_code': 'VCB-998811',
            'created_at': orderDate,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    } catch (e) {
      // Ignored safely for foreign key boundary in legacy databases
    }
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();
    await _seedUsersAndSettings(db);

    // 2. Seed Categories
    await db.insert('categories', {
      'category_id': 'cat_gaming',
      'name': 'Laptop Gaming',
      'description': 'Laptop cấu hình cao chơi game và đồ họa 3D',
      'is_active': 1,
    });
    await db.insert('categories', {
      'category_id': 'cat_office',
      'name': 'Laptop Văn Phòng & Doanh Nhân',
      'description': 'Laptop mỏng nhẹ, pin trâu, bảo mật cao',
      'is_active': 1,
    });
    await db.insert('categories', {
      'category_id': 'cat_pc',
      'name': 'Máy Tính Để Bàn (PC)',
      'description': 'PC đồng bộ & PC lắp ráp sẵn',
      'is_active': 1,
    });
    await db.insert('categories', {
      'category_id': 'cat_acc',
      'name': 'Phụ Kiện & Linh Kiện',
      'description': 'Chuột, phím, tai nghe, RAM, SSD',
      'is_active': 1,
    });

    // 3. Seed Suppliers
    await db.insert('suppliers', {
      'supplier_id': 'sup_synnex',
      'name': 'FPT Synnex Distribution',
      'phone': '02473006666',
      'email': 'contact@synnexfpt.com',
      'address': 'Tòa nhà FPT Cầu Giấy, Hà Nội',
      'is_active': 1,
    });
    await db.insert('suppliers', {
      'supplier_id': 'sup_dgw',
      'name': 'Digiworld Corporation (DGW)',
      'phone': '02839290059',
      'email': 'info@digiworld.com.vn',
      'address': '195 Cô Bắc, Quận 1, TP. HCM',
      'is_active': 1,
    });
    await db.insert('suppliers', {
      'supplier_id': 'sup_phongvu',
      'name': 'Phong Vũ Trading',
      'phone': '18006867',
      'email': 'cskh@phongvu.vn',
      'address': '264 Nguyễn Thị Minh Khai, Q3, TP. HCM',
      'is_active': 1,
    });

    // 4. Seed Products
    final productsData = [
      {
        'product_id': 'p_rog_g16',
        'category_id': 'cat_gaming',
        'sku': 'LAP-ROG-G16',
        'name': 'Asus ROG Strix G16 G614JV',
        'brand': 'Asus',
        'specs':
            'i7-13650HX / 16GB DDR5 / 512GB SSD / RTX 4060 8GB / 165Hz FHD+',
        'price': 32990000.0,
        'cost': 27500000.0,
        'stock': 12,
        'alert_threshold': 4,
        'is_active': 1,
      },
      {
        'product_id': 'p_mac_m3',
        'category_id': 'cat_office',
        'sku': 'LAP-MAC-M3',
        'name': 'MacBook Pro 14 M3 2023',
        'brand': 'Apple',
        'specs':
            'Apple M3 Pro / 18GB RAM / 512GB SSD / Liquid Retina XDR 120Hz',
        'price': 49990000.0,
        'cost': 43000000.0,
        'stock': 6,
        'alert_threshold': 3,
        'is_active': 1,
      },
      {
        'product_id': 'p_dell_xps15',
        'category_id': 'cat_office',
        'sku': 'LAP-DELL-XPS15',
        'name': 'Dell XPS 15 9530',
        'brand': 'Dell',
        'specs': 'i7-13700H / 32GB RAM / 1TB SSD / RTX 4050 / OLED 3.5K Touch',
        'price': 46500000.0,
        'cost': 39000000.0,
        'stock': 4, // Below threshold
        'alert_threshold': 5,
        'is_active': 1,
      },
      {
        'product_id': 'p_thinkpad_x1',
        'category_id': 'cat_office',
        'sku': 'LAP-LEN-X1C11',
        'name': 'Lenovo ThinkPad X1 Carbon Gen 11',
        'brand': 'Lenovo',
        'specs': 'i7-1355U / 16GB LPDDR5 / 512GB SSD / 14 inch 2.8K OLED',
        'price': 38900000.0,
        'cost': 32000000.0,
        'stock': 8,
        'alert_threshold': 4,
        'is_active': 1,
      },
      {
        'product_id': 'p_hp_victus',
        'category_id': 'cat_gaming',
        'sku': 'LAP-HP-VIC16',
        'name': 'HP Victus 16 2023',
        'brand': 'HP',
        'specs':
            'Ryzen 7 7840HS / 16GB DDR5 / 512GB SSD / RTX 4050 6GB / 144Hz',
        'price': 22500000.0,
        'cost': 18500000.0,
        'stock': 2, // Low stock
        'alert_threshold': 5,
        'is_active': 1,
      },
      {
        'product_id': 'p_pc_gaming',
        'category_id': 'cat_pc',
        'sku': 'PC-CM-ULTRA',
        'name': 'PC Gaming CoolerMaster Ultra Gaming',
        'brand': 'Custom Build',
        'specs': 'i5-13400F / B760M / 16GB DDR4 / RTX 4060 8GB / 650W Bronze',
        'price': 19990000.0,
        'cost': 16200000.0,
        'stock': 5,
        'alert_threshold': 3,
        'is_active': 1,
      },
      {
        'product_id': 'p_mouse_mx3s',
        'category_id': 'cat_acc',
        'sku': 'ACC-LOG-MX3S',
        'name': 'Chuột Không Dây Logitech MX Master 3S',
        'brand': 'Logitech',
        'specs':
            'Cảm biến Darkfield 8K DPI, Quiet Clicks, Sạc Type-C, Bluetooth',
        'price': 2190000.0,
        'cost': 1650000.0,
        'stock': 25,
        'alert_threshold': 10,
        'is_active': 1,
      },
      {
        'product_id': 'p_keyboard_fl',
        'category_id': 'cat_acc',
        'sku': 'ACC-FL-OG87',
        'name': 'Bàn Phím Cơ FL-Esports OG87 Retro',
        'brand': 'FL-Esports',
        'specs': 'Switch Kailh Box, 3 Mode kết nối, Gasket mount, Hotswap',
        'price': 1850000.0,
        'cost': 1350000.0,
        'stock': 15,
        'alert_threshold': 5,
        'is_active': 1,
      },
      {
        'product_id': 'p_ssd_990pro',
        'category_id': 'cat_acc',
        'sku': 'ACC-SSD-990P1T',
        'name': 'Ổ Cứng SSD Samsung 990 Pro 1TB NVMe PCIe 4.0',
        'brand': 'Samsung',
        'specs': 'Đọc 7450 MB/s, Ghi 6900 MB/s, Chuẩn M.2 2280',
        'price': 2750000.0,
        'cost': 2100000.0,
        'stock': 18,
        'alert_threshold': 5,
        'is_active': 1,
      },
    ];

    for (var prod in productsData) {
      await db.insert('products', prod);
    }

    // 5. Seed Customers
    await db.insert('customers', {
      'customer_id': 'cust_01',
      'name': 'Nguyễn Văn An',
      'phone': '0912345678',
      'email': 'an.nguyen@gmail.com',
      'address': 'Hoàn Kiếm, Hà Nội',
      'total_orders': 1,
      'total_spent': 32990000.0,
    });
    await db.insert('customers', {
      'customer_id': 'cust_02',
      'name': 'Trần Thị Mai',
      'phone': '0987654321',
      'email': 'mai.tran@gmail.com',
      'address': 'Cầu Giấy, Hà Nội',
      'total_orders': 1,
      'total_spent': 2190000.0,
    });
    await db.insert('customers', {
      'customer_id': 'cust_03',
      'name': 'Lê Hoàng Long',
      'phone': '0903112233',
      'email': 'long.le@yahoo.com',
      'address': 'Đống Đa, Hà Nội',
      'total_orders': 0,
      'total_spent': 0.0,
    });

    // 6. Seed Sample Stock Receipt
    await db.insert('stock_receipts', {
      'receipt_id': 'rcpt_001',
      'supplier_id': 'sup_synnex',
      'created_by': 'u_truong',
      'status': 'posted',
      'received_at': now,
      'total_cost': 137500000.0,
      'notes': 'Nhập kho lô đầu tháng 11 theo hợp đồng synnex',
    });
    await db.insert('stock_receipt_items', {
      'receipt_item_id': 'rcpt_item_01',
      'receipt_id': 'rcpt_001',
      'product_id': 'p_rog_g16',
      'qty': 5,
      'unit_cost': 27500000.0,
    });

    // 7. Seed Stock Movements
    await db.insert('stock_movements', {
      'movement_id': 'mov_001',
      'product_id': 'p_rog_g16',
      'created_by': 'u_truong',
      'type': 'receipt',
      'qty_delta': 5,
      'ref': 'Phiếu nhập #rcpt_001',
      'created_at': now,
    });

    // 8. Seed Initial Audit Log
    await db.insert('audit_logs', {
      'audit_id': 'aud_001',
      'user_id': 'u_admin',
      'action': 'SYSTEM_INIT',
      'entity': 'Database',
      'details': 'Khởi tạo cơ sở dữ liệu LPSM và nạp danh mục ban đầu',
      'created_at': now,
    });
  }
}
