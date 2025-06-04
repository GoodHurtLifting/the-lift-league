import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lift_league/models/timeline_entry.dart';

class EditCheckInScreen extends StatefulWidget {
  final String entryId;
  final TimelineEntry entry;
  final String userId;

  const EditCheckInScreen({
    super.key,
    required this.entryId,
    required this.entry,
    required this.userId,
  });

  @override
  State<EditCheckInScreen> createState() => _EditCheckInScreenState();
}

class _EditCheckInScreenState extends State<EditCheckInScreen> {
  late List<String> existingImageUrls;
  final List<File> newImages = [];
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _bmiController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedBlock;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    existingImageUrls = List.from(widget.entry.imageUrls);
    _weightController.text = widget.entry.weight?.toString() ?? '';
    _bodyFatController.text = widget.entry.bodyFat?.toString() ?? '';
    _bmiController.text = widget.entry.bmi?.toString() ?? '';
    _notesController.text = widget.entry.note ?? '';
    _selectedBlock = widget.entry.block;
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
      uiSettings: [
        AndroidUiSettings(lockAspectRatio: true),
        IOSUiSettings(aspectRatioLockEnabled: true),
      ],
    );

    if (cropped != null) {
      setState(() {
        newImages.add(File(cropped.path));
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isUploading = true);
    final storageRef = FirebaseStorage.instance.ref().child("check_ins/${widget.userId}");

    // Upload new images
    List<String> allUrls = [...existingImageUrls];

    for (int i = 0; i < newImages.length; i++) {
      final file = newImages[i];

      final resizedBytes = await FlutterImageCompress.compressWithList(
        await file.readAsBytes(),
        minWidth: 800,
        minHeight: 1000,
        format: CompressFormat.jpeg,
      );

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/edit_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final resizedFile = File(path)..writeAsBytesSync(resizedBytes);

      final uploadRef = storageRef.child("edit_${widget.entryId}_$i.jpg");
      await uploadRef.putFile(resizedFile);
      final url = await uploadRef.getDownloadURL();
      allUrls.add(url);
    }

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .doc(widget.entryId)
        .update({
      'imageUrls': allUrls,
      'weight': _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
      'bodyFat': _bodyFatController.text.isNotEmpty ? double.tryParse(_bodyFatController.text) : null,
      'bmi': _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
      'block': _selectedBlock,
      'notes': _notesController.text.trim(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allPreviewUrls = [...existingImageUrls, ...newImages.map((f) => f.path)];

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Check-In")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text("📅 ${widget.entry.timestamp.toLocal().toString().split(' ').first}"),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...existingImageUrls.map((url) => Stack(
                  children: [
                    Image.network(url, height: 150, width: 100, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => existingImageUrls.remove(url));
                        },
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                )),
                ...newImages.map((file) => Stack(
                  children: [
                    Image.file(file, height: 150, width: 100, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => newImages.remove(file));
                        },
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                )),
                if (existingImageUrls.length + newImages.length < 3)
                  GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      height: 150,
                      width: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Weight (lbs)"),
            ),
            TextField(
              controller: _bodyFatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Body Fat (%)"),
            ),
            TextField(
              controller: _bmiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "BMI"),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBlock,
              items: [
                "Push Pull Legs",
                "Upper Lower",
                "Full Body",
                "Full Body Plus",
                "5 x 5",
                "Texas Method",
                "Weuhr Hammer",
                "Gran Moreno",
                "Body Split",
                "Shatner",
                "Super Split",
                "PPL Plus",
              ].map((block) {
                return DropdownMenuItem(value: block, child: Text(block));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBlock = val),
              decoration: const InputDecoration(labelText: "Current Block"),
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Notes"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _saveChanges,
              child: _isUploading ? const CircularProgressIndicator() : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
