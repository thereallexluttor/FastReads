import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'read_page.dart';

class MenuUi extends StatefulWidget {
  const MenuUi({super.key});

  @override
  _MenuUiState createState() => _MenuUiState();
}

class _MenuUiState extends State<MenuUi> {
  List<String> uploadedBooks = [];
  List<String> filePaths = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? books = prefs.getStringList('uploaded_books');
    List<String>? paths = prefs.getStringList('book_paths');

    if (books != null && paths != null) {
      setState(() {
        uploadedBooks = books;
        filePaths = paths;
      });
    }
  }

  Future<void> _saveBooks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('uploaded_books', uploadedBooks);
    await prefs.setStringList('book_paths', filePaths);
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        String fileName = result.files.single.name;
        String filePath = result.files.single.path ?? "";

        if (filePath.isNotEmpty) {
          setState(() {
            uploadedBooks.add(fileName);
            filePaths.add(filePath);
          });
          _saveBooks();
        }
      } else {
        print("No file selected.");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  void _openBook(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadPage(filePath: filePaths[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Books',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 10),
            Expanded(
              child: uploadedBooks.isEmpty
                  ? Center(
                      child: Text(
                        'No books uploaded',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: uploadedBooks.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            "📖 ${uploadedBooks[index]}",
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          onTap: () =>
                              _openBook(index), // Abre la lectura del libro
                        );
                      },
                    ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Upload Book',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
