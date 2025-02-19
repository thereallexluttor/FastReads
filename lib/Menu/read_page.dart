import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:epubx/epubx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;

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

  @override
  void initState() {
    super.initState();
    _readFile();
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
      String content = "Formato no compatible.";

      if (extension == ".epub") {
        content = await _readEpub(file);
      } else if (extension == ".pdf") {
        content = await _readPdf(file);
      }

      setState(() {
        bookContent = content;
        words = content.split(RegExp(r'\s+')); // Divide en palabras
      });
    } catch (e) {
      setState(() {
        bookContent = "❌ Error al cargar el archivo: $e";
      });
    }
  }

  Future<String> _readEpub(File file) async {
    List<int> bytes = await file.readAsBytes();
    EpubBook epubBook = await EpubReader.readBook(bytes);

    String title = epubBook.Title ?? "Título desconocido";
    String author = epubBook.Author?.isNotEmpty == true
        ? epubBook.Author!
        : "Autor desconocido";
    String content = "";

    if (epubBook.Chapters?.isNotEmpty ?? false) {
      for (var chapter in epubBook.Chapters!) {
        content += "${chapter.Title ?? "Capítulo"}\n";
        content +=
            chapter.HtmlContent?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "";
        content += "\n\n";
      }
    } else {
      content = "No hay capítulos disponibles.";
    }

    return "📚 $title\n👤 $author\n\n$content";
  }

  Future<String> _readPdf(File file) async {
    List<int> bytes = await file.readAsBytes();
    PdfDocument pdf = PdfDocument(inputBytes: bytes);

    String content = "";
    for (int i = 0; i < pdf.pages.count; i++) {
      content += PdfTextExtractor(pdf).extractText(startPageIndex: i) ?? "";
      content += "\n\n";
    }

    pdf.dispose();
    return content.isNotEmpty ? content : "No se pudo extraer texto del PDF.";
  }

  void _startReading() {
    if (words.isEmpty) return;
    _stopReading(); // Detiene cualquier ejecución previa
    setState(() => isPlaying = true);

    _timer =
        Timer.periodic(Duration(milliseconds: (60000 / wpm).round()), (timer) {
      if (currentIndex < words.length - 1) {
        setState(() => currentIndex++);
      } else {
        _stopReading();
      }
    });
  }

  void _stopReading() {
    _timer?.cancel();
    setState(() => isPlaying = false);
  }

  void _changeSpeed(int newWpm) {
    setState(() {
      wpm = newWpm;
      if (isPlaying) {
        _startReading(); // Reinicia con la nueva velocidad
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Read Book"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                words.isNotEmpty ? words[currentIndex] : "📖 Cargando...",
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: isPlaying ? _stopReading : _startReading,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlaying ? Colors.red : Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(isPlaying ? "⏸ Pausar" : "▶ Iniciar"),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: wpm,
                      items: [100, 200, 300, 400, 500]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text("$e WPM")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _changeSpeed(value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
