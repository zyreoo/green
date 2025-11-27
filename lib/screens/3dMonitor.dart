import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';


class Monitor3D extends StatefulWidget {
  const Monitor3D({super.key});

   @override
  State<Monitor3D> createState() => _Monitor3DState();
}

class _Monitor3DState extends State<Monitor3D> {
   CameraController? _controller;
   Future<void>? _initializeControllerFuture;
   bool _cameraOn = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }


  Future<void> _captureAndSendImage() async {
    try {
      final image = await _controller!.takePicture();
      var request = http.MultipartRequest(
              'POST',
              Uri.parse('http://localhost:8000/hand'),
            );
            request.files.add(
              await http.MultipartFile.fromPath(
                'image', image.path,
              ),
            );

      var response = await request.send();

      var responseString = await response.stream.bytesToString();
      print('Response from server: $responseString');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image sent to server!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  Future<void> _turnOnCamera() async {
    try{
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras found on this device')),
        );
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller!.initialize();

      await _initializeControllerFuture;

      setState(() {
        _cameraOn = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Monitor')),
      body: Center(
        child: _cameraOn
            ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  width: 300,
                  height: 400,
                  child: CameraPreview(_controller!),
                );
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _captureAndSendImage, child: const Text('Capture & Send Image')),

          ElevatedButton(
            onPressed: () {
              setState(() {
                _cameraOn = false;
              });
            },
            child: const Text('Turn off Camera'),
          ),
        ],
      )
    : ElevatedButton(
        onPressed: _turnOnCamera,
        child: const Text('Turn on Camera'),
      ),
      ),
    );
  }


}
