import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class Monitor3D extends StatefulWidget {
  const Monitor3D({super.key});

  @override
  State<Monitor3D> createState() => _Monitor3DState();
}

class _Monitor3DState extends State<Monitor3D> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _cameraOn = false;
  List<HandLandmark> _landmarks = const [];
  String? _statusMessage;
  double _rotationY = 0;
  double _rotationX = 0;
  double _zoom = 1;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSendImage() async {
    if (_controller == null) return;

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      setState(() {
        _statusMessage = 'Processing hand...';
      });

      final responseMessage = await _sendImage(bytes, image.name);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(responseMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  Future<String> _sendImage(Uint8List bytes, String name) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:8000/hand'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: name),
    );

    final response = await request.send();
    final responseString = await response.stream.bytesToString();
    debugPrint('Server response: $responseString');

    try {
      final decoded = jsonDecode(responseString);
      if (decoded is Map && decoded['landmarks_3d'] is List) {
        final raw = decoded['landmarks_3d'] as List;
        final points = raw
            .whereType<Map>()
            .map(
              (lm) => HandLandmark(
                x: (lm['x'] as num?)?.toDouble() ?? 0,
                y: (lm['y'] as num?)?.toDouble() ?? 0,
                z: (lm['z'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(growable: false);

        setState(() {
          _landmarks = points;
          _statusMessage = 'Received ${points.length} landmarks';
        });

        return '3D hand received';
      }
    } catch (e) {
      debugPrint('Failed to parse landmarks: $e');
    }

    setState(() {
      _landmarks = const [];
      _statusMessage = responseString;
    });

    return responseString;
  }

  Future<void> _turnOnCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras found on this device')),
        );
        return;
      }

      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      if (!mounted) return;

      setState(() {
        _cameraOn = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initializing camera: $e')));
    }
  }

  void _handleRotationDrag(DragUpdateDetails details) {
    setState(() {
      _rotationY += details.delta.dx * 0.01;
      _rotationX += details.delta.dy * 0.01;
    });
  }

  void _resetView() {
    setState(() {
      _rotationX = 0;
      _rotationY = 0;
      _zoom = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Monitor')),
      body: Center(
        child: _cameraOn
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            return SizedBox(
                              width: 320,
                              height: 400,
                              child: CameraPreview(_controller!),
                            );
                          } else {
                            return const CircularProgressIndicator();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_landmarks.isNotEmpty)
                        Column(
                          children: [
                            GestureDetector(
                              onPanUpdate: _handleRotationDrag,
                              child: SizedBox(
                                width: 320,
                                height: 320,
                                child: Hand3DView(
                                  landmarks: _landmarks,
                                  rotationX: _rotationX,
                                  rotationY: _rotationY,
                                  zoom: _zoom,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Drag to rotate • Zoom ${_zoom.toStringAsFixed(1)}x',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Slider(
                              min: 0.6,
                              max: 1.8,
                              value: _zoom,
                              onChanged: (value) {
                                setState(() => _zoom = value);
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _resetView,
                                child: const Text('Reset view'),
                              ),
                            ),
                          ],
                        ),
                      if (_statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _captureAndSendImage,
                        child: const Text('Capture & Send Image'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _cameraOn = false;
                            _landmarks = const [];
                          });
                        },
                        child: const Text('Turn off Camera'),
                      ),
                    ],
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: _turnOnCamera,
                child: const Text('Turn on Camera'),
              ),
      ),
    );
  }
}

class HandLandmark {
  const HandLandmark({required this.x, required this.y, required this.z});
  final double x;
  final double y;
  final double z;
}

class Hand3DView extends StatelessWidget {
  const Hand3DView({
    super.key,
    required this.landmarks,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  final List<HandLandmark> landmarks;
  final double rotationX;
  final double rotationY;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: Hand3DPainter(
          landmarks: landmarks,
          rotationX: rotationX,
          rotationY: rotationY,
          zoom: zoom,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class Hand3DPainter extends CustomPainter {
  Hand3DPainter({
    required this.landmarks,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  final List<HandLandmark> landmarks;
  final double rotationX;
  final double rotationY;
  final double zoom;

  static const List<List<int>> _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length < 2) return;

    final projection = _projectedPoints(size);

    final bonePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final pair in _connections) {
      if (pair[0] >= projection.length || pair[1] >= projection.length) {
        continue;
      }
      canvas.drawLine(projection[pair[0]], projection[pair[1]], bonePaint);
    }

    final jointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;
    for (final point in projection) {
      canvas.drawCircle(point, 3, jointPaint);
    }
  }

  List<Offset> _projectedPoints(Size size) {
    final offsetX = size.width / 2;
    final offsetY = size.height / 2;
    final baseScale = size.width * 0.6 * zoom;
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);

    return landmarks
        .map((lm) {
          double x = lm.x - 0.5;
          double y = 0.5 - lm.y;
          double z = -lm.z;

          final rotatedX = x * cosY + z * sinY;
          double rotatedZ = -x * sinY + z * cosY;

          // Rotate around X axis (up-down drag)
          final rotatedY = y * cosX - rotatedZ * sinX;
          rotatedZ = y * sinX + rotatedZ * cosX;

          final depth = (1.2 - rotatedZ).clamp(0.3, 2.0);
          final scale = baseScale / depth;

          final projectedX = rotatedX * scale + offsetX;
          final projectedY = rotatedY * scale + offsetY;
          return Offset(projectedX, projectedY);
        })
        .toList(growable: false);
  }

  @override
  bool shouldRepaint(covariant Hand3DPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks ||
      oldDelegate.rotationX != rotationX ||
      oldDelegate.rotationY != rotationY ||
      oldDelegate.zoom != zoom;
}
