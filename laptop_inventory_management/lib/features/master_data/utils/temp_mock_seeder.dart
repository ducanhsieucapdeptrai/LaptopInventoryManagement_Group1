// Temporary helper for seeding master data in testing
import '../../../core/models/customer.dart';

class TempMockSeeder {
  static List<Customer> generateSampleCustomers() {
    return [
      Customer(
        customerId: 'CUST-001',
        name: 'Nguyễn Văn Test',
        phone: '0912345678',
        email: 'test1@example.com',
        address: 'Hà Nội',
      ),
      Customer(
        customerId: 'CUST-002',
        name: 'Trần Thị Demo',
        phone: '0987654321',
        email: 'test2@example.com',
        address: 'Đà Nẵng',
      ),
    ];
  }
}
