import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

const _serverBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

Uri _serverEndpoint(String pathSegment) {
  final normalizedBase = _serverBaseUrl.endsWith('/')
      ? _serverBaseUrl.substring(0, _serverBaseUrl.length - 1)
      : _serverBaseUrl;
  final normalizedPath = pathSegment.startsWith('/')
      ? pathSegment
      : '/$pathSegment';
  return Uri.parse('$normalizedBase$normalizedPath');
}

class Monitor3D extends StatefulWidget {
  const Monitor3D({super.key, this.onRequestHome});

  final VoidCallback? onRequestHome;

  @override
  State<Monitor3D> createState() => _Monitor3DState();
}

class _Monitor3DState extends State<Monitor3D> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _cameraOn = false;
  List<HandLandmark> _handLandmarks = const [];
  List<FaceLandmark> _faceLandmarks = const [];
  String? _statusMessage;
  Uint8List? _annotatedFrame;
  double _rotationY = 0;
  double _rotationX = 0;
  bool _liveMode = false;
  bool _captureInProgress = false;
  final Duration _liveInterval = const Duration(milliseconds: 250);

  Future<void> _handleGoHome() async {
    if (widget.onRequestHome != null) {
      widget.onRequestHome!();
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSendImage({bool silent = false}) async {
    if (_controller == null) return;
    if (_captureInProgress) return;
    _captureInProgress = true;

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      if (!silent && mounted) {
        setState(() {
          _statusMessage = 'Processing frame...';
        });
      }

      final responseMessage = await _sendImage(bytes, image.name);

      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(responseMessage)));
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    } finally {
      _captureInProgress = false;
    }
  }

  Future<String> _sendImage(Uint8List bytes, String name) async {
    final endpoint = _serverEndpoint('/hand');
    print('DEBUG: Sending request to: $endpoint');
    print('DEBUG: Server base URL: $_serverBaseUrl');

    final request = http.MultipartRequest('POST', endpoint);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: name),
    );

    try {
      final response = await request.send();
      print('DEBUG: Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        print('DEBUG: Error response: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }

      final responseString = await response.stream.bytesToString();

      try {
        final decoded = jsonDecode(responseString);
        if (decoded is Map) {
          final handRaw = decoded['hand_landmarks'] as List?;
          final faceRaw = decoded['face_landmarks'] as List?;
          final handPoints =
              handRaw
                  ?.whereType<Map>()
                  .map(
                    (lm) => HandLandmark(
                      x: (lm['x'] as num?)?.toDouble() ?? 0,
                      y: (lm['y'] as num?)?.toDouble() ?? 0,
                      z: (lm['z'] as num?)?.toDouble() ?? 0,
                    ),
                  )
                  .toList(growable: false) ??
              const [];
          final facePoints =
              faceRaw
                  ?.whereType<Map>()
                  .map(
                    (lm) => FaceLandmark(
                      x: (lm['x'] as num?)?.toDouble() ?? 0,
                      y: (lm['y'] as num?)?.toDouble() ?? 0,
                      z: (lm['z'] as num?)?.toDouble() ?? 0,
                    ),
                  )
                  .toList(growable: false) ??
              const [];

          if (handPoints.isNotEmpty || facePoints.isNotEmpty) {
            setState(() {
              _handLandmarks = handPoints;
              _faceLandmarks = facePoints;
              _statusMessage =
                  'Hands: ${handPoints.length} pts • Face: ${facePoints.length} pts';
              final frameString = decoded['frame'] as String?;
              _annotatedFrame = frameString != null && frameString.isNotEmpty
                  ? base64Decode(frameString)
                  : null;
            });
            return 'Frame processed';
          }

          final message = decoded['message'] as String?;
          if (message != null) {
            setState(() {
              _handLandmarks = const [];
              _faceLandmarks = const [];
              _annotatedFrame = null;
              _statusMessage = message;
            });
            return message;
          }
        }
      } catch (e) {
        print('DEBUG: JSON decode exception: $e');
      }

      setState(() {
        _handLandmarks = const [];
        _faceLandmarks = const [];
        _statusMessage = responseString;
        _annotatedFrame = null;
      });

      return responseString;
    } catch (e) {
      print('DEBUG: Network exception: $e');
      setState(() {
        _handLandmarks = const [];
        _faceLandmarks = const [];
        _statusMessage = 'Network error: $e';
        _annotatedFrame = null;
      });
      return 'Network error: $e';
    }
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
        _statusMessage = 'Camera ready';
      });
      _startLiveStream();
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
    });
  }

  Future<void> _startLiveStream() async {
    if (_liveMode) return;
    setState(() {
      _liveMode = true;
      _statusMessage = 'Live stream started';
    });
    _runLiveLoop();
  }

  void _stopLiveStream() {
    if (!_liveMode) return;
    setState(() {
      _liveMode = false;
      _statusMessage = 'Live stream stopped';
    });
  }

  Future<void> _runLiveLoop() async {
    while (_liveMode && mounted) {
      await _captureAndSendImage(silent: true);
      if (!_liveMode || !mounted) break;
      await Future.delayed(_liveInterval);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    );
    final subtitle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white70);
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _cameraOn
                  ? _buildActiveLayout(headline, subtitle, isCompact)
                  : _buildIdleLayout(headline, subtitle, isCompact),
            ),
            if (isCompact)
              Positioned(right: 16, top: 12, child: _buildCompactHomeButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLayout(
    TextStyle? headline,
    TextStyle? subtitle,
    bool compact,
  ) {
    final horizontal = compact ? 16.0 : 24.0;
    final vertical = compact ? 16.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 1200,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(headline, subtitle, compact),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final allowSideBySide =
                      !compact && constraints.maxWidth > 900;
                  if (allowSideBySide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCameraCard(subtitle, compact)),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildUnifiedMeshCard(subtitle, compact),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildCameraCard(subtitle, compact),
                      const SizedBox(height: 20),
                      _buildUnifiedMeshCard(subtitle, compact),
                    ],
                  );
                },
              ),
              SizedBox(height: compact ? 16 : 20),
              _buildServerPreviewCard(subtitle, compact),
              const SizedBox(height: 16),
              if (_statusMessage != null)
                _buildGlassSurface(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: 12,
                  ),
                  borderRadius: compact ? 22 : 26,
                  child: Text(
                    _statusMessage!,
                    style: subtitle,
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: compact ? 20 : 24),
              _buildControlsRow(compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCard(TextStyle? subtitle, bool compact) {
    final aspect = compact ? 9 / 16 : 3 / 4;
    return _buildGlassSurface(
      padding: EdgeInsets.all(compact ? 16 : 20),
      borderRadius: compact ? 22 : 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Camera Feed',
                style: subtitle?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.circle, color: Colors.redAccent, size: 12),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
            child: AspectRatio(
              aspectRatio: aspect,
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.redAccent.withValues(alpha: 0.08),
                        BlendMode.softLight,
                      ),
                      child: CameraPreview(_controller!),
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMeshCard(TextStyle? subtitle, bool compact) {
    return _buildGlassSurface(
      padding: EdgeInsets.all(compact ? 16 : 20),
      borderRadius: compact ? 22 : 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3D Mesh',
                style: subtitle?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_handLandmarks.length + _faceLandmarks.length} points',
                style: subtitle?.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            child: GestureDetector(
              onPanUpdate: _handleRotationDrag,
              child: SizedBox(
                height: compact ? 260 : 320,
                child: _handLandmarks.isNotEmpty || _faceLandmarks.isNotEmpty
                    ? CombinedMeshView(
                        handLandmarks: _handLandmarks,
                        faceLandmarks: _faceLandmarks,
                        rotationX: _rotationX,
                        rotationY: _rotationY,
                      )
                    : Center(
                        child: Text(
                          'Show your hand or face to capture a mesh',
                          style: subtitle,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetView,
              child: const Text('Reset view'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleLayout(
    TextStyle? headline,
    TextStyle? subtitle,
    bool compact,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 32 : 40,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 400 : 460),
          child: _buildGlassSurface(
            padding: EdgeInsets.all(compact ? 24 : 32),
            borderRadius: compact ? 24 : 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.front_hand,
                  size: compact ? 60 : 72,
                  color: Colors.white,
                ),
                SizedBox(height: compact ? 12 : 16),
                Text('Step into See You in 3D', style: headline),
                const SizedBox(height: 8),
                Text(
                  'Stream your hand and face to the cloud and watch them reconstructed in real-time.',
                  style: subtitle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: compact ? 20 : 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _turnOnCamera,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Start Capture'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSurface({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    double borderRadius = 28,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildServerPreviewCard(TextStyle? subtitle, bool compact) {
    final aspect = compact ? 3 / 4 : 4 / 3;
    return _buildGlassSurface(
      padding: EdgeInsets.all(compact ? 16 : 20),
      borderRadius: compact ? 22 : 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Server Preview',
            style: subtitle?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _annotatedFrame != null
                ? AspectRatio(
                    aspectRatio: aspect,
                    child: Image.memory(_annotatedFrame!, fit: BoxFit.cover),
                  )
                : AspectRatio(
                    aspectRatio: aspect,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      alignment: Alignment.center,
                      child: Text(
                        'Awaiting data from server...',
                        style: subtitle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'See exactly what the server detects — both face and hand overlays from the remote pipeline.',
            style: subtitle?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
    TextStyle? headline,
    TextStyle? subtitle,
    bool compact,
  ) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('See You in 3D', style: headline),
          const SizedBox(height: 6),
          Text(
            'Stream your hand + face into a shared, live mesh.',
            style: subtitle,
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.redAccent, size: 10),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('See You in 3D', style: headline),
            const SizedBox(height: 4),
            Text(
              'Stream your hand + face into a shared, live mesh.',
              style: subtitle,
            ),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.circle, color: Colors.redAccent, size: 10),
                SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsRow(bool compact) {
    void handleTurnOff() {
      setState(() {
        _cameraOn = false;
        _handLandmarks = const [];
        _faceLandmarks = const [];
        _statusMessage = null;
        _annotatedFrame = null;
      });
      _stopLiveStream();
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _liveMode ? _stopLiveStream : _startLiveStream,
            icon: Icon(_liveMode ? Icons.stop : Icons.play_arrow),
            label: Text(_liveMode ? 'Stop Live' : 'Start Live'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: handleTurnOff,
              child: const Text('Turn off camera'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _liveMode ? _stopLiveStream : _startLiveStream,
            icon: Icon(_liveMode ? Icons.stop : Icons.play_arrow),
            label: Text(_liveMode ? 'Stop Live' : 'Start Live'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: handleTurnOff,
          child: const Text('Turn off camera'),
        ),
      ],
    );
  }

  Widget _buildCompactHomeButton() {
    return TextButton.icon(
      onPressed: _handleGoHome,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.home_outlined, size: 18),
      label: const Text('Home'),
    );
  }
}

class HandLandmark {
  const HandLandmark({required this.x, required this.y, required this.z});
  final double x;
  final double y;
  final double z;
}

class FaceLandmark {
  const FaceLandmark({required this.x, required this.y, required this.z});
  final double x;
  final double y;
  final double z;
}

class CombinedMeshView extends StatelessWidget {
  const CombinedMeshView({
    super.key,
    required this.handLandmarks,
    required this.faceLandmarks,
    required this.rotationX,
    required this.rotationY,
  });

  final List<HandLandmark> handLandmarks;
  final List<FaceLandmark> faceLandmarks;
  final double rotationX;
  final double rotationY;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: CombinedMeshPainter(
          handLandmarks: handLandmarks,
          faceLandmarks: faceLandmarks,
          rotationX: rotationX,
          rotationY: rotationY,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class CombinedMeshPainter extends CustomPainter {
  CombinedMeshPainter({
    required this.handLandmarks,
    required this.faceLandmarks,
    required this.rotationX,
    required this.rotationY,
  });

  final List<HandLandmark> handLandmarks;
  final List<FaceLandmark> faceLandmarks;
  final double rotationX;
  final double rotationY;

  static const List<List<int>> _handConnections = [
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
    final projectedHands = _projectHandPoints(size);
    final projectedFace = faceLandmarks
        .map((lm) => Offset(lm.x * size.width, lm.y * size.height))
        .toList();

    final handConnectionPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final pair in _handConnections) {
      if (pair[0] >= projectedHands.length ||
          pair[1] >= projectedHands.length) {
        continue;
      }
      canvas.drawLine(
        projectedHands[pair[0]],
        projectedHands[pair[1]],
        handConnectionPaint,
      );
    }

    final handJointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;
    for (final point in projectedHands) {
      canvas.drawCircle(point, 3, handJointPaint);
    }

    final facePaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    for (final point in projectedFace) {
      canvas.drawCircle(point, 1.3, facePaint);
    }
  }

  List<Offset> _projectHandPoints(Size size) {
    final offsetX = size.width / 2;
    final offsetY = size.height / 2;
    final baseScale = size.width * 0.6;
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);

    return handLandmarks
        .map((lm) {
          double x = lm.x - 0.5;
          double y = lm.y - 0.5;
          double z = -lm.z;

          final rotatedX = x * cosY + z * sinY;
          double rotatedZ = -x * sinY + z * cosY;

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
  bool shouldRepaint(covariant CombinedMeshPainter oldDelegate) =>
      oldDelegate.handLandmarks != handLandmarks ||
      oldDelegate.faceLandmarks != faceLandmarks ||
      oldDelegate.rotationX != rotationX ||
      oldDelegate.rotationY != rotationY;
}
