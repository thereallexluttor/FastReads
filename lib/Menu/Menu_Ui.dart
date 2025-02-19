import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

class MenuUi extends StatefulWidget {
  const MenuUi({super.key});

  @override
  _MenuUiState createState() => _MenuUiState();
}

class _MenuUiState extends State<MenuUi> {
  List<String> uploadedBooks = [];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          uploadedBooks.add(result.files.single.name);
        });
      } else {
        print("No file selected.");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
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
            const SizedBox(height: 20),
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
                          title: Text(uploadedBooks[index],
                              style: GoogleFonts.poppins(fontSize: 16)),
                          leading:
                              const Icon(Icons.book, color: Colors.deepPurple),
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
