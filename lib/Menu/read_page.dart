import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; // Para extracción de texto

class ReadPage extends StatefulWidget {
  final String filePath;

  const ReadPage({Key? key, required this.filePath}) : super(key: key);

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  String selectedText = '';
  List<String> words = [];
  int currentWordIndex = 0;
  bool isReading = false;
  Timer? _timer;
  double wordsPerMinute = 200; // Velocidad predeterminada
  bool _fileExists = false;

  int _currentPageNumber = 1; // Guarda el número de página actual

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final file = File(widget.filePath);
    final exists = await file.exists();
    if (mounted) {
      setState(() {
        _fileExists = exists;
      });
    }
  }

  /// Extrae el texto de la página actual usando la librería Syncfusion PDF.
  Future<void> _extractCurrentPageText() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Se resta 1 porque _currentPageNumber es 1-indexado
      final int pageIndex = _currentPageNumber - 1;
      final String pageText =
          PdfTextExtractor(document).extractText(startPageIndex: pageIndex);
      document.dispose();

      setState(() {
        selectedText = pageText;
        if (isReading) {
          stopReading();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error extrayendo texto: $e")),
      );
    }
  }

  /// Inicia la lectura mostrando palabra por palabra.
  void startReading() {
    if (selectedText.isEmpty) return;

    // Separa el texto en palabras (ignorando espacios múltiples)
    words = selectedText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return;

    currentWordIndex = 0;
    setState(() {
      isReading = true;
    });

    // Calcula el intervalo para cada palabra (60,000 ms / wpm)
    final interval = Duration(milliseconds: (60000 / wordsPerMinute).round());
    _timer = Timer.periodic(interval, (timer) {
      if (currentWordIndex < words.length) {
        setState(() {
          currentWordIndex++;
        });
      } else {
        timer.cancel();
        setState(() {
          isReading = false;
        });
      }
    });
  }

  /// Detiene la lectura.
  void stopReading() {
    _timer?.cancel();
    setState(() {
      isReading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "PDF Viewer",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: "Seleccionar todo el texto de la página actual",
            onPressed: _extractCurrentPageText,
          ),
        ],
      ),
      floatingActionButton: selectedText.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                if (isReading) {
                  stopReading();
                } else {
                  startReading();
                }
              },
              child: Icon(isReading ? Icons.stop : Icons.play_arrow),
              backgroundColor: Colors.deepPurple,
            )
          : null,
      body: !_fileExists
          ? const Center(
              child: Text("Archivo no encontrado o no se puede acceder"),
            )
          : Stack(
              children: [
                _buildPdfViewer(),
                _buildControlPanel(),
              ],
            ),
    );
  }

  Widget _buildPdfViewer() {
    try {
      return SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        scrollDirection: PdfScrollDirection.vertical,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            _currentPageNumber = details.newPageNumber;
          });
        },
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          if (details.selectedText != null) {
            setState(() {
              selectedText = details.selectedText!;
              if (isReading) {
                stopReading();
              }
            });
          }
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al cargar el PDF: ${details.error}")),
          );
        },
      );
    } catch (e) {
      return Center(
        child: Text("Error cargando el PDF: $e"),
      );
    }
  }

  Widget _buildControlPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Muestra la palabra actual durante la lectura
              if (isReading &&
                  words.isNotEmpty &&
                  currentWordIndex > 0 &&
                  currentWordIndex <= words.length)
                Text(
                  words[currentWordIndex - 1],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                )
              // Si no se está leyendo, muestra una vista previa del texto seleccionado
              else if (selectedText.isNotEmpty)
                Text(
                  "Texto seleccionado: ${selectedText.length > 100 ? '${selectedText.substring(0, 97)}...' : selectedText}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const Text(
                  "Selecciona texto del PDF o usa el botón 'Select All' para comenzar a leer",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              const SizedBox(height: 12),
              // Slider para ajustar la velocidad (palabras por minuto)
              Row(
                children: [
                  Text(
                    "Velocidad: ${wordsPerMinute.toInt()} wpm",
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: wordsPerMinute,
                      min: 50,
                      max: 500,
                      divisions: 9,
                      label: "${wordsPerMinute.toInt()}",
                      onChanged: isReading
                          ? null
                          : (value) {
                              setState(() {
                                wordsPerMinute = value;
                              });
                            },
                    ),
                  ),
                ],
              ),
              if (isReading)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Progreso: ${currentWordIndex}/${words.length} palabras",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
