import 'dart:io';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

class photoAdd extends StatefulWidget {
  const photoAdd({super.key});

  @override
  State<photoAdd> createState() => _photoAddState();
}

class _photoAddState extends State<photoAdd> {
  XFile? _image;
  final ImagePicker picker = ImagePicker();

  // Camera
  Future<void> _getImageFromCamera() async {
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = image;
    });
  }
  
  // Gallery
  Future<void> _getImageFromGallery() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('약 봉투로 추가하기')),
      body: Column(
        children: [
          _image == null ? Text('No image selected.') : Image.file(File(_image!.path)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: _getImageFromGallery, icon: Icon(Icons.folder)),
              IconButton(onPressed: _getImageFromCamera, icon: Icon(Icons.camera_alt)),
              IconButton(onPressed: (){}, icon: Icon(Icons.cameraswitch_outlined))
            ],
          )
        ],
      ),
    );
  }
}