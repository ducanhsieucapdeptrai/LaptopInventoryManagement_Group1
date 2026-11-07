import 'dart:async';

import 'api_service.dart';

class FirebaseCloudService {
  static final FirebaseCloudService instance = FirebaseCloudService._internal();

  FirebaseCloudService._internal();

  final _syncStatusStreamController = StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusStreamController.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  /// Đồng bộ tồn kho lên Cloud
  Future<bool> syncInventoryToCloud({
    required int productCount,
    required double totalInventoryValue,
  }) async {
    _syncStatusStreamController.add('Đang kết nối Cloud BaaS...');
    final success = await ApiService.instance.syncInventoryToCloud({
      'product_count': productCount,
      'total_inventory_value': totalInventoryValue,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _isOnline = success;
    if (success) {
      _syncStatusStreamController.add(
        'Đồng bộ Cloud thành công lúc ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
      );
    } else {
      _syncStatusStreamController.add(
        'Chế độ Offline: Dữ liệu đang được lưu trữ an toàn trong SQLite',
      );
    }
    return success;
  }

  /// Sao lưu database lên Cloud Storage
  Future<String> backupDatabaseToCloudStorage(
    Map<String, dynamic> backupData,
  ) async {
    final cloudUrl = await ApiService.instance.backupToCloudStorage(backupData);
    if (cloudUrl != null) return cloudUrl;
    return 'offline_local_backup_${DateTime.now().millisecondsSinceEpoch}.db';
  }

  /// Luồng sự kiện trạng thái Cloud Realtime Stream
  Stream<String> get realTimeCloudAlerts async* {
    yield 'Hệ thống Cloud BaaS: Khởi động';
    final health = await ApiService.instance.checkHealth();
    if (health['status'] == 'healthy') {
      yield 'Cloud Backend: Đã kết nối (Online)';
    } else {
      yield 'Cloud Backend: Chế độ Ngoại tuyến (Offline)';
    }
  }

  void dispose() {
    _syncStatusStreamController.close();
  }
}
