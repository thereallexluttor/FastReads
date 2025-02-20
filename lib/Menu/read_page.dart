import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ReadPage extends StatefulWidget {
  final String filePath;

  const ReadPage({super.key, required this.filePath});

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "PDF Viewer",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        scrollDirection: PdfScrollDirection.vertical,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}
