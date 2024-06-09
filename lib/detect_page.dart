import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

class DetectPage extends StatefulWidget {
  // final String selectedPose;

  // DetectPage({required this.selectedPose});

  @override
  _DetectPageState createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  late IO.Socket socket;
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  late Timer _timer;
  Uint8List? _imageBytes;
  String poseClass = '';
  double probability = 0.0;
  bool showImage = false;
  bool isConnected = false; // Tambahkan variabel ini

  @override
  void initState() {
    super.initState();
    // Mengunci orientasi ke landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    initializeCamera();
    connectToServer();
  }

  @override
  void dispose() {
    // Mengembalikan orientasi ke default (mengizinkan semua orientasi)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    socket.dispose();
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void connectToServer() {
    // Ganti 'http://your-flask-server-url' dengan URL server Flask Anda
    socket =
        IO.io('https://4dba-36-68-53-220.ngrok-free.app', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.on('connect', (_) {
      print('Connected to server');
      setState(() {
        isConnected = true;
      });
      // Tampilkan Snackbar saat terhubung ke server
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terhubung ke Socket.IO server'),
        ),
      );
      startSendingImages();
    });

    socket.on('response', (data) {
      // Terima respons JSON dan ekstrak data gambar, kelas pose, dan probabilitas
      print('Received data from server: $data');

      try {
        String imageData = data['imageData'];
        String bodyLanguageClass = data['pose_class'];
        double prob = double.parse(data['prob']);

        // Konversi data gambar dari base64 ke bytes
        List<int> imageBytes = base64Decode(imageData);
        setState(() {
          _imageBytes = Uint8List.fromList(imageBytes);
          poseClass = bodyLanguageClass;
          probability = prob;
          showImage = true;
        });
      } catch (e) {
        print('Error handling response: $e');
      }

      // Setelah 2 detik, kembali ke tampilan kamera
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          showImage = false;
        });
      });
    });

    socket.connect();
  }

  Future<void> initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.high);
    await _controller.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: isConnected
                ? (showImage
                    ? _imageBytes != null
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : CircularProgressIndicator()
                    : _controller.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: CameraPreview(_controller),
                          )
                        : CircularProgressIndicator())
                : CircularProgressIndicator(), // Tampilkan loading saat belum terhubung
          ),
          if (isConnected)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pose: $poseClass',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Probability: ${probability.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    // Text(
                    //   'Selected Pose: ${widget.selectedPose}',
                    //   style: TextStyle(
                    //     color: Colors.white,
                    //     fontSize: 18,
                    //   ),
                    // ),
                    // Text(
                    //   poseClass == widget.selectedPose
                    //       ? 'Gerakan Sesuai'
                    //       : 'Gerakan Tidak Sesuai',
                    //   style: TextStyle(
                    //     color: Colors.white,
                    //     fontSize: 18,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void startSendingImages() {
    // Timer untuk mengambil dan mengirim gambar setiap 3 detik
    _timer = Timer.periodic(Duration(seconds: 3), (Timer timer) async {
      if (_controller.value.isInitialized) {
        // Ambil foto dari kamera
        final picture = await _controller.takePicture();
        // Ambil file foto
        final File imageFile = File(picture.path);
        // Baca file gambar sebagai byte
        final List<int> imageBytes = await imageFile.readAsBytes();
        // Encode bytes ke base64
        final String base64Image = base64Encode(imageBytes);
        // Kirim gambar ke server menggunakan Socket.IO
        socket.emit('image', base64Image);
      }
    });
  }
}
