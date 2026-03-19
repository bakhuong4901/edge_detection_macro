import 'dart:async';
import 'dart:io';

import 'package:edge_detection/edge_detection.dart';
import 'package:edge_detection/gemini_ai/analytics.dart';
import 'package:edge_detection_example/analytic_img.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _imagePath;
  SplitImage? _lhResult;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveImageToGallery() async {
    if (_imagePath == null) return;

    try {
      // Gọi hàm lưu file từ đường dẫn _imagePath
      final result = await ImageGallerySaverPlus.saveFile(_imagePath!);

      if (mounted) {
        if (result['isSuccess'] == true) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Đã lưu ảnh thành công vào thư viện!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Không thể lưu ảnh!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("Lỗi khi lưu ảnh: $e");
    }
  }

  Future<void> getImageFromCamera() async {
    bool isCameraGranted = await Permission.camera.request().isGranted;
    if (!isCameraGranted) {
      isCameraGranted =
          await Permission.camera.request() == PermissionStatus.granted;
    }

    if (!isCameraGranted) {
      // Have not permission to camera
      return;
    }

    // Generate filepath for saving
    String imagePath = join((await getApplicationSupportDirectory()).path,
        "${(DateTime.now().millisecondsSinceEpoch / 1000).round()}.jpeg");

    bool success = false;

    try {
      //Make sure to await the call to detectEdge.
      success = await EdgeDetection.detectEdge(
        imagePath,
        canUseGallery: true,
        androidScanTitle: 'Scanning',
        // use custom localizations for android
        androidCropTitle: 'Crop',
        androidCropBlackWhiteTitle: 'Black White',
        androidCropReset: 'Reset',
      );
      print("success: $success");
    } catch (e) {
      print(e);
    }

    if (!mounted) return;

    setState(() {
      if (success) {
        _imagePath = imagePath;
      }
    });
    File image = File(_imagePath!);
    img.Image colorImage = img.decodeImage(image.readAsBytesSync())!;
    _lhResult = await ImageAnalyze().splitImage(colorImage);
  }

  Future<void> getImageFromGallery() async {
    // Generate filepath for saving
    String imagePath = join((await getApplicationSupportDirectory()).path,
        "${(DateTime.now().millisecondsSinceEpoch / 1000).round()}.jpeg");

    bool success = false;
    try {
      //Make sure to await the call to detectEdgeFromGallery.
      success = await EdgeDetection.detectEdgeFromGallery(
        imagePath,
        androidCropTitle: 'Crop', // use custom localizations for android
        androidCropBlackWhiteTitle: 'Black White',
        androidCropReset: 'Reset',
      );
      print("success: $success");
    } catch (e) {
      print(e);
    }

    if (!mounted) return;

    setState(() {
      if (success) {
        _imagePath = imagePath;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('OVUMB TEST'),
            bottom: TabBar(tabs: [
              Tab(
                text: "GEMINI AI",
              ),
              Tab(
                text: "EDGE DETECTION",
              ),
            ]),
          ),
          body: TabBarView(
            children: [
              //GEMINI
              PregnancyTestScreen(),
              //EDGE
              SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 30,
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: getImageFromCamera,
                        child: const Text('Scan'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: getImageFromGallery,
                        child: Text('Upload'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Visibility(
                      visible: _imagePath != null,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: _saveImageToGallery,
                          child: Image.file(
                            File(_imagePath ?? ''),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('KẾT QUẢ: ${_lhResult?.lh}'),
                    // const Text('Cropped image path:'),
                    // Padding(
                    //   padding: EdgeInsets.only(top: 0, left: 0, right: 0),
                    //   child: Text(
                    //     _imagePath.toString(),
                    //     textAlign: TextAlign.center,
                    //     style: TextStyle(fontSize: 14),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
