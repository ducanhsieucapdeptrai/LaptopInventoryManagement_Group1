// Application constants, System Messages, and Business Rules based on SRS (LPSM)

class AppRoles {
  static const String admin = 'admin';
  static const String masterData = 'master_data';
  static const String inventoryStaff = 'inventory_staff';
  static const String salesStaff = 'sales_staff';

  static String getDisplayName(String role) {
    switch (role) {
      case admin:
        return 'Quản trị viên (Đức Anh)';
      case masterData:
        return 'Quản lý danh mục & Đối tác (Minh)';
      case inventoryStaff:
        return 'Nhân viên quản lý kho (Trường)';
      case salesStaff:
        return 'Nhân viên bán hàng & POS (Trương)';
      default:
        return 'Thành viên cửa hàng';
    }
  }
}

class SystemMessages {
  static const String msg01 =
      'Vui lòng nhập cả tên đăng nhập và mật khẩu. (MSG-01)';
  static const String msg02 =
      'Thông tin đăng nhập không hợp lệ. Vui lòng thử lại. (MSG-02)';
  static const String msg03 =
      'Tài khoản này đã bị vô hiệu hóa. Liên hệ quản trị viên. (MSG-03)';
  static const String msg04 =
      'Đăng nhập sai quá 5 lần. Tài khoản tạm khóa 15 phút. (MSG-04)';
  static const String msg05 =
      'Mã SKU đã tồn tại. Vui lòng nhập SKU khác. (MSG-05)';
  static const String msg06 =
      'Vui lòng chọn sản phẩm hợp lệ và số lượng lớn hơn 0. (MSG-06)';
  static const String msg07 =
      'Không đủ tồn kho cho một hoặc nhiều sản phẩm trong đơn. (MSG-07)';
  static const String msg08 =
      'Số tiền thanh toán chưa khớp với số tiền cần trả. (MSG-08)';
  static const String msg09 =
      'Bạn không có quyền áp dụng mức chiết khấu này (Tối đa 10% với Sales, 30% với Admin). (MSG-09)';
  static const String msg10 =
      'Giao dịch thất bại. Không có thay đổi nào được lưu. (MSG-10)';
  static const String msg11 =
      'Số lượng trả hàng vượt quá số lượng hợp lệ còn lại. (MSG-11)';
  static const String msg12 =
      'Không thể xuất file CSV. Vui lòng kiểm tra quyền truy cập. (MSG-12)';
  static const String msg13 =
      'Hành động này chỉ dành riêng cho Quản trị viên (Admin). (MSG-13)';
  static const String msg14 =
      'Không tìm thấy dữ liệu nào phù hợp với bộ lọc. (MSG-14)';
}

class BusinessRules {
  // BR-06: 7-day return policy
  static const int salesReturnValidDays = 7;
  // BR-07: Sales Staff max discount is 10%, Admin max discount is 30%
  static const double maxSalesStaffDiscountPercent = 10.0;
  static const double maxAdminDiscountPercent = 30.0;
  static const int maxLoginAttempts = 5;
  static const int lockoutMinutes = 15;
}
