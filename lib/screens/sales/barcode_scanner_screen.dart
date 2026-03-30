import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/barcode_server_service.dart';

/// Pantalla de escaneo inteligente:
/// - iOS / Android → cámara nativa con mobile_scanner
/// - Desktop (Linux/Windows/macOS) → servidor web + QR companion
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  static bool get _isMobile =>
      !const bool.fromEnvironment('dart.library.html') &&
      (Platform.isIOS || Platform.isAndroid);

  @override
  Widget build(BuildContext context) {
    if (_isMobile) {
      return const _NativeScannerScreen();
    }
    return const _WebCompanionScannerScreen();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVO (iOS / Android) — mobile_scanner
// ═══════════════════════════════════════════════════════════════════════════════

class _NativeScannerScreen extends StatefulWidget {
  const _NativeScannerScreen();

  @override
  State<_NativeScannerScreen> createState() => _NativeScannerScreenState();
}

class _NativeScannerScreenState extends State<_NativeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _detected = false;

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value != null && value.isNotEmpty) {
      _detected = true;
      _controller.stop();
      Navigator.of(context).pop(value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, __) => IconButton(
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: state.torchState == TorchState.on
                    ? Colors.yellow
                    : Colors.white,
              ),
              onPressed: () => _controller.toggleTorch(),
              tooltip: 'Linterna',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          CustomPaint(size: Size.infinite, painter: _ScanOverlayPainter()),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Apunta al código de barras',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'EAN-8 · EAN-13 · Code-128',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEB COMPANION (Desktop) — servidor shelf + QR
// ═══════════════════════════════════════════════════════════════════════════════

class _WebCompanionScannerScreen extends StatefulWidget {
  const _WebCompanionScannerScreen();

  @override
  State<_WebCompanionScannerScreen> createState() =>
      _WebCompanionScannerScreenState();
}

class _WebCompanionScannerScreenState
    extends State<_WebCompanionScannerScreen> {
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
        title: const Text('Escanear Código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: url == null ? _buildNoServer() : _buildScannerInfo(url),
        ),
      ),
    );
  }

  Widget _buildNoServer() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white54, size: 72),
          SizedBox(height: 20),
          Text(
            'Servidor no disponible.\nVerifica la conexión WiFi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
        ],
      );

  Widget _buildScannerInfo(String url) => Column(
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
                    strokeWidth: 2, color: Colors.green),
              ),
              SizedBox(width: 12),
              Text('Esperando escaneo...',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Overlay painter — ventana con esquinas verdes
// ═══════════════════════════════════════════════════════════════════════════════

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 280.0;
    const h = 160.0;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2 - 30;
    final rect = Rect.fromLTWH(left, top, w, h);

    // Sombra
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shadow);

    // Borde
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Esquinas
    const cl = 24.0;
    final cp = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // TL
    canvas.drawLine(Offset(left, top + cl), Offset(left, top), cp);
    canvas.drawLine(Offset(left, top), Offset(left + cl, top), cp);
    // TR
    canvas.drawLine(Offset(left + w - cl, top), Offset(left + w, top), cp);
    canvas.drawLine(Offset(left + w, top), Offset(left + w, top + cl), cp);
    // BL
    canvas.drawLine(Offset(left, top + h - cl), Offset(left, top + h), cp);
    canvas.drawLine(Offset(left, top + h), Offset(left + cl, top + h), cp);
    // BR
    canvas.drawLine(
        Offset(left + w - cl, top + h), Offset(left + w, top + h), cp);
    canvas.drawLine(
        Offset(left + w, top + h), Offset(left + w, top + h - cl), cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
