import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yoga Pose Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Timer? _timer;
  Uint8List? _imageBytes;
  bool _processingFrame = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> initializeCamera() async {
    if (cameras != null && cameras!.isNotEmpty) {
      _controller = CameraController(cameras![1], ResolutionPreset.medium);

      try {
        await _controller!.initialize();
        if (!mounted) return;
        setState(() {});

        _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
          if (!_processingFrame && _controller!.value.isInitialized) {
            processFrame();
          }
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    } else {
      print('No cameras found');
    }
  }

  Future<void> processFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Camera is not initialized');
      return;
    }

    _processingFrame = true;

    try {
      XFile picture = await _controller!.takePicture();
      Uint8List bytes = await picture.readAsBytes();
      String base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('http://192.168.42.228:5000/video_feed'),
        body: {'frame': base64Image},
      );

      if (response.statusCode == 200) {
        setState(() {
          _imageBytes = base64Decode(jsonDecode(response.body)['frame']);
        });
      } else {
        print('Failed to process frame');
      }
    } catch (e) {
      print('Error processing frame: $e');
    }

    _processingFrame = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yoga Pose Detection'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _controller != null && _controller!.value.isInitialized
                ? Stack(
                    children: [
                      CameraPreview(_controller!),
                      if (_imageBytes != null)
                        Positioned.fill(
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_processingFrame &&
                  _controller?.value.isInitialized == true) {
                processFrame();
              }
            },
            child: Text('Process Frame'),
          ),
        ],
      ),
    );
  }
}
