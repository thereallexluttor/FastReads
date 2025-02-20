import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_math_fork/flutter_math.dart';

class ReadPage extends StatefulWidget {
  final String filePath;

  const ReadPage({super.key, required this.filePath});

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  String bookContent = "📖 Cargando libro...";
  List<String> words = [];
  int currentIndex = 0;
  Timer? _timer;
  bool isPlaying = false;
  int wpm = 200; // Words per minute
  int currentPage = 0;
  List<String> pages = [];
  String fileType = "";
  double _zoomLevel = 1.0;
  bool isLoading = true; // Loading flag

  // Variables for page range (PDF mode)
  int startPage = 0;
  int endPage = 0;
  int totalPages = 0;
  bool usePageRange = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  // ValueNotifier to update the word-by-word dialog
  final ValueNotifier<int> updateNotifier = ValueNotifier<int>(0);

  // Selected text for word-by-word reading
  String? selectedText;

  @override
  void initState() {
    super.initState();
    _readFile();
  }

  @override
  void dispose() {
    _timer?.cancel();
    updateNotifier.dispose();
    super.dispose();
  }

  Future<void> _readFile() async {
    try {
      File file = File(widget.filePath);
      if (!(await file.exists())) {
        setState(() {
          bookContent = "❌ Error: El archivo no existe.";
          isLoading = false;
        });
        return;
      }

      String extension = path.extension(widget.filePath).toLowerCase();
      fileType = extension;
      String content = "Formato no compatible.";

      if (extension == ".pdf") {
        content = await _readPdf(file);
      } else {
        content = "❌ Error: Formato de archivo no compatible.";
      }

      setState(() {
        bookContent = content;
        pages = content.split(RegExp(r'\n{2,}'));
        totalPages = pages.length;
        endPage = totalPages - 1;
        // Initialize words with the content of the first page
        words = pages.isNotEmpty
            ? pages[currentPage]
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList()
            : [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        bookContent = "❌ Error al cargar el archivo: $e";
        isLoading = false;
      });
    }
  }

  Future<String> _readPdf(File file) async {
    try {
      List<int> bytes = await file.readAsBytes();
      PdfDocument pdfDocument = PdfDocument(inputBytes: bytes);
      StringBuffer content = StringBuffer();

      totalPages = pdfDocument.pages.count;
      endPage = totalPages - 1;

      for (int i = 0; i < pdfDocument.pages.count; i++) {
        // Extract text from each page
        String? text = PdfTextExtractor(pdfDocument).extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        if (text != null && text.isNotEmpty) {
          content.writeln(text.trim());
          content.writeln("\n"); // Add spacing between pages
        }
      }
      pdfDocument.dispose(); // Dispose to free resources

      return content.isNotEmpty
          ? content.toString()
          : "No se pudo extraer texto del PDF.";
    } catch (e) {
      return "❌ Error al leer PDF: $e";
    }
  }

  void _updateTextPage() {
    _stopReading();
    setState(() {
      words = pages[currentPage]
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      currentIndex = 0;
    });
  }

  void _goToPreviousPage() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
      });
      _updateTextPage();
    }
  }

  void _goToNextPage() {
    if (currentPage < totalPages - 1) {
      setState(() {
        currentPage++;
      });
      _updateTextPage();
    }
  }

  void _startReadingFromSelectedText(String text) {
    setState(() {
      selectedText = text;
      words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      currentIndex = 0;
    });
    _startReading();
  }

  void _startReadingForRange() {
    if (usePageRange &&
        startPage >= 0 &&
        endPage < totalPages &&
        startPage <= endPage) {
      setState(() {
        words = List<String>.from(pages
            .sublist(startPage - 2, endPage)
            .expand((page) => page.split(RegExp(r'\s+')))
            .where((w) => w.isNotEmpty));
        currentIndex = 0;
      });

      // Jump to the start page in the PDF viewer
      _pdfViewerController.jumpToPage(startPage + 1);

      // Start reading
      _startReading();
    } else {
      setState(() {
        bookContent = "❌ Error: Rango de páginas inválido.";
      });
    }
  }

  void _startReading() {
    if (words.isEmpty) return;
    _stopReading(); // Cancel any existing timer
    setState(() => isPlaying = true);

    _timer = Timer.periodic(
      Duration(milliseconds: (60000 / wpm).round()),
      (timer) {
        if (currentIndex < words.length - 1) {
          setState(() {
            currentIndex++;
          });
          updateNotifier.value++; // Trigger update
        } else {
          _stopReading();
        }
      },
    );
  }

  void _stopReading() {
    _timer?.cancel();
    setState(() => isPlaying = false);
    updateNotifier.value++; // Notify listeners that reading has stopped
  }

  void _showPageRangeDialog() {
    int tempStartPage = startPage + 1; // For display (1-based)
    int tempEndPage = endPage + 1;
    // Local controllers to show the current values
    TextEditingController startController =
        TextEditingController(text: tempStartPage.toString());
    TextEditingController endController =
        TextEditingController(text: tempEndPage.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Seleccionar rango de páginas"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Usar rango de páginas"),
                    value: usePageRange,
                    onChanged: (value) {
                      setDialogState(() {
                        usePageRange = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          enabled: usePageRange,
                          decoration: InputDecoration(
                            labelText: "Página inicial",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          controller: startController,
                          onChanged: (value) {
                            tempStartPage = int.tryParse(value) ?? 1;
                            if (tempStartPage < 1) tempStartPage = 1;
                            if (tempStartPage > totalPages) {
                              tempStartPage = totalPages;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          enabled: usePageRange,
                          decoration: InputDecoration(
                            labelText: "Página final",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          controller: endController,
                          onChanged: (value) {
                            tempEndPage = int.tryParse(value) ?? totalPages;
                            if (tempEndPage < tempStartPage) {
                              tempEndPage = tempStartPage;
                            }
                            if (tempEndPage > totalPages) {
                              tempEndPage = totalPages;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Total páginas: $totalPages",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () {
              setState(() {
                startPage = tempStartPage - 1; // Convert back to 0-based
                endPage = tempEndPage - 1;
              });
              if (usePageRange && fileType == ".pdf") {
                _pdfViewerController.jumpToPage(startPage);
                _startReadingForRange(); // Start word-by-word reading automatically
              }
              Navigator.pop(context);
            },
            child: const Text("Aplicar"),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Stack(
      children: [
        SfPdfViewer.file(
          File(widget.filePath),
          controller: _pdfViewerController,
          onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
            if (details.selectedText != null) {
              setState(() {
                selectedText = details.selectedText;
              });
            }
          },
          pageLayoutMode: PdfPageLayoutMode.continuous,
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() {
              currentPage = details.newPageNumber - 1;
            });
          },
          scrollDirection: PdfScrollDirection.vertical,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
        ),
        Positioned(
          top: 16,
          right: 16,
          child: _buildZoomControls(),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: _buildPageNavigator(),
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomButton(Icons.zoom_in, () {
            _pdfViewerController.zoomLevel =
                (_pdfViewerController.zoomLevel + 0.25).clamp(0.5, 3.0);
            setState(() {
              _zoomLevel = _pdfViewerController.zoomLevel;
            });
          }),
          const SizedBox(height: 8),
          Text(
            '${(_zoomLevel * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildZoomButton(Icons.zoom_out, () {
            _pdfViewerController.zoomLevel =
                (_pdfViewerController.zoomLevel - 0.25).clamp(0.5, 3.0);
            setState(() {
              _zoomLevel = _pdfViewerController.zoomLevel;
            });
          }),
          const SizedBox(height: 8),
          _buildZoomButton(Icons.fit_screen, () {
            _pdfViewerController.zoomLevel = 1.0;
            setState(() {
              _zoomLevel = 1.0;
            });
          }),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.deepPurple,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavigator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Página ${_pdfViewerController.pageNumber} de $totalPages",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (usePageRange)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Rango: ${startPage + 1}-${endPage + 1}",
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalPages > 0
                ? (_pdfViewerController.pageNumber - 1) / (totalPages - 1)
                : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Colors.deepPurple),
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavigationButton(
                Icons.skip_previous,
                "Primera página",
                () => _pdfViewerController
                    .jumpToPage(usePageRange ? startPage + 1 : 1),
              ),
              _buildNavigationButton(
                Icons.arrow_back,
                "Página anterior",
                () {
                  if (_pdfViewerController.pageNumber > 1) {
                    _pdfViewerController.previousPage();
                  }
                },
              ),
              _buildNavigationButton(
                Icons.filter_list,
                "Rango",
                _showPageRangeDialog,
              ),
              _buildNavigationButton(
                Icons.arrow_forward,
                "Página siguiente",
                () {
                  if (_pdfViewerController.pageNumber < totalPages) {
                    _pdfViewerController.nextPage();
                  }
                },
              ),
              _buildNavigationButton(
                Icons.skip_next,
                "Última página",
                () => _pdfViewerController
                    .jumpToPage(usePageRange ? endPage + 1 : totalPages),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Colors.deepPurple,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMathRenderer(String mathExpression) {
    return Center(
      child: Math.tex(
        mathExpression,
        textStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Improved heuristic for math expressions
  bool _isMathExpression(String word) {
    return word.startsWith('\\') || word.contains('^') || word.contains('_');
  }

  Widget _buildWordByWordReader() {
    if (words.isEmpty) {
      return const Center(child: Text("No hay contenido disponible"));
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: currentIndex < words.length
                    ? _isMathExpression(words[currentIndex])
                        ? _buildMathRenderer(words[currentIndex])
                        : Text(
                            words[currentIndex],
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          )
                    : const Text("Fin de la lectura"),
              ),
            ),
            const SizedBox(height: 40),
            LinearProgressIndicator(
              value: words.isEmpty ? 0 : currentIndex / words.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation(Colors.deepPurple),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Palabra ${currentIndex + 1} de ${words.length}",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWordByWordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        title: Row(
          children: [
            const Icon(Icons.fast_forward, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Text("Lectura palabra por palabra"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ValueListenableBuilder(
            valueListenable: updateNotifier,
            builder: (context, value, child) {
              return _buildWordByWordReader();
            },
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWPMControl(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.text_format),
                label: const Text("Usar selección"),
                onPressed: () {
                  if (selectedText != null) {
                    _startReadingFromSelectedText(selectedText!);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(isPlaying ? "Pausar" : "Iniciar"),
                onPressed: () {
                  if (usePageRange) {
                    _startReadingForRange();
                  } else {
                    _startReading();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.close),
                label: const Text("Cerrar"),
                onPressed: () {
                  _stopReading();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWPMControl() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              setState(() {
                wpm = (wpm - 25).clamp(50, 800);
              });
              if (isPlaying) {
                _stopReading();
                _startReading();
              }
            },
            tooltip: "Reducir velocidad",
            color: Colors.deepPurple,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              "$wpm WPM",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                wpm = (wpm + 25).clamp(50, 800);
              });
              if (isPlaying) {
                _stopReading();
                _startReading();
              }
            },
            tooltip: "Aumentar velocidad",
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          path.basename(widget.filePath),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Seleccionar rango de páginas",
            onPressed: _showPageRangeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.text_format),
            tooltip: "Modo palabra por palabra",
            onPressed: _showWordByWordDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: "Más opciones",
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: const Text("Añadir marcador"),
                        onTap: () {
                          Navigator.pop(context);
                          // Implement bookmark functionality
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.text_fields),
                        title: const Text("Ajustes de texto"),
                        onTap: () {
                          Navigator.pop(context);
                          // Implement text settings
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text("Información del documento"),
                        onTap: () {
                          Navigator.pop(context);
                          // Show document info
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : fileType == ".pdf"
              ? _buildPdfViewer()
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: Text(
                            pages.isNotEmpty && currentPage < pages.length
                                ? pages[currentPage]
                                : "📖 Cargando...",
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _goToPreviousPage,
                                icon: const Icon(Icons.arrow_back),
                                tooltip: "Página anterior",
                              ),
                              Text(
                                "Página ${currentPage + 1} de $totalPages",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                onPressed: _goToNextPage,
                                icon: const Icon(Icons.arrow_forward),
                                tooltip: "Página siguiente",
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(200, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: isPlaying ? _stopReading : _startReading,
                            icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(isPlaying
                                ? "Pausar lectura"
                                : "Iniciar lectura ($wpm WPM)"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
