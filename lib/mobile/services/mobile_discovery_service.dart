import 'package:nsd/nsd.dart' as nsd;
import 'package:nsd/nsd.dart' show Discovery, Service;
import 'dart:async';

class MobileDiscoveryService {
  final Function(String) onLog;
  Discovery? _discovery;
  List<Service> knownServices = [];
  final StreamController<List<Service>> _servicesController =
      StreamController<List<Service>>.broadcast();

  Stream<List<Service>> get servicesStream => _servicesController.stream;

  MobileDiscoveryService({required this.onLog});

  Future<void> startDiscovery() async {
    try {
      if (_discovery != null) {
        onLog('Discovery already running, restarting...');
        await stopDiscovery();
      }

      onLog('Starting discovery for _dockerportal._tcp');
      _discovery = await nsd.startDiscovery('_dockerportal._tcp');

      _discovery!.addListener(() {
        knownServices = _discovery!.services;
        onLog('Services updated: ${knownServices.length} found');
        _servicesController.add(knownServices);
      });
    } catch (e) {
      onLog('Error starting discovery: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
      knownServices.clear();
      _servicesController.add([]);
      onLog('Discovery stopped');
    }
  }
}
