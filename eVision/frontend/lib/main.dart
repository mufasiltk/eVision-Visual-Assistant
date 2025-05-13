import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  late CameraController _cameraController;
  bool isCameraInitialized = false;
  late AnimationController _animationController;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _initializeCamera() async {
    _cameraController = CameraController(cameras![0], ResolutionPreset.medium);
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() {
      isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _captureAndSendImage(String mode) async {
    if (!_cameraController.value.isInitialized ||
        _cameraController.value.isTakingPicture) {
      print("Camera not ready yet!");
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      print("Capturing image...");
      XFile imageFile = await _cameraController.takePicture();
      print("Image captured: ${imageFile.path}");

      final uri = Uri.parse(
          'http://192.168.158.179:5019/${mode == 'object' ? 'detect_objects' : 'detect_text'}');

      var request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('image', imageFile.path));

      print("Sending image to $mode endpoint...");
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData.body);
        print("Server response: $jsonResponse");

        String message = (mode == 'object')
            ? "Objects: ${(jsonResponse['objects'] as List<dynamic>).join(', ')}"
            : "Text: ${jsonResponse['text']}";

        print(message);

        var audioUrl = 'http://192.168.158.179:5019/get_audio';
        var audioResponse = await http.get(Uri.parse(audioUrl));

        File audioFile =
        File('${(await getTemporaryDirectory()).path}/output.mp3');
        await audioFile.writeAsBytes(audioResponse.bodyBytes);

        AudioPlayer player = AudioPlayer();
        print("Playing audio...");
        await player.play(DeviceFileSource(audioFile.path));
      } else {
        print("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: isCameraInitialized
                  ? CameraPreview(_cameraController)
                  : Center(child: CircularProgressIndicator()),
            ),

            // App title bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'eVision',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Buttons at bottom
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _captureAndSendImage('object'),
                      //icon: Icon(Icons.remove_red_eye, color: Colors.white),
                      label: Text(
                        "Detect Objects",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _captureAndSendImage('text'),
                      //icon: Icon(Icons.text_snippet, color: Colors.white),
                      label: Text(
                        "Read Text",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loader
            if (isProcessing)
              Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
