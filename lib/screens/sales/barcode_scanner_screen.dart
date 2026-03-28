import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/barcode_server_service.dart';

/// Scanner screen usando el companion web en lugar de mobile_scanner.
/// Funciona en Linux, Windows y macOS (y tambien en movil via la pagina web).
/// Cualquier barcode enviado desde la pagina web cierra la pantalla con el valor.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = BarcodeServerService.instance.barcodeStream.listen((barcode) {
      if (mounted) Navigator.of(context).pop(barcode);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = BarcodeServerService.instance.serverUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Codigo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: url == null
              ? _buildNoServer()
              : _buildScannerInfo(context, url),
        ),
      ),
    );
  }

  Widget _buildNoServer() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off, color: Colors.white54, size: 72),
        SizedBox(height: 20),
        Text(
          'Servidor no disponible.\nVerifica la conexion WiFi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildScannerInfo(BuildContext context, String url) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone_iphone, color: Colors.white70, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Abre esta URL en Safari de tu iPhone:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 10),
        SelectableText(
          url,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Esperando escaneo...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}
