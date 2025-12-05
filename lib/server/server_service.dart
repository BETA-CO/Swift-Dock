import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

class ServerService {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  final Function(String) onLog;

  ServerService({required this.onLog});

  Future<String?> getIpAddress() async {
    try {
      // Try getting Wi-Fi IP first
      final info = NetworkInfo();
      var ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;

      // Fallback: Iterate network interfaces for Desktop/Ethernet
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        // Filter out loopback and common virtual adapters if possible,
        // but generally just picking the first non-loopback IPv4 is decent for a start.
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      onLog('Error fetching IP: $e');
    }
    return 'Unknown IP';
  }

  Future<void> startServer() async {
    var handler = webSocketHandler((webSocket, protocol) {
      final channel = webSocket as WebSocketChannel;
      _clients.add(channel);
      onLog('New client connected');

      webSocket.stream.listen(
        (message) {
          onLog('Received: $message');
        },
        onDone: () {
          _clients.remove(webSocket);
          onLog('Client disconnected');
        },
      );
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      onLog('Server running on port 8080');
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048 ||
          e.message.contains('Address already in use')) {
        onLog('Error: Port 8080 is busy. Close other instances.');
      } else {
        onLog('Error starting server: $e');
      }
    } catch (e) {
      onLog('Error starting server: $e');
    }
  }

  void broadcast(String message) {
    for (final client in _clients) {
      try {
        client.sink.add(message);
      } catch (e) {
        onLog('Error broadcasting to client: $e');
      }
    }
  }

  void stopServer() {
    _server?.close();
    for (var client in _clients) {
      client.sink.close(status.goingAway);
    }
    _clients.clear();
    onLog('Server stopped');
  }
}
