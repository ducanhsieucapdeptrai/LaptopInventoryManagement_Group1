// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// LPSM Local Backend Server & Cloud Alternative for PRM393
/// Runs on host Windows at port 8080.
/// Accessible from Android Emulator via: http://10.0.2.2:8080
/// Accessible from Desktop / Web via: http://127.0.0.1:8080
void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('================================================================');
  print('  LPSM Cloud Backend Server (PRM393 Group 1)');
  print('  Listening on: http://${server.address.address}:${server.port}');
  print('  Android Emulator URL: http://10.0.2.2:${server.port}');
  print('  Desktop / Web URL:    http://127.0.0.1:${server.port}');
  print('================================================================');

  // In-memory cloud datastore
  final List<Map<String, dynamic>> syncedOrders = [];
  final List<Map<String, dynamic>> backupArchives = [];

  await for (HttpRequest request in server) {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, X-Client-App',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    final path = request.uri.path;
    print('[${DateTime.now().toIso8601String()}] ${request.method} $path');

    try {
      if (path == '/api/v1/health' && request.method == 'GET') {
        _sendJson(request.response, {
          'status': 'healthy',
          'server': 'LPSM-Dart-Cloud-Server',
          'timestamp': DateTime.now().toIso8601String(),
          'active_connections': 1,
          'synced_orders_count': syncedOrders.length,
        });
      } else if (path.startsWith('/api/v1/warranty/') &&
          request.method == 'GET') {
        final sku = path.replaceFirst('/api/v1/warranty/', '');
        _sendJson(request.response, {
          'status': 'success',
          'sku': sku,
          'genuine_verified': true,
          'warranty_months': 24,
          'distributor': 'FPT Synnex / Digiworld Corporation',
          'server_timestamp': DateTime.now().toIso8601String(),
        });
      } else if (path == '/api/v1/orders/sync' && request.method == 'POST') {
        final bodyStr = await utf8.decodeStream(request);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        body['cloud_synced_at'] = DateTime.now().toIso8601String();
        syncedOrders.add(body);

        _sendJson(request.response, {
          'status': 'success',
          'message': 'Đơn hàng đã được đồng bộ an toàn lên Cloud Server',
          'order_id': body['order_id'],
          'server_total_synced': syncedOrders.length,
        });
      } else if (path == '/api/v1/inventory/sync' && request.method == 'POST') {
        final bodyStr = await utf8.decodeStream(request);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        _sendJson(request.response, {
          'status': 'success',
          'message': 'Số dư kho hàng đã được đồng bộ lên Cloud BaaS',
          'product_count': body['product_count'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else if (path == '/api/v1/cloud/alerts' && request.method == 'GET') {
        _sendJson(request.response, {
          'status': 'success',
          'cloud_status': 'CONNECTED',
          'alerts': [
            'Firebase Cloud: Sẵn sàng trực tuyến',
            'Hệ thống ERP: Kết nối đồng bộ ổn định',
          ],
        });
      } else if (path == '/api/v1/backup' && request.method == 'POST') {
        final bodyStr = await utf8.decodeStream(request);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final archiveId =
            'cloud_backup_${DateTime.now().millisecondsSinceEpoch}';
        backupArchives.add({
          'archive_id': archiveId,
          'data': body,
          'created_at': DateTime.now().toIso8601String(),
        });

        _sendJson(request.response, {
          'status': 'success',
          'archive_id': archiveId,
          'cloud_url': 'cloud://lpsm-storage.internal/backups/$archiveId.db',
          'message': 'Sao lưu SQLite thành công lên Cloud Storage',
        });
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _sendJson(request.response, {'error': 'Endpoint not found'});
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      _sendJson(request.response, {'error': e.toString()});
    }
  }
}

void _sendJson(HttpResponse response, Map<String, dynamic> data) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  response.close();
}
