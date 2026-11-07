class Validators {
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    return null;
  }

  static String? positiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    final clean = value.trim().replaceAll(RegExp(r'[,\s]'), '');
    final num? parsed = num.tryParse(clean);
    if (parsed == null || parsed <= 0) {
      return '$fieldName phải lớn hơn 0';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName không được để trống';
    }
    final clean = value.trim().replaceAll(RegExp(r'[,\s]'), '');
    final num? parsed = num.tryParse(clean);
    if (parsed == null || parsed < 0) {
      return '$fieldName không được âm';
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional in some contexts (e.g. walk-in customer)
    }
    final cleanPhone = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(cleanPhone)) {
      return 'Số điện thoại không hợp lệ (10 chữ số)';
    }
    return null;
  }

  static String? sku(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mã SKU không được để trống';
    }
    if (value.trim().length < 3) {
      return 'Mã SKU tối thiểu 3 ký tự';
    }
    return null;
  }
}
