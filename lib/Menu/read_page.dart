import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:epubx/epubx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  int wpm = 200; // Palabras por minuto
  int currentPage = 0;
  List<String> pages = [];
  String fileType = "";
  bool showTextMode = false;

  // Add new variables for page range selection
  int startPage = 0;
  int endPage = 0;
  int totalPages = 0;
  bool usePageRange = false;
  PdfDocument? pdfDocument;
  EpubBook? epubBook;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _readFile();
  }

  @override
  void dispose() {
    _timer?.cancel();
    pdfDocument?.dispose();
    super.dispose();
  }

  Future<void> _readFile() async {
    try {
      File file = File(widget.filePath);
      if (!(await file.exists())) {
        setState(() {
          bookContent = "❌ Error: El archivo no existe.";
        });
        return;
      }

      String extension = path.extension(widget.filePath).toLowerCase();
      fileType = extension;
      String content = "Formato no compatible.";

      if (extension == ".epub") {
        content = await _readEpub(file);
      } else if (extension == ".pdf") {
        content = await _readPdf(file);
      } else {
        content = "❌ Error: Formato de archivo no compatible.";
      }

      setState(() {
        bookContent = content;
        pages = content.split(RegExp(r'\n{2,}'));
        totalPages = pages.length;
        endPage = totalPages - 1;
        words = pages.isNotEmpty
            ? pages[currentPage]
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList()
            : [];
      });
    } catch (e) {
      setState(() {
        bookContent = "❌ Error al cargar el archivo: $e";
      });
    }
  }

  Future<String> _readEpub(File file) async {
    try {
      List<int> bytes = await file.readAsBytes();
      epubBook = await EpubReader.readBook(bytes);
      String content = "";

      if (epubBook?.Chapters?.isNotEmpty ?? false) {
        for (var chapter in epubBook!.Chapters!) {
          content += "${chapter.Title ?? "Capítulo"}\n";
          content +=
              chapter.HtmlContent?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "";
          content += "\n\n";
        }
      } else {
        content = "No hay capítulos disponibles.";
      }
      return content;
    } catch (e) {
      return "❌ Error al leer EPUB: $e";
    }
  }

  Future<String> _readPdf(File file) async {
    try {
      List<int> bytes = await file.readAsBytes();
      pdfDocument = PdfDocument(inputBytes: bytes);
      StringBuffer content = StringBuffer();

      totalPages = pdfDocument!.pages.count;
      endPage = totalPages - 1;

      for (int i = 0; i < pdfDocument!.pages.count; i++) {
        String? text =
            PdfTextExtractor(pdfDocument!).extractText(startPageIndex: i);
        if (text != null && text.isNotEmpty) {
          content.writeln(text);
        }
      }

      return content.isNotEmpty
          ? content.toString()
          : "No se pudo extraer texto del PDF.";
    } catch (e) {
      return "❌ Error al leer PDF: $e";
    }
  }

  void _startReading() {
    if (words.isEmpty) return;
    _stopReading();
    setState(() => isPlaying = true);

    _timer =
        Timer.periodic(Duration(milliseconds: (60000 / wpm).round()), (timer) {
      if (currentIndex < words.length - 1) {
        setState(() => currentIndex++);
      } else {
        // Move to next page if we're at the end of words
        if (currentPage < endPage) {
          setState(() {
            currentPage++;
            currentIndex = 0;
            _loadCurrentPageWords();
          });
        } else {
          _stopReading();
        }
      }
    });
  }

  void _loadCurrentPageWords() {
    if (pages.isNotEmpty && currentPage < pages.length) {
      words = pages[currentPage]
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
    } else {
      words = [];
    }
  }

  void _stopReading() {
    _timer?.cancel();
    setState(() => isPlaying = false);
  }

  Widget _buildPdfViewer() {
    return Stack(
      children: [
        SfPdfViewer.file(
          File(widget.filePath),
          controller: _pdfViewerController,
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Página ${_pdfViewerController.pageNumber} de $totalPages",
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _showPageRangeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int tempStartPage = startPage;
        int tempEndPage = endPage;

        return AlertDialog(
          title: const Text("Seleccionar rango de páginas"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text("Desde: "),
                  Expanded(
                    child: Slider(
                      value: tempStartPage.toDouble(),
                      min: 0,
                      max: (totalPages - 1).toDouble(),
                      divisions: totalPages > 1 ? totalPages - 1 : 1,
                      label: (tempStartPage + 1).toString(),
                      onChanged: (value) {
                        tempStartPage = value.toInt();
                        // Ensure endPage is always >= startPage
                        if (tempEndPage < tempStartPage) {
                          tempEndPage = tempStartPage;
                        }
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                  Text((tempStartPage + 1).toString()),
                ],
              ),
              Row(
                children: [
                  const Text("Hasta: "),
                  Expanded(
                    child: Slider(
                      value: tempEndPage.toDouble(),
                      min: tempStartPage.toDouble(),
                      max: (totalPages - 1).toDouble(),
                      divisions: totalPages - tempStartPage > 1
                          ? totalPages - tempStartPage
                          : 1,
                      label: (tempEndPage + 1).toString(),
                      onChanged: (value) {
                        tempEndPage = value.toInt();
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                  Text((tempEndPage + 1).toString()),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  startPage = tempStartPage;
                  endPage = tempEndPage;
                  currentPage = startPage;
                  usePageRange = true;
                  _loadCurrentPageWords();
                });
                Navigator.pop(context);
              },
              child: const Text("Aplicar"),
            ),
          ],
        );
      },
    );
  }

  void _showWpmSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int tempWpm = wpm;

        return AlertDialog(
          title: const Text("Configurar velocidad de lectura"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$tempWpm palabras por minuto",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("100"),
                  Expanded(
                    child: Slider(
                      value: tempWpm.toDouble(),
                      min: 100,
                      max: 800,
                      divisions: 14,
                      onChanged: (value) {
                        tempWpm = value.toInt();
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                  const Text("800"),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _wpmPresetButton(
                      150, tempWpm, (val) => tempWpm = val, context),
                  _wpmPresetButton(
                      200, tempWpm, (val) => tempWpm = val, context),
                  _wpmPresetButton(
                      300, tempWpm, (val) => tempWpm = val, context),
                  _wpmPresetButton(
                      400, tempWpm, (val) => tempWpm = val, context),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  wpm = tempWpm;
                  // If already reading, restart with new speed
                  if (isPlaying) {
                    _stopReading();
                    _startReading();
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("Aplicar"),
            ),
          ],
        );
      },
    );
  }

  Widget _wpmPresetButton(int presetWpm, int currentWpm,
      Function(int) onSelected, BuildContext dialogContext) {
    bool isSelected = presetWpm == currentWpm;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      onPressed: () {
        onSelected(presetWpm);
        (dialogContext as Element).markNeedsBuild();
      },
      child: Text("$presetWpm"),
    );
  }

  Widget _buildWordByWordReader() {
    if (words.isEmpty)
      return const Center(child: Text("No hay contenido disponible"));

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  currentIndex < words.length ? words[currentIndex] : "",
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 40),
            LinearProgressIndicator(
              value: words.isEmpty ? 0 : currentIndex / words.length,
              backgroundColor: Colors.grey.shade300,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Palabra ${currentIndex + 1} de ${words.length} | Página ${currentPage + 1} de ${endPage + 1}",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Read Book"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: "Configurar velocidad",
            onPressed: _showWpmSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Seleccionar rango de páginas",
            onPressed: _showPageRangeDialog,
          ),
          if (fileType == ".pdf")
            IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: "Cambiar modo de visualización",
              onPressed: () {
                setState(() {
                  showTextMode = !showTextMode;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.text_format),
            tooltip: "Modo palabra por palabra",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Lectura palabra por palabra"),
                  content: Container(
                    width: double.maxFinite,
                    height: 400,
                    child: _buildWordByWordReader(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isPlaying ? _stopReading : _startReading,
                      child: Text(isPlaying ? "⏸ Pausar" : "▶ Iniciar"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cerrar"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: fileType == ".pdf" && !showTextMode
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
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    children: [
                      if (usePageRange)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Rango seleccionado: ${startPage + 1} - ${endPage + 1} de $totalPages",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              currentPage = currentPage > startPage
                                  ? currentPage - 1
                                  : startPage;
                              _loadCurrentPageWords();
                            }),
                            icon: const Icon(Icons.arrow_back),
                            tooltip: "Página anterior",
                          ),
                          Text(
                            "Página ${currentPage + 1} de ${totalPages}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              currentPage = currentPage < endPage
                                  ? currentPage + 1
                                  : endPage;
                              _loadCurrentPageWords();
                            }),
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
                        ),
                        onPressed: isPlaying ? _stopReading : _startReading,
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
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
