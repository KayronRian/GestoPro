import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/theme.dart';

// Página stateful para leitura de código de barras e retorno do valor via Navigator.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

// State que mantém controladores, flags e a lógica de detecção do scanner.
class _ScannerPageState extends State<ScannerPage> {
  // Controlador do MobileScanner: gerencia câmera, lanterna e start/stop da captura.
  final MobileScannerController _ctrl = MobileScannerController();
  // Flag para garantir processamento único do primeiro código válido detectado.
  bool _scanned = false;
  final _manualCtrl = TextEditingController();

  // Libera controladores (câmera e texto) ao destruir a página, evitando leaks.
  @override
  void dispose() {
    _ctrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  // Callback do scanner: recebe o lote de barcodes e decide qual processar.
  void _onDetect(BarcodeCapture capture) {
    // Se já processou um código, sai cedo para evitar leituras duplicadas.
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _scanned = true;
      // Após marcar _scanned, para o scanner e fecha a página retornando o código.
      _ctrl.stop();
      Navigator.pop(context, code);
    }
  }

  // Constrói a UI: AppBar com ações, área da câmera e seção de entrada manual.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código de Barras'),
        actions: [
          // Alterna a lanterna no dispositivo via MobileScannerController.
          IconButton(
            onPressed: () => _ctrl.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: 'Lanterna',
          ),
          IconButton(
            onPressed: () => _ctrl.switchCamera(),
            icon: const Icon(Icons.flip_camera_ios_outlined),
            tooltip: 'Trocar câmera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Área da câmera
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Exibe a prévia da câmera e chama _onDetect quando encontrar barcodes.
                MobileScanner(
                  controller: _ctrl,
                  onDetect: _onDetect,
                ),
                // Overlay de mira
                Center(
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accentGreen,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Aponte para o código de barras',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Entrada manual
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ou digite o código manualmente:',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        // TextField para digitar o código; usa _manualCtrl e teclado numérico.
                        child: TextField(
                          controller: _manualCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Ex: 7891234567890',
                            prefixIcon: Icon(Icons.qr_code),
                          ),
                          // Ao enviar pelo teclado, valida não-vazio e retorna o valor digitado.
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) {
                              Navigator.pop(context, v.trim());
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        // Botão OK lê _manualCtrl, verifica preenchimento e fecha retornando o código.
                        onPressed: () {
                          final v = _manualCtrl.text.trim();
                          if (v.isNotEmpty) Navigator.pop(context, v);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
