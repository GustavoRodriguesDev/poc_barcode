import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeScannerView extends StatefulWidget {
  final ValueNotifier<String> barcodeText;
  const BarcodeScannerView({required this.barcodeText, super.key});
  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  late BarcodeScanner _barcodeScanner;
  bool _canProcess = true;
  bool _isBusy = false;

  static List<CameraDescription> _cameras = [];
  late CameraController _controller;
  int _cameraIndex = -1;

  late CameraLensDirection _cameraLensDirection;
  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner();
    _cameraLensDirection = CameraLensDirection.back;

    _initialize();
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == _cameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed();
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameras.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Text('Camera não encontrada'),
      );
    }

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CameraPreview(
                _controller,
              ),
            ),
            ClipPath(
              clipper: MyCustonClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.black54,
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 8,
              child: SizedBox(
                height: 50.0,
                width: 50.0,
                child: FloatingActionButton(
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Colors.black54,
                  child: const Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 20,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<String?> _processImage(InputImage inputImage) async {
    if (!_canProcess) return null;
    if (_isBusy) return null;
    _isBusy = true;

    final barcodes = await _barcodeScanner.processImage(inputImage);

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      for (final item in barcodes) {
        if (item.displayValue!.length == 44) {
          widget.barcodeText.value = item.displayValue!;
          Navigator.pop(context);
          return item.displayValue;
        }
      }
    }
    _isBusy = false;

    return null;
  }

  Future<void> _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _controller.initialize().then((_) {
      _controller.startImageStream(_processCameraImage).then((value) {
        _cameraLensDirection = camera.lensDirection;
      });
      setState(() {});
    });
  }

  Future<void> _stopLiveFeed() async {
    await _controller.stopImageStream();
    await _controller.dispose();
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    _processImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}

class MyCustonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final retanguloLeftInside = RRect.fromRectXY(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        height: size.height * 0.3,
        width: size.width * 0.7,
      ),
      size.height * 0.3,
      size.width * 0.7,
    );

    Path path = Path()
          ..moveTo(0.0, 0.0)
          ..lineTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, 0)
          ..addRRect(retanguloLeftInside)

        //
        ;

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
