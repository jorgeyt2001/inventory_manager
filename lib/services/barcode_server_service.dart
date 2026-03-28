import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';

class BarcodeServerService {
  static final BarcodeServerService instance = BarcodeServerService._();
  BarcodeServerService._();

  final StreamController<String> _barcodeController =
      StreamController<String>.broadcast();
  Stream<String> get barcodeStream => _barcodeController.stream;

  HttpServer? _server;
  String? _localIp;
  final int port = 8181;

  String? get localIp => _localIp;
  String? get serverUrl => _localIp != null ? 'http://$_localIp:$port' : null;
  bool get isRunning => _server != null;

  Future<void> start() async {
    _localIp = await _resolveLocalIp();

    final router = Router();
    router.get('/', _handleRoot);
    router.post('/barcode', _handleBarcode);
    router.options('/barcode', _handleOptions);

    try {
      _server = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        port,
      );
      // ignore: avoid_print
      print('[BarcodeServer] Listening on http://$_localIp:$port');
    } catch (e) {
      // ignore: avoid_print
      print('[BarcodeServer] Failed to start: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  Future<String?> _resolveLocalIp() async {
    // Try network_info_plus (works on WiFi-connected devices)
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}

    // Fallback: iterate network interfaces
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }
      // Any non-loopback
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}

    return '127.0.0.1';
  }

  Response _handleRoot(Request req) => Response.ok(
        _scannerHtml,
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  Response _handleOptions(Request req) => Response.ok(
        '',
        headers: _corsHeaders,
      );

  Future<Response> _handleBarcode(Request req) async {
    final body = await req.readAsString();
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final barcode = data['barcode'] as String?;
      if (barcode != null && barcode.trim().isNotEmpty) {
        _barcodeController.add(barcode.trim());
      }
    } catch (_) {}
    return Response.ok(
      '{"status":"ok"}',
      headers: {'Content-Type': 'application/json', ..._corsHeaders},
    );
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  // ─── Scanner HTML page ───────────────────────────────────────────────────────
  static const String _scannerHtml = '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Scanner de Codigos</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #111;
      color: #fff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 16px;
      gap: 16px;
    }
    h1 { font-size: 1.25rem; font-weight: 600; text-align: center; }
    #camera-section { width: 100%; max-width: 420px; }
    #camera-wrap {
      position: relative;
      width: 100%;
      background: #000;
      border-radius: 14px;
      overflow: hidden;
      aspect-ratio: 4/3;
    }
    video { width: 100%; height: 100%; object-fit: cover; display: block; }
    canvas { display: none; }
    #scan-line {
      position: absolute;
      left: 12%; right: 12%;
      height: 2px;
      background: linear-gradient(90deg, transparent, #00ff88, transparent);
      animation: sweep 1.8s ease-in-out infinite;
      border-radius: 2px;
    }
    @keyframes sweep { 0%,100% { top: 15%; } 50% { top: 80%; } }
    .corner {
      position: absolute;
      width: 22px; height: 22px;
      border-color: #00ff88; border-style: solid;
    }
    .tl { top: 8%; left: 8%; border-width: 3px 0 0 3px; }
    .tr { top: 8%; right: 8%; border-width: 3px 3px 0 0; }
    .bl { bottom: 8%; left: 8%; border-width: 0 0 3px 3px; }
    .br { bottom: 8%; right: 8%; border-width: 0 3px 3px 0; }
    #cam-status {
      margin-top: 10px;
      font-size: 0.85rem;
      color: #aaa;
      text-align: center;
      min-height: 1.2em;
    }
    #no-camera-msg {
      display: none;
      background: #2a2a2a;
      border: 1px solid #444;
      border-radius: 12px;
      padding: 16px;
      font-size: 0.85rem;
      color: #bbb;
      text-align: center;
      line-height: 1.5;
    }
    #no-camera-msg strong { color: #ff9f43; }
    #result-banner {
      display: none;
      width: 100%;
      max-width: 420px;
      padding: 14px 18px;
      background: #00aa55;
      border-radius: 10px;
      font-size: 1.05rem;
      font-weight: 600;
      text-align: center;
    }
    .divider {
      width: 100%;
      max-width: 420px;
      display: flex;
      align-items: center;
      gap: 10px;
      color: #555;
      font-size: 0.8rem;
    }
    .divider::before, .divider::after {
      content: "";
      flex: 1;
      height: 1px;
      background: #333;
    }
    .manual-box {
      width: 100%;
      max-width: 420px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .manual-box label { font-size: 0.85rem; color: #aaa; }
    .manual-row { display: flex; gap: 8px; }
    .manual-row input {
      flex: 1;
      padding: 12px 14px;
      border-radius: 10px;
      border: 1px solid #3a3a3a;
      background: #222;
      color: #fff;
      font-size: 1rem;
      outline: none;
      -webkit-appearance: none;
    }
    .manual-row input:focus { border-color: #0066ff; }
    .manual-row button {
      padding: 12px 18px;
      border-radius: 10px;
      border: none;
      background: #0066ff;
      color: #fff;
      font-size: 0.95rem;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      -webkit-appearance: none;
    }
    .manual-row button:active { background: #0052cc; transform: scale(0.97); }
  </style>
</head>
<body>
  <h1>Escanear Codigo</h1>

  <!-- Camera section -->
  <div id="camera-section">
    <div id="camera-wrap">
      <video id="video" autoplay playsinline muted></video>
      <canvas id="canvas"></canvas>
      <div id="scan-line"></div>
      <div class="corner tl"></div>
      <div class="corner tr"></div>
      <div class="corner bl"></div>
      <div class="corner br"></div>
    </div>
    <div id="cam-status">Iniciando camara...</div>
    <div id="no-camera-msg">
      <strong>Camara no disponible</strong><br>
      Safari requiere HTTPS para acceder a la camara en redes locales.<br><br>
      Usa el campo de texto de abajo para introducir el codigo manualmente,
      o conectate al servidor via HTTPS si esta configurado.
    </div>
  </div>

  <!-- Detected result -->
  <div id="result-banner"></div>

  <div class="divider">O introduce manualmente</div>

  <!-- Manual input -->
  <div class="manual-box">
    <label>Codigo de barras</label>
    <div class="manual-row">
      <input id="manual-input" type="text" placeholder="Escanea o escribe..." autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
      <button onclick="sendManual()">Enviar</button>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.js"></script>
  <script>
    const video = document.getElementById("video");
    const canvas = document.getElementById("canvas");
    const ctx = canvas.getContext("2d");
    const camStatus = document.getElementById("cam-status");
    const noCameraMsg = document.getElementById("no-camera-msg");
    const cameraWrap = document.getElementById("camera-wrap");
    const resultBanner = document.getElementById("result-banner");
    let scanning = true;
    let barcodeDetector = null;

    // ── Init BarcodeDetector ──────────────────────────────────────────────────
    async function initDetector() {
      if (typeof BarcodeDetector === "undefined") return;
      try {
        const formats = await BarcodeDetector.getSupportedFormats();
        barcodeDetector = new BarcodeDetector({ formats });
      } catch (_) {
        try {
          barcodeDetector = new BarcodeDetector({
            formats: ["ean_13","ean_8","code_128","code_39","qr_code","upc_a","upc_e","itf"]
          });
        } catch (_) {}
      }
    }

    // ── Camera start ─────────────────────────────────────────────────────────
    async function startCamera() {
      // getUserMedia requires a secure context (HTTPS or localhost)
      if (!window.isSecureContext) {
        cameraWrap.style.display = "none";
        camStatus.style.display = "none";
        noCameraMsg.style.display = "block";
        return;
      }
      try {
        await initDetector();
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } }
        });
        video.srcObject = stream;
        await video.play();
        camStatus.textContent = "Apunta al codigo de barras";
        tick();
      } catch (e) {
        cameraWrap.style.display = "none";
        camStatus.style.display = "none";
        noCameraMsg.style.display = "block";
      }
    }

    // ── Scan loop ────────────────────────────────────────────────────────────
    async function tick() {
      if (!scanning) { setTimeout(tick, 200); return; }
      if (video.readyState < video.HAVE_ENOUGH_DATA) { setTimeout(tick, 100); return; }

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx.drawImage(video, 0, 0);

      let found = null;

      // BarcodeDetector (EAN-13, Code-128, etc.)
      if (barcodeDetector) {
        try {
          const results = await barcodeDetector.detect(video);
          if (results.length > 0) found = results[0].rawValue;
        } catch (_) {}
      }

      // jsQR fallback (QR codes)
      if (!found) {
        try {
          const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const code = jsQR(img.data, img.width, img.height);
          if (code) found = code.data;
        } catch (_) {}
      }

      if (found) {
        sendBarcode(found);
      } else {
        setTimeout(tick, 150);
      }
    }

    // ── Send barcode ─────────────────────────────────────────────────────────
    function sendBarcode(barcode) {
      scanning = false;
      resultBanner.textContent = "✓ " + barcode;
      resultBanner.style.display = "block";
      camStatus.textContent = "Enviando a la app...";

      fetch("/barcode", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ barcode: barcode })
      }).then(() => {
        camStatus.textContent = "✓ Enviado. Listo para siguiente...";
        setTimeout(() => {
          resultBanner.style.display = "none";
          camStatus.textContent = "Apunta al codigo de barras";
          scanning = true;
          tick();
        }, 2500);
      }).catch(() => {
        scanning = true;
        tick();
      });
    }

    function sendManual() {
      const val = document.getElementById("manual-input").value.trim();
      if (val) {
        sendBarcode(val);
        document.getElementById("manual-input").value = "";
      }
    }

    document.getElementById("manual-input").addEventListener("keydown", function(e) {
      if (e.key === "Enter") sendManual();
    });

    startCamera();
  </script>
</body>
</html>''';
}
