import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:async';
import '../services/db_service.dart';

class AddCheckInScreen extends StatefulWidget {
  const AddCheckInScreen({super.key});

  @override
  State<AddCheckInScreen> createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _bmiController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedBlock;
  bool _isUploading = false;
  List<File> _imageFiles = [];

  @override
  void initState() {
    super.initState();
/*
    _prefillFromFitbit();
*/
  }

  /*Future<void> _prefillFromFitbit() async {
    final sample = await DBService()
        .getLatestWeightSampleForDay(DateTime.now(), source: 'fitbit');
    if (sample == null) return;
    setState(() {
      final weight = sample['value'] as num?;
      final bodyFat = sample['bodyFat'] as num?;
      final bmi = sample['bmi'] as num?;
      if (weight != null) _weightController.text = weight.toString();
      if (bodyFat != null) _bodyFatController.text = bodyFat.toString();
      if (bmi != null) _bmiController.text = bmi.toString();
    });
  }*/


  Future<List<File>> _pickAndCropImages() async {
    try {
      final picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You get three, bum.")),
        );
        return [];
      }

      List<File> croppedImages = [];

      for (int i = 0; i < pickedFiles.length && i < 3; i++) {
        final file = pickedFiles[i];

        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image ${i + 1}/${pickedFiles.length}',
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (cropped != null) {
          croppedImages.add(File(cropped.path));
        }
      }

      return croppedImages;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong picking or cropping.")),
      );
      return [];
    }
  }


  Future<void> _submit() async {
    setState(() => _isUploading = true);

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // Make sure at least 1 image is selected
    if (_imageFiles.isEmpty) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 1 photo.")),
      );
      return;
    }

    final storageRef = FirebaseStorage.instance.ref().child("check_ins/$userId");
    List<String> imageUrls = [];

    // Upload each image (however many there are, up to 3)
    for (int i = 0; i < _imageFiles.length && i < 3; i++) {
      final file = _imageFiles[i];

      try {
        final resizedBytes = await FlutterImageCompress.compressWithList(
          await file.readAsBytes(),
          minWidth: 800,
          minHeight: 1000,
          format: CompressFormat.jpeg,
        );

        final tempDir = await getTemporaryDirectory();
        final resizedPath = '${tempDir.path}/resized_${now.millisecondsSinceEpoch}_$i.jpg';
        final resizedFile = File(resizedPath)..writeAsBytesSync(resizedBytes);

        final uploadRef = storageRef.child("${monthKey}_$i.jpg");
        await uploadRef.putFile(resizedFile);
        final url = await uploadRef.getDownloadURL();
        imageUrls.add(url);
      } catch (e, stack) {
        debugPrint('🛑 Image compress/upload failed: $e');
        FirebaseCrashlytics.instance.recordError(e, stack);
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image upload failed. Try smaller images.")),
        );
        return;
      }
    }

    // Save entry in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries')
        .add({
      "userId": userId,
      "type": "checkin",
      "timestamp": Timestamp.now(),
      "month": monthKey,
      "imageUrls": imageUrls,
      "weight": _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
      "bodyFat": _bodyFatController.text.isNotEmpty ? double.tryParse(_bodyFatController.text) : null,
      "bmi": _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
      "block": _selectedBlock,
      "note": _notesController.text.trim(),
      "displayName": userData['displayName'] ?? 'Lifter',
      "title": userData['title'] ?? '',
      "profileImageUrl": userData['profileImageUrl'] ?? '',
    });

    Navigator.pop(context, true); // Done!
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Check-In")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _isUploading
                  ? null
                  : () async {
                final images = await _pickAndCropImages();

                if (images.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("You need to select at least 1 photo.")),
                  );
                } else if (images.length > 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Only 1 to 3 photos allowed.")),
                  );
                } else {
                  setState(() => _imageFiles = images);
                }
              },

              icon: const Icon(Icons.add_a_photo),
              label: const Text("Select up to 3 Photos"),
            ),

            const SizedBox(height: 12),

            if (_imageFiles.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: _imageFiles.length,
                  itemBuilder: (context, index) {
                    return Image.file(
                      _imageFiles[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    );
                  },
                ),
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
                "Wuehr Hammer",
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
              decoration: const InputDecoration(labelText: "Notes (optional)"),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              child: _isUploading ? const CircularProgressIndicator() : const Text("Submit Check-In"),
            ),
          ],
        ),
      ),
    );
  }

}
