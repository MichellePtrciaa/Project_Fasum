import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  String? _base64Image;
  File? _image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _latitude;
  double? _longitude;

  String? _aiCategory;
  String? _aiDescription;
  bool _isGenerating = false;
  final String _apiKey =
      'AQ.Ab8RN6KGASm-kz8cwTkwrTSzBPLaG7Ff1jZ3PS4LBFtIS5hcQA';

  List<String> categories = [
    'Jalan Rusak',
    'Marka Pudar',
    'Lampu Mati',
    'Trotoar Rusak',
    'Rambu Rusak',
    'Jembatan Rusak',
    'Sampah Menumpuk',
    'Saluran Tersumbat',
    'Sungai Tercemar',
    'Sampah Sungai',
    'Pohon Tumbang',
    'Taman Rusak',
    'Fasilitas Rusak',
    'Pipa Bocor',
    'Vandalisme',
    'Banjir',
    'Lainnya',
  ];

  void _showCategorySelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: categories.map((category) {
            return ListTile(
              title: Text(category),
              onTap: () {
                setState(() {
                  _aiCategory = category;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _generateDescriptionWithAI() async {
    if (_imageBytes == null) return;
    setState(() => _isGenerating = true);
    try {
      final base64Image = _base64Image ?? base64Encode(_imageBytes!);

      // final url =
      //     'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$_apiKey';

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent';

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
              },
              {
                "text":
                    "Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum "
                    "dari daftar berikut: Jalan Rusak, Marka Pudar, Lampu Mati, Trotoar Rusak, "
                    "Rambu Rusak, Jembatan Rusak, Sampah Menumpuk, Saluran Tersumbat, Sungai Tercemar, "
                    "Sampah Sungai, Pohon Tumbang, Taman Rusak, Fasilitas Rusak,Pipa Bocor, "
                    "Vandalisme, Banjir, dan Lainnya. "
                    "Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan. "
                    "Buat deskripsi singkat untuk laporan perbaikan, dan tambahkan permohonan perbaikan. "
                    "Fokus pada kerusakan yang terlihat dan hindari spekulasi.\n\n"
                    "Format output yang diinginkan:\n"
                    "Kategori: [satu kategori yang dipilih]\n"
                    "Deskripsi: [deskripsi singkat]",
              },
            ],
          },
        ],
      });

      final headers = {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      print("AI RESPONSE: ${response.body}");
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        print("AI TEXT: $text");
        if (text != null && text.isNotEmpty) {
          final lines = text.trim().split('\n');
          String? category;
          String? description;
          for (var line in lines) {
            final lower = line.toLowerCase();
            if (lower.startsWith('kategori:')) {
              category = line.substring(9).trim();
            } else if (lower.startsWith('deskripsi:')) {
              description = line.substring(10).trim();
            } else if (lower.startsWith('keterangan:')) {
              description = line.substring(11).trim();
            }
          }
          description ??= text.trim();
          // Validasi kategori terhadap list categories dan fallback ke 'Lainnya'
          final validCategories = categories
              .map((c) => c.toLowerCase())
              .toList();
          String finalCategory = 'Lainnya';
          if (category != null) {
            final idx = validCategories.indexOf(category.toLowerCase());
            if (idx != -1) finalCategory = categories[idx];
          }
          setState(() {
            _aiCategory = finalCategory;
            _aiDescription = description ?? '';
            _descriptionController.text = _aiDescription!;
          });
        }
      } else {
        debugPrint('Request failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to generate AI description: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<String> detectCategoryFromImage(String base64Image) async {
    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent';

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
              },
              {
                "text":
                    "Berdasarkan foto ini, jawab HANYA dengan satu nama kategori dari daftar berikut (tanpa penjelasan): Jalan Rusak, Marka Pudar, Lampu Mati, Trotoar Rusak, Rambu Rusak, Jembatan Rusak, Sampah Menumpuk, Saluran Tersumbat, Sungai Tercemar, Sampah Sungai, Pohon Tumbang, Taman Rusak, Fasilitas Rusak, Pipa Bocor, Vandalisme, Banjir, Lainnya.\nFormat output: Kategori: [nama kategori]",
              },
            ],
          },
        ],
      });

      final headers = {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        debugPrint('Detect category failed: ${response.body}');
        return 'Lainnya';
      }

      final jsonResponse = jsonDecode(response.body);
      final text =
          jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          '';
      if (text.trim().isEmpty) return 'Lainnya';

      // Ambil value setelah "Kategori:" atau fallback ke baris pertama
      String? category;
      final lines = text.trim().split('\n');
      for (var line in lines) {
        final lower = line.toLowerCase();
        if (lower.contains('kategori:')) {
          category = line.substring(line.indexOf(':') + 1).trim();
          break;
        }
      }
      category ??= lines.first.trim();

      // Validasi terhadap daftar categories, fallback ke 'Lainnya'
      final found = categories.firstWhere(
        (c) => c.toLowerCase() == category!.toLowerCase(),
        orElse: () => 'Lainnya',
      );

      return found;
    } catch (e) {
      debugPrint('Error detecting category: $e');
      return 'Lainnya';
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Choose Image Source"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text("Camera"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text("Gallery"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // final pickedFile = await _picker.pickImage(source: source);
    // if (pickedFile != null) {
    //   setState(() {
    //     _image = File(pickedFile.path);
    //   });
    //   await _compressAndEncodeImage();
    // }

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedFile = pickedFile;
          _imageBytes = bytes;
          _image = File(pickedFile.path);
          _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        await _generateDescriptionWithAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _compressAndEncodeImage() async {
    if (_pickedFile == null || _imageBytes == null) return;
    if (kIsWeb) {
      // flutter_image_compress tidak mendukung web, gunakan bytes langsung
      setState(() {
        _base64Image = base64Encode(_imageBytes!);
      });
    } else {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        File(_pickedFile!.path).path,
        quality: 50,
      );
      if (compressedImage == null) return;
      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Failed to retrieve location: $e');
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  Future<void> _submitPost() async {
    print('Debug: _base64Image: $_base64Image');
    print('Debug: description: ${_descriptionController.text}');
    if (_base64Image == null || _descriptionController.text.isEmpty) {
      print('Debug: Upload skipped - image or description missing');
      return;
    }
    setState(() => _isUploading = true);
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('Debug: uid: $uid');

    if (uid == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User not found.')));
      return;
    }
    try {
      await _getLocation();
      print('Debug: Location - lat: $_latitude, lng: $_longitude');
      // Ambil nama lengkap dari koleksi users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';
      print('Debug: fullName: $fullName');
      await FirebaseFirestore.instance.collection('posts').add({
        'image': _base64Image,
        'description': _descriptionController.text,
        'category': _aiCategory ?? 'Lainnya',
        'createdAt': now,
        'latitude': _latitude,
        'longitude': _longitude,
        'fullName': fullName,
        'userId': uid,
      });
      print('Debug: Post added successfully');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print('Debug: Upload failed: $e');
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload the post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Post')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // (1) GestureDetector
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            // (2) SizedBox
            const SizedBox(height: 16),
            if (_isGenerating)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),

            // Kategori dan tombol refresh
            if (_aiCategory != null && !_isGenerating)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showCategorySelection,
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_aiCategory!),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, size: 16),
                          ],
                        ),
                        backgroundColor: Colors.blue[100],
                      ),
                    ),
                    if (_imageBytes != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Generate another description',
                        onPressed: _generateDescriptionWithAI,
                      ),
                  ],
                ),
              ),

            // (3) Column - TextField untuk deskripsi
            Offstage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Add a brief description...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            // (4) SizedBox
            const SizedBox(height: 16),
            // (5) ElevatedButton - Tombol kirim post
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.green,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Post', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
