import 'package:flutter/material.dart';
import 'dart:io';
import 'package:epubx/epubx.dart';

class ReadPage extends StatefulWidget {
  final String filePath;

  const ReadPage({super.key, required this.filePath});

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  String bookContent = "Cargando...";

  @override
  void initState() {
    super.initState();
    _readEpub();
  }

  Future<void> _readEpub() async {
    try {
      File file = File(widget.filePath);
      if (!(await file.exists())) {
        setState(() {
          bookContent = "❌ Error: El archivo no existe.";
        });
        return;
      }

      List<int> bytes = await file.readAsBytes();
      EpubBook epubBook = await EpubReader.readBook(bytes);

      // Obtener el contenido del primer capítulo
      String content = epubBook.Chapters?.isNotEmpty ?? false
          ? epubBook.Chapters![0].HtmlContent ?? "No hay contenido disponible."
          : "No hay capítulos disponibles.";

      setState(() {
        bookContent = content.replaceAll(
            RegExp(r'<[^>]*>'), ''); // Elimina etiquetas HTML
      });
    } catch (e) {
      setState(() {
        bookContent = "❌ Error al cargar el EPUB: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Read Book"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(bookContent, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
