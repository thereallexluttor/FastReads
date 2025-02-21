import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';

class ReadPage extends StatefulWidget {
  final String filePath;

  const ReadPage({Key? key, required this.filePath}) : super(key: key);

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage>
    with SingleTickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  /// En vez de 'late', usamos `AnimationController?` para evitar el error de inicialización tardía.
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  String selectedText = '';
  List<String> words = [];
  int currentWordIndex = 0;
  bool isReading = false;
  Timer? _timer;
  double wordsPerMinute = 250; // Velocidad predeterminada
  bool _fileExists = false;
  bool _showReader = false;
  int _currentPageNumber = 1;
  int _totalPages = 0;
  double _fontSize = 38;
  Color _readerBackgroundColor = const Color(0xFF2D3250);
  Color _readerTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    // Inicializamos el AnimationController en initState
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Creamos la animación de opacidad
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeIn),
    );

    // Por si acaso, establecemos el valor inicial de la animación en 0
    _animationController!.value = 0.0;

    // Verificamos si el archivo PDF existe
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

  Future<void> _extractCurrentPageText() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      _totalPages = document.pages.count;

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

      // Mostrar el panel de lectura
      _toggleReaderView(true);
    } catch (e) {
      _showErrorSnackBar("Error extrayendo texto: $e");
    }
  }

  void _toggleReaderView(bool show) {
    setState(() {
      _showReader = show;
    });

    // Antes de usar el controlador, verificamos que no sea nulo
    if (_animationController == null) return;

    if (_animationController!.isAnimating) {
      _animationController!.stop();
    }

    if (show) {
      _animationController!.forward();
    } else {
      _animationController!.reverse();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void startReading() {
    if (selectedText.isEmpty) return;

    words = selectedText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return;

    currentWordIndex = 0;
    setState(() {
      isReading = true;
    });

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

  void stopReading() {
    _timer?.cancel();
    setState(() {
      isReading = false;
    });
  }

  void _adjustFontSize(double change) {
    setState(() {
      _fontSize = (_fontSize + change).clamp(16.0, 72.0);
    });
  }

  String _formatTimeRemaining() {
    if (!isReading || words.isEmpty || currentWordIndex >= words.length) {
      return '00:00';
    }

    final wordsRemaining = words.length - currentWordIndex;
    final secondsRemaining = (wordsRemaining / wordsPerMinute * 60).round();

    final minutes = (secondsRemaining / 60).floor();
    final seconds = secondsRemaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _changeTheme(bool isDark) {
    setState(() {
      if (isDark) {
        _readerBackgroundColor = const Color(0xFF2D3250);
        _readerTextColor = Colors.white;
      } else {
        _readerBackgroundColor = const Color(0xFFF7F3E3);
        _readerTextColor = const Color(0xFF2B2B2B);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pdfViewerController.dispose();
    // Eliminamos el controlador de animación de forma segura
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "PDF Reader",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF6F61C0),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: "Extraer texto de la página actual",
            onPressed: _extractCurrentPageText,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Información del documento",
            onPressed: () {
              _showDocumentInfo();
            },
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      body: !_fileExists
          ? _buildErrorView()
          : Stack(
              children: [
                _buildPdfViewer(),
                if (_showReader) _buildReaderOverlay(),
              ],
            ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (!_showReader && selectedText.isNotEmpty) {
      return FloatingActionButton(
        onPressed: () => _toggleReaderView(true),
        child: const Icon(Icons.remove_red_eye),
        backgroundColor: const Color(0xFF6F61C0),
        tooltip: "Abrir vista de lectura",
      );
    } else if (_showReader) {
      return FloatingActionButton(
        onPressed: () {
          if (isReading) {
            stopReading();
          } else {
            startReading();
          }
        },
        child: Icon(isReading ? Icons.pause : Icons.play_arrow),
        backgroundColor: isReading ? Colors.orange : const Color(0xFF6F61C0),
        tooltip: isReading ? "Pausar lectura" : "Comenzar lectura",
      );
    }
    return Container();
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Información del PDF"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Archivo: ${widget.filePath.split('/').last}"),
            const SizedBox(height: 8),
            Text("Página actual: $_currentPageNumber de $_totalPages"),
            const SizedBox(height: 8),
            if (selectedText.isNotEmpty) ...[
              const Divider(),
              Text("Texto seleccionado: ${selectedText.length} caracteres"),
              Text("Palabras: ${words.isEmpty ? 0 : words.length}"),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            "Archivo no encontrado o no se puede acceder",
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Volver"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6F61C0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
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
          if (details.selectedText != null &&
              details.selectedText!.isNotEmpty) {
            setState(() {
              selectedText = details.selectedText!;
              if (isReading) {
                stopReading();
              }
            });
          }
        },
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          _showErrorSnackBar("Error al cargar el PDF: ${details.error}");
        },
      );
    } catch (e) {
      return Center(
        child: Text("Error cargando el PDF: $e"),
      );
    }
  }

  Widget _buildReaderOverlay() {
    final fadeAnim = _fadeAnimation;
    if (fadeAnim == null) {
      // Si aún no se inicializó la animación, devolvemos un contenedor vacío
      return Container();
    }

    return AnimatedBuilder(
      animation: fadeAnim,
      builder: (context, child) {
        final opacity = fadeAnim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Container(
            color: _readerBackgroundColor.withOpacity(0.95),
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  _buildReaderHeader(),
                  Expanded(
                    child: _buildWordDisplay(),
                  ),
                  _buildReaderControls(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReaderHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: _readerTextColor),
                onPressed: () {
                  stopReading();
                  _toggleReaderView(false);
                },
                tooltip: "Volver al PDF",
              ),
              Text(
                "Página $_currentPageNumber",
                style: TextStyle(
                  color: _readerTextColor.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.light_mode,
                  color: _readerBackgroundColor == const Color(0xFF2D3250)
                      ? _readerTextColor.withOpacity(0.4)
                      : _readerTextColor,
                ),
                onPressed: () => _changeTheme(false),
                tooltip: "Modo claro",
              ),
              IconButton(
                icon: Icon(
                  Icons.dark_mode,
                  color: _readerBackgroundColor == const Color(0xFF2D3250)
                      ? _readerTextColor
                      : _readerTextColor.withOpacity(0.4),
                ),
                onPressed: () => _changeTheme(true),
                tooltip: "Modo oscuro",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordDisplay() {
    if (!isReading ||
        words.isEmpty ||
        currentWordIndex <= 0 ||
        currentWordIndex > words.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories,
                size: 64,
                color: _readerTextColor.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                selectedText.isEmpty
                    ? "No hay texto seleccionado"
                    : "Presiona play para comenzar la lectura",
                style: TextStyle(
                  fontSize: 18,
                  color: _readerTextColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (selectedText.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  "${words.length} palabras · ${(words.length / wordsPerMinute).toStringAsFixed(1)} minutos",
                  style: TextStyle(
                    fontSize: 16,
                    color: _readerTextColor.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currentWord = words[currentWordIndex - 1];

    // Encuentra un punto de enfoque (ORP) aproximado
    int midpoint = (currentWord.length / 2).floor();
    int orp = currentWord.length <= 3 ? 1 : midpoint;

    String firstPart = currentWord.substring(0, orp);
    String middleLetter =
        orp < currentWord.length ? currentWord.substring(orp, orp + 1) : "";
    String lastPart =
        orp + 1 < currentWord.length ? currentWord.substring(orp + 1) : "";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: Text(
              currentWord,
              key: ValueKey(currentWordIndex),
              style: GoogleFonts.robotoSlab(
                fontSize: _fontSize,
                color: _readerTextColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Visualización del ORP (Optimal Recognition Point)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                firstPart,
                style: GoogleFonts.robotoSlab(
                  fontSize: _fontSize * 0.4,
                  color: _readerTextColor.withOpacity(0.7),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _readerTextColor,
                      width: 2.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  middleLetter,
                  style: GoogleFonts.robotoSlab(
                    fontSize: _fontSize * 0.4,
                    color: _readerTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                lastPart,
                style: GoogleFonts.robotoSlab(
                  fontSize: _fontSize * 0.4,
                  color: _readerTextColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Barra de progreso
          LinearProgressIndicator(
            value: words.isEmpty ? 0 : currentWordIndex / words.length,
            backgroundColor: _readerTextColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              _readerTextColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _readerBackgroundColor.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Control de tamaño de letra
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.text_decrease, color: _readerTextColor),
                  onPressed: () => _adjustFontSize(-4),
                  tooltip: "Disminuir tamaño de texto",
                ),
                Text(
                  "Aa",
                  style: TextStyle(
                    fontSize: 20,
                    color: _readerTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.text_increase, color: _readerTextColor),
                  onPressed: () => _adjustFontSize(4),
                  tooltip: "Aumentar tamaño de texto",
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Control de velocidad
            Row(
              children: [
                Text(
                  "${wordsPerMinute.toInt()} WPM",
                  style: TextStyle(
                    color: _readerTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: wordsPerMinute,
                    min: 100,
                    max: 700,
                    divisions: 12,
                    activeColor: const Color(0xFF6F61C0),
                    inactiveColor: _readerTextColor.withOpacity(0.2),
                    onChanged: isReading
                        ? null
                        : (value) {
                            setState(() {
                              wordsPerMinute = value;
                            });
                          },
                  ),
                ),
                if (isReading)
                  Text(
                    _formatTimeRemaining(),
                    style: TextStyle(
                      color: _readerTextColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),

            // Contador de progreso
            if (isReading && words.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "${currentWordIndex}/${words.length} palabras",
                  style: TextStyle(
                    color: _readerTextColor.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
