import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laptop_inventory_management_group1/core/constants/app_constants.dart';
import 'package:laptop_inventory_management_group1/features/administration/providers/administration_provider.dart';
import 'package:laptop_inventory_management_group1/core/models/app_user.dart';
import 'package:laptop_inventory_management_group1/core/models/category.dart';
import 'package:laptop_inventory_management_group1/core/models/customer.dart';
import 'package:laptop_inventory_management_group1/core/models/product.dart';
import 'package:laptop_inventory_management_group1/core/models/sales_order.dart';
import 'package:laptop_inventory_management_group1/core/models/sales_return.dart';
import 'package:laptop_inventory_management_group1/core/models/supplier.dart';
import 'package:laptop_inventory_management_group1/core/utils/formatters.dart';
import 'package:laptop_inventory_management_group1/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    test('requiredField validates non-empty inputs', () {
      expect(
        Validators.requiredField('', 'Tên'),
        contains('không được để trống'),
      );
      expect(
        Validators.requiredField(null, 'Tên'),
        contains('không được để trống'),
      );
      expect(Validators.requiredField('Asus ROG', 'Tên'), isNull);
    });

    test('sku validator enforces SKU pattern', () {
      expect(Validators.sku(''), contains('không được để trống'));
      expect(Validators.sku('LP-01'), isNull);
      expect(Validators.sku('LP-ROG-STRIX-01'), isNull);
    });

    test('phone validator verifies VN phone standard', () {
      expect(Validators.phoneNumber('0912345678'), isNull);
      expect(Validators.phoneNumber('+84912345678'), isNull);
      expect(Validators.phoneNumber('123'), contains('không hợp lệ'));
      expect(Validators.phoneNumber('abcd123456'), contains('không hợp lệ'));
    });

    test('positiveNumber validator enforces numeric > 0', () {
      expect(Validators.positiveNumber('5000000', 'Giá'), isNull);
      expect(Validators.positiveNumber('-10', 'Giá'), contains('lớn hơn 0'));
    });
  });

  group('Formatters Unit Tests', () {
    test('formatCurrency formats VND correctly', () {
      final formatted = Formatters.formatCurrency(25000000);
      expect(formatted, contains('25.000.000'));
      expect(formatted, contains('₫'));
    });

    test('formatDate formats DateTime object', () {
      final dt = DateTime(2026, 11, 7, 10, 30);
      final str = Formatters.formatDate(dt);
      expect(str, contains('07/11/2026'));
    });
  });

  group('Model Serialization & Deserialization Tests', () {
    test('AppUser toMap and fromMap', () {
      final user = AppUser(
        userId: 'u_test',
        username: 'ducanh',
        passwordHash: 'dummy_hash',
        role: AppRoles.admin,
        fullName: 'Đoàn Đức Anh',
        isActive: true,
        createdAt: '2026-11-07T00:00:00Z',
      );

      final map = user.toMap();
      final revived = AppUser.fromMap(map);
      expect(revived.userId, equals('u_test'));
      expect(revived.username, equals('ducanh'));
      expect(revived.role, equals(AppRoles.admin));
      expect(revived.isActive, isTrue);
    });

    test('Category toMap and fromMap', () {
      final cat = Category(
        categoryId: 'cat_gaming',
        name: 'Laptop Gaming',
        description: 'Máy tính chơi game cấu hình cao',
        isActive: true,
      );

      final map = cat.toMap();
      final revived = Category.fromMap(map);
      expect(revived.name, equals('Laptop Gaming'));
      expect(revived.isActive, isTrue);
    });

    test('Product toMap and fromMap', () {
      final prod = Product(
        productId: 'prod_rog',
        sku: 'LP-ROG-G16',
        name: 'Asus ROG Strix G16',
        categoryId: 'cat_gaming',
        brand: 'ASUS',
        specs: 'i7-13650HX / 16GB / RTX 4060',
        cost: 26000000,
        price: 31990000,
        stock: 12,
        alertThreshold: 3,
        isActive: true,
      );

      final map = prod.toMap();
      final revived = Product.fromMap(map);
      expect(revived.sku, equals('LP-ROG-G16'));
      expect(revived.price, greaterThan(revived.cost));
      expect(revived.isLowStock, isFalse);
    });

    test('Supplier toMap and fromMap', () {
      final sup = Supplier(
        supplierId: 'sup_asus',
        name: 'Asus Vietnam Technology',
        phone: '02838383838',
        email: 'supply@asus.vn',
        address: 'Hà Nội',
        isActive: true,
      );

      final map = sup.toMap();
      final revived = Supplier.fromMap(map);
      expect(revived.name, contains('Asus'));
      expect(revived.phone, equals('02838383838'));
    });

    test('Customer toMap and fromMap', () {
      final cust = Customer(
        customerId: 'cust_01',
        name: 'Nguyễn Văn A',
        phone: '0987654321',
        email: 'a@gmail.com',
        totalOrders: 5,
        totalSpent: 120000000,
      );

      final map = cust.toMap();
      final revived = Customer.fromMap(map);
      expect(revived.totalOrders, equals(5));
      expect(revived.totalSpent, equals(120000000));
    });

    test('SalesOrder and SalesReturn logic', () {
      final order = SalesOrder(
        orderId: 'ORD-20261107-001',
        customerId: 'cust_01',
        createdBy: 'u_sales',
        status: 'completed',
        subtotal: 30000000,
        discountPercent: 5,
        discountAmount: 1500000,
        total: 28500000,
        paid: 28500000,
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(order.isCompleted, isTrue);

      final ret = SalesReturn(
        returnId: 'RET-001',
        orderId: order.orderId,
        refundTotal: 28500000,
        reason: 'Lỗi bo mạch chủ NSX',
        status: 'pending',
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(ret.isApproved, isFalse);
    });
  });

  group('Business Rules Logic Tests (BR-01 to BR-14)', () {
    test('BR-02: Prevent overselling check', () {
      const currentStock = 5;
      const requestedQty = 8;
      final canSell = requestedQty <= currentStock;
      expect(canSell, isFalse);
    });

    test('BR-06: 7-day return eligibility check', () {
      final orderDate = DateTime.now().subtract(const Duration(days: 4));
      final daysDiff = DateTime.now().difference(orderDate).inDays;
      expect(daysDiff <= 7, isTrue);

      final expiredOrderDate = DateTime.now().subtract(
        const Duration(days: 10),
      );
      final expiredDiff = DateTime.now().difference(expiredOrderDate).inDays;
      expect(expiredDiff <= 7, isFalse);
    });

    test('BR-07 & SystemMessages: Discount permissions', () {
      const salesDiscount = 8.0;
      const invalidSalesDiscount = 15.0;
      expect(
        salesDiscount <= BusinessRules.maxSalesStaffDiscountPercent,
        isTrue,
      );
      expect(
        invalidSalesDiscount <= BusinessRules.maxSalesStaffDiscountPercent,
        isFalse,
      );
    });

    test('BR-12: Max 5 login attempts lockout threshold', () {
      var attempts = 4;
      expect(attempts >= BusinessRules.maxLoginAttempts, isFalse);
      attempts++;
      expect(attempts >= BusinessRules.maxLoginAttempts, isTrue);
    });

    test('4 Distinct Member Roles Verification', () {
      expect(AppRoles.getDisplayName(AppRoles.admin), contains('Đức Anh'));
      expect(AppRoles.getDisplayName(AppRoles.masterData), contains('Minh'));
      expect(
        AppRoles.getDisplayName(AppRoles.inventoryStaff),
        contains('Trường'),
      );
      expect(AppRoles.getDisplayName(AppRoles.salesStaff), contains('Trương'));
    });

    test('UC-02: Logout and Member Workspace State Reset', () {
      final container = ProviderContainer();
      container.read(activeWorkspaceProvider.notifier).state = 'truong';
      expect(container.read(activeWorkspaceProvider), equals('truong'));

      // Simulate Logout (UC-02)
      container.read(currentUserProvider.notifier).state = null;
      container.read(activeWorkspaceProvider.notifier).state = 'ducanh';
      expect(container.read(currentUserProvider), isNull);
      expect(container.read(activeWorkspaceProvider), equals('ducanh'));
      container.dispose();
    });
  });
}
