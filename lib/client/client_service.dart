import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ClientService {
  WebSocketChannel? _channel;
  final Function(String) onLog;
  final Function(String)? onMessage;

  ClientService({required this.onLog, this.onMessage});

  void connect(String ipAddress) {
    if (ipAddress.isEmpty) return;

    final uri = Uri.parse('ws://$ipAddress:8080');
    try {
      _channel = WebSocketChannel.connect(uri);
      onLog('Connected to $ipAddress');

      _channel!.stream.listen(
        (message) {
          if (onMessage != null) {
            onMessage!(message.toString());
          } else {
            onLog('Server says: $message');
          }
        },
        onDone: () {
          onLog('Disconnected');
        },
        onError: (error) {
          onLog('Connection error: $error');
        },
      );
    } catch (e) {
      onLog('Error connecting: $e');
    }
  }

  void sendCommand(String command) {
    if (_channel != null) {
      _channel!.sink.add(command);
      onLog('Sent: $command');
    } else {
      onLog('Not connected');
    }
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }
}
