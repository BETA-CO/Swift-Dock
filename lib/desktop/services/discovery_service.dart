import 'package:nsd/nsd.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:convert';

class DiscoveryService {
  final Function(String) onLog;
  Registration? _registration;

  DiscoveryService({required this.onLog});

  Future<void> registerService(int port, String serviceName) async {
    try {
      // It's helpful to get the actual IP to debug/confirm,
      // though mDNS handles the resolution.
      final info = NetworkInfo();
      var ip = await info.getWifiIP();
      onLog('Preparing to register service on IP: $ip, Port: $port');

      // The service type must be in the format: _<name>._<protocol>
      // We'll use _dockerportal._tcp (internal underscores can be problematic)
      const String serviceType = '_dockerportal._tcp';

      _registration = await register(
        Service(
          name: serviceName, // Use custom name
          type: serviceType,
          port: port,
          txt: {'os': utf8.encode('windows')}, // Optional metadata
        ),
      );

      onLog(
        'Service registered: ${_registration?.service.name} (type: $serviceType, port: $port)',
      );
    } catch (e) {
      onLog('Error registering mDNS service: $e');
    }
  }

  Future<void> unregisterService() async {
    if (_registration != null) {
      try {
        await unregister(_registration!);
        _registration = null;
        onLog('Service unregistered');
      } catch (e) {
        onLog('Error unregistering service: $e');
      }
    }
  }
}
