import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'qr_scanner_screen.dart';
import '../../../shared/widgets.dart';

class ConnectionScreen extends StatefulWidget {
  final Function(String) onConnect;
  final List<Service> discoveredServices;

  const ConnectionScreen({
    super.key,
    required this.onConnect,
    this.discoveredServices = const [],
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool _showManualInput = false;

  void _scanQrCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (result != null && result is Map && result.containsKey('ip')) {
      widget.onConnect(result['ip']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Header
          Text(
            'Connect to\nSwift Dock',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control your desktop from your phone',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 40),

          // Main Action: Scan QR
          GlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            color: Theme.of(context).primaryColor,
            opacity: 0.2,
            child: InkWell(
              onTap: _scanQrCode,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to camera scan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Manual / Discovery Toggle
          Row(
            children: [
              const Text(
                'Nearby Devices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (widget.discoveredServices.isEmpty)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: widget.discoveredServices.isEmpty
                ? Center(
                    child: Text(
                      'Searching for devices...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: widget.discoveredServices.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final service = widget.discoveredServices[index];
                      final ip = service.addresses?.isNotEmpty == true
                          ? service.addresses!.first.address
                          : service.host ?? 'Unknown IP';
                      final name = service.name ?? 'Unknown Device';

                      return GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        padding: EdgeInsets.zero,
                        color: Theme.of(context).cardColor,
                        opacity: 0.1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onConnect(ip),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.desktop_windows_rounded,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        ip,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Manual IP Entry Toggle
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showManualInput = !_showManualInput;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showManualInput
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  const SizedBox(width: 8),
                  const Text("Enter IP Manually"),
                ],
              ),
            ),
          ),

          if (_showManualInput)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassContainer(
                opacity: 0.1,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "IP Address (e.g. 192.168.1.10)",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.wifi, color: Colors.white54),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) widget.onConnect(value);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
