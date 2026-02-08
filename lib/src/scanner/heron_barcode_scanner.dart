import 'dart:async';
import 'dart:io';
import 'dart:math' show max;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../generated/scan_window_api.g.dart';
import '../models/barcode_overlay_style.dart';
import '../models/capture_result.dart';
import '../models/detected_barcode.dart';
import '../models/scan_window_style.dart';
import '../services/scan_window_service.dart';

// =============================================================================
// HeronBarcodeScanner Widget
// =============================================================================

/// ML Kit + camera を使用したバーコードスキャナーWidget
///
/// 高フレームレートでのバーコード検知、スムーズオーバーレイ描画、
/// スキャンウィンドウフィルタリング、画像キャプチャ機能を提供する。
///
/// ## 基本的な使い方
///
/// ```dart
/// HeronBarcodeScanner(
///   onDetect: (barcodes, imageSize) {
///     for (final barcode in barcodes) {
///       print('検出: ${barcode.rawValue}');
///     }
///   },
/// )
/// ```
///
/// ## GlobalKeyでStateにアクセス
///
/// ```dart
/// final scannerKey = GlobalKey<HeronBarcodeScannerState>();
///
/// HeronBarcodeScanner(
///   key: scannerKey,
///   onDetect: (barcodes, imageSize) { /* ... */ },
/// )
///
/// // トーチ切り替え
/// scannerKey.currentState?.toggleTorch();
///
/// // 画像キャプチャ
/// final result = await scannerKey.currentState?.captureImage(barcode, imageSize);
/// ```
class HeronBarcodeScanner extends StatefulWidget {
  /// コンストラクタ
  const HeronBarcodeScanner({
    this.onDetect,
    this.onCameraReady,
    this.onDetectionStateChanged,
    this.onAutoStopped,
    this.autoStopDuration,
    this.formats = const [BarcodeFormat.all],
    this.showOverlay = true,
    this.overlayStyle = const BarcodeOverlayStyle(),
    this.scanWindowMarginRatio,
    this.showScanWindow = true,
    this.scanWindowStyle = const ScanWindowStyle(),
    this.loadingWidget,
    this.resolution = ResolutionPreset.high,
    this.captureSubdirectory = 'heron_scanner',
    this.captureQuality = 80,
    super.key,
  });

  /// バーコード検知時のコールバック（nullの場合は検知のみ行う）
  final void Function(List<DetectedBarcode> barcodes, Size imageSize)? onDetect;

  /// カメラ準備完了時のコールバック
  final void Function(CameraController controller)? onCameraReady;

  /// バーコード検出状態が変化した時のコールバック（オーバーレイ表示/非表示）
  final void Function({required bool hasDetectedBarcodes})? onDetectionStateChanged;

  /// 自動停止時のコールバック
  final VoidCallback? onAutoStopped;

  /// 未検出がこの時間継続したら自動停止（nullの場合は自動停止しない）
  final Duration? autoStopDuration;

  /// 検知対象のバーコードフォーマット
  final List<BarcodeFormat> formats;

  /// オーバーレイを表示するか
  final bool showOverlay;

  /// オーバーレイスタイル
  final BarcodeOverlayStyle overlayStyle;

  /// スキャンウィンドウのマージン比率（0.0〜0.4）
  /// nullの場合はスキャンウィンドウを使用しない（全画面スキャン）
  final double? scanWindowMarginRatio;

  /// スキャンウィンドウのガイドを表示するか
  final bool showScanWindow;

  /// スキャンウィンドウスタイル
  final ScanWindowStyle scanWindowStyle;

  /// カメラ初期化中に表示するWidget（nullの場合はデフォルトのローディング表示）
  final Widget? loadingWidget;

  /// カメラ解像度
  final ResolutionPreset resolution;

  /// キャプチャ画像を保存するサブディレクトリ名
  final String captureSubdirectory;

  /// キャプチャ画像のJPEG品質（0〜100）
  final int captureQuality;

  @override
  State<HeronBarcodeScanner> createState() => HeronBarcodeScannerState();
}

/// [HeronBarcodeScanner] の State
///
/// GlobalKeyを使用してアクセスし、トーチ切替やカメラ切替、
/// スキャンの一時停止/再開、画像キャプチャなどを行う。
class HeronBarcodeScannerState extends State<HeronBarcodeScanner>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  BarcodeScanner? _barcodeScanner;
  bool _isProcessing = false;
  bool _isInitialized = false;
  List<CameraDescription>? _cameras;

  // オーバーレイ用の状態
  Size _imageSize = Size.zero;
  Size _widgetSize = Size.zero;
  bool _torchEnabled = false;

  // 自動停止機能用
  DateTime? _lastDetectionTime;
  bool _isAutoStopped = false;

  // スムーズオーバーレイ用
  late final _SmoothOverlayController _overlayController;

  // 前回の検出状態（変化検知用）
  bool _lastHasDetected = false;

  // ネイティブへ送信済みのscanWindow
  Rect? _lastSentScanWindow;

  // ストリームフレームキャプチャ用
  CameraImage? _lastDetectedFrame;
  Size? _lastDetectedFrameSize;

  // ---------------------------------------------------------------------------
  // 公開プロパティ
  // ---------------------------------------------------------------------------

  /// トーチ（フラッシュライト）の状態
  bool get torchEnabled => _torchEnabled;

  /// カメラが初期化済みか
  bool get isInitialized => _isInitialized;

  /// 自動停止中か
  bool get isAutoStopped => _isAutoStopped;

  /// バーコードを検出中か（オーバーレイが実際に表示されているか）
  bool get hasDetectedBarcodes => _overlayController.trackedBarcodes.any((b) => b.fadeProgress > 0);

  /// 画像キャプチャモードか
  bool _isCapturing = false;

  /// 画像キャプチャモードか
  bool get isCapturing => _isCapturing;

  // ---------------------------------------------------------------------------
  // 公開メソッド
  // ---------------------------------------------------------------------------

  /// 画像キャプチャモードを開始
  void startImageCapture() {
    _isCapturing = true;
  }

  /// 画像キャプチャモードを終了
  void stopImageCapture() {
    _isCapturing = false;
  }

  /// 画像をキャプチャして保存
  ///
  /// [barcode] 検出されたバーコード
  /// [scanImageSize] スキャン時の画像サイズ
  /// [useStreamFrame] trueの場合ストリームフレームを使用（座標完全一致）、
  ///                  falseの場合カメラ撮影を使用（高画質）
  /// Returns: キャプチャ結果（失敗時はnull）
  Future<CaptureResult?> captureImage(
    DetectedBarcode barcode,
    Size scanImageSize, {
    bool useStreamFrame = true,
  }) async {
    if (!useStreamFrame) {
      return captureImageWithCamera(barcode, scanImageSize);
    }
    return _captureStreamFrame(barcode, scanImageSize);
  }

  /// カメラでの写真撮影による画像保存（高画質だが座標ずれの可能性あり）
  Future<CaptureResult?> captureImageWithCamera(DetectedBarcode barcode, Size scanImageSize) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || !mounted) {
      return null;
    }

    try {
      final wasStreaming = controller.value.isStreamingImages;
      if (wasStreaming) {
        await controller.stopImageStream();
      }

      if (!mounted || _cameraController == null) return null;

      final file = await controller.takePicture();
      if (!mounted) return null;

      final tempDir = await getTemporaryDirectory();
      final captureDir = Directory(p.join(tempDir.path, widget.captureSubdirectory));
      if (!captureDir.existsSync()) {
        await captureDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedCode = barcode.rawValue.replaceAll(RegExp(r'[^\w]'), '_');
      final fileName = '${timestamp}_$sanitizedCode.jpg';
      final destPath = p.join(captureDir.path, fileName);

      await File(file.path).copy(destPath);
      await File(file.path).delete();

      if (wasStreaming && mounted && _cameraController != null) {
        await _cameraController!.startImageStream(_processImage);
      }

      final codeMetadata = _createCodeMetadata(barcode, scanImageSize);
      return CaptureResult(imagePath: destPath, codeMetadata: codeMetadata);
    } on Exception catch (e) {
      debugPrint('Image capture error: $e');
      if (mounted && _cameraController != null && !_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.startImageStream(_processImage);
        } on Exception catch (e2) {
          debugPrint('Failed to restart image stream: $e2');
        }
      }
      return null;
    }
  }

  /// トーチの切り替え
  Future<void> toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _torchEnabled = !_torchEnabled;
      await _cameraController!.setFlashMode(_torchEnabled ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } on Exception catch (e) {
      debugPrint('Torch toggle error: $e');
    }
  }

  /// カメラの切り替え
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentDirection = _cameraController?.description.lensDirection;
    final newCamera = _cameras!.firstWhere(
      (c) => c.lensDirection != currentDirection,
      orElse: () => _cameras!.first,
    );

    final oldController = _cameraController;
    _cameraController = null;
    setState(() => _isInitialized = false);
    await oldController?.dispose();

    try {
      final controller = CameraController(
        newCamera,
        widget.resolution,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }

      await controller.startImageStream(_processImage);
      _cameraController = controller;
      setState(() => _isInitialized = true);
    } on Exception catch (e) {
      debugPrint('Camera switch error: $e');
    }
  }

  /// スキャンを一時停止（カメラも停止）
  Future<void> pauseScanning() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() => _isInitialized = false);
    }

    try {
      if (controller != null) {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await controller.dispose();
      }
    } on Exception catch (e) {
      debugPrint('Pause scanning error: $e');
    }
  }

  /// スキャンを再開（カメラも再起動）
  Future<void> resumeScanning() async {
    _isAutoStopped = false;
    _lastDetectionTime = DateTime.now();

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initializeCamera();
      } else if (!_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processImage);
      }
    } on Exception catch (e) {
      debugPrint('Resume scanning error: $e');
    }
  }

  /// 一括スキャン用の一時画像をクリア
  Future<void> clearCapturedImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final captureDir = Directory(p.join(tempDir.path, widget.captureSubdirectory));
      if (captureDir.existsSync()) {
        await captureDir.delete(recursive: true);
      }
    } on Exception catch (e) {
      debugPrint('Failed to clear captured images: $e');
    }
  }

  /// 一括スキャン用の一時画像をクリア（static版）
  static Future<void> clearImages([String subdirectory = 'heron_scanner']) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final captureDir = Directory(p.join(tempDir.path, subdirectory));
      if (captureDir.existsSync()) {
        await captureDir.delete(recursive: true);
      }
    } on Exception catch (e) {
      debugPrint('Failed to clear images: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ライフサイクル
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _overlayController = _SmoothOverlayController(vsync: this, style: widget.overlayStyle);
    _overlayController.addListener(_onOverlayChanged);
    _initializeScanner();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(HeronBarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanWindowMarginRatio != widget.scanWindowMarginRatio) {
      if (widget.scanWindowMarginRatio == null || widget.scanWindowMarginRatio! <= 0) {
        _lastSentScanWindow = null;
        ScanWindowService.updateScanWindow(null);
      }
    }
    if (oldWidget.overlayStyle != widget.overlayStyle) {
      _overlayController.style = widget.overlayStyle;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayController.removeListener(_onOverlayChanged);
    _overlayController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    _isInitialized = false;
    controller?.dispose();
    _barcodeScanner?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;

    if (state == AppLifecycleState.inactive) {
      _cameraController = null;
      if (mounted) {
        setState(() => _isInitialized = false);
      }
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isAutoStopped) {
        _initializeCamera();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // カメラ・スキャナー初期化
  // ---------------------------------------------------------------------------

  void _initializeScanner() {
    _barcodeScanner = BarcodeScanner(formats: widget.formats);
  }

  Future<void> _initializeCamera() async {
    if (_cameraController != null) {
      final oldController = _cameraController;
      _cameraController = null;
      await oldController?.dispose();
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;
      if (!mounted) return;

      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      final controller = CameraController(
        camera,
        widget.resolution,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }

      await controller.startImageStream(_processImage);
      _cameraController = controller;
      _lastDetectionTime = DateTime.now();
      setState(() => _isInitialized = true);

      widget.onCameraReady?.call(controller);
    } on Exception catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 画像処理
  // ---------------------------------------------------------------------------

  Future<void> _processImage(CameraImage image) async {
    final controller = _cameraController;
    if (_isProcessing || _barcodeScanner == null || _isAutoStopped || controller == null) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final barcodes = await _barcodeScanner!.processImage(inputImage);

      if (!mounted || _cameraController == null) {
        _isProcessing = false;
        return;
      }

      final sensorOrientation = controller.description.sensorOrientation;
      final isRotated = sensorOrientation == 90 || sensorOrientation == 270;
      final imageSize = isRotated
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      var detectedBarcodes = barcodes.map((barcode) {
        return DetectedBarcode(
          rawValue: barcode.rawValue ?? '',
          format: barcode.format,
          boundingBox: barcode.boundingBox,
          corners: barcode.cornerPoints.isNotEmpty ? barcode.cornerPoints : null,
        );
      }).toList();

      // スキャンウィンドウフィルタリング（画面座標ベース）
      final marginRatio = widget.scanWindowMarginRatio;
      if (marginRatio != null && marginRatio > 0 && detectedBarcodes.isNotEmpty) {
        detectedBarcodes = _filterByScanWindow(detectedBarcodes, imageSize, marginRatio);
      }

      // 自動停止タイマー更新
      if (detectedBarcodes.isNotEmpty) {
        _lastDetectionTime = DateTime.now();
        _lastDetectedFrame = image;
        _lastDetectedFrameSize = imageSize;
      } else {
        _checkAutoStop();
      }

      if (!mounted) {
        _isProcessing = false;
        return;
      }

      _imageSize = imageSize;
      _overlayController.updateBarcodes(detectedBarcodes);

      widget.onDetect?.call(detectedBarcodes, imageSize);
    } on Exception catch (e) {
      debugPrint('Barcode processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // フィルタリング・座標変換
  // ---------------------------------------------------------------------------

  /// 自動停止チェック
  void _checkAutoStop() {
    final autoStopDuration = widget.autoStopDuration;
    if (autoStopDuration == null) return;
    if (_lastDetectionTime == null) return;

    final elapsed = DateTime.now().difference(_lastDetectionTime!);
    if (elapsed >= autoStopDuration) {
      _performAutoStop();
    }
  }

  Future<void> _performAutoStop() async {
    if (_isAutoStopped) return;
    _isAutoStopped = true;
    await pauseScanning();
    widget.onAutoStopped?.call();
  }

  /// スキャンウィンドウでバーコードをフィルタリング（画面座標ベース）
  List<DetectedBarcode> _filterByScanWindow(
    List<DetectedBarcode> barcodes,
    Size imageSize,
    double marginRatio,
  ) {
    final screenSize = _widgetSize;
    if (screenSize.isEmpty) return barcodes;

    final scanRect = Rect.fromLTRB(
      screenSize.width * marginRatio,
      screenSize.height * marginRatio,
      screenSize.width * (1 - marginRatio),
      screenSize.height * (1 - marginRatio),
    );

    final isFrontCamera = _cameraController?.description.lensDirection == CameraLensDirection.front;
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final offsetX = (screenSize.width - imageSize.width * scale) / 2;
    final offsetY = (screenSize.height - imageSize.height * scale) / 2;

    return barcodes.where((barcode) {
      final center = barcode.boundingBox.center;
      var x = center.dx;
      final y = center.dy;
      if (isFrontCamera) {
        x = imageSize.width - x;
      }
      final screenPoint = Offset(x * scale + offsetX, y * scale + offsetY);
      return scanRect.contains(screenPoint);
    }).toList();
  }

  /// ネイティブ側のscanWindowを更新（レイアウトに合わせて補正）
  Future<void> _updateNativeScanWindowWithLayout(Size widgetSize, Size textureSize) async {
    final marginRatio = widget.scanWindowMarginRatio;
    if (marginRatio == null || marginRatio <= 0) {
      if (_lastSentScanWindow != null) {
        _lastSentScanWindow = null;
        await ScanWindowService.updateScanWindow(null);
      }
      return;
    }

    if (widgetSize.isEmpty || textureSize.isEmpty) return;

    final scanWindowInWidget = Rect.fromLTRB(
      widgetSize.width * marginRatio,
      widgetSize.height * marginRatio,
      widgetSize.width * (1.0 - marginRatio),
      widgetSize.height * (1.0 - marginRatio),
    );

    final normalizedWindow = _calculateScanWindowRelativeToTextureInPercentage(
      scanWindowInWidget,
      textureSize: textureSize,
      widgetSize: widgetSize,
    );

    if (_isSameRect(_lastSentScanWindow, normalizedWindow)) return;

    _lastSentScanWindow = normalizedWindow;
    await ScanWindowService.updateScanWindow(
      ScanWindowRect(
        left: normalizedWindow.left,
        top: normalizedWindow.top,
        right: normalizedWindow.right,
        bottom: normalizedWindow.bottom,
      ),
    );
  }

  bool _isSameRect(Rect? a, Rect b, {double epsilon = 0.0005}) {
    if (a == null) return false;
    return (a.left - b.left).abs() < epsilon &&
        (a.top - b.top).abs() < epsilon &&
        (a.right - b.right).abs() < epsilon &&
        (a.bottom - b.bottom).abs() < epsilon;
  }

  /// BoxFit.coverのクロップを考慮したscanWindow座標変換
  Rect _calculateScanWindowRelativeToTextureInPercentage(
    Rect scanWindow, {
    required Size textureSize,
    required Size widgetSize,
  }) {
    final fittedTextureSize = applyBoxFit(BoxFit.cover, textureSize, widgetSize);

    var sx = fittedTextureSize.destination.width / textureSize.width;
    var sy = fittedTextureSize.destination.height / textureSize.height;
    final double s = max(sx, sy);
    sx = s;
    sy = s;

    final textureWindow = Alignment.center.inscribe(
      Size(textureSize.width * sx, textureSize.height * sy),
      Rect.fromLTWH(0, 0, widgetSize.width, widgetSize.height),
    );

    final scanWindowInTexSpace = Rect.fromLTRB(
      (1 / sx) * (scanWindow.left - textureWindow.left),
      (1 / sy) * (scanWindow.top - textureWindow.top),
      (1 / sx) * (scanWindow.right - textureWindow.left),
      (1 / sy) * (scanWindow.bottom - textureWindow.top),
    );

    final clippedScanWndInTexSpace = scanWindowInTexSpace.intersect(
      Rect.fromLTWH(0, 0, textureSize.width, textureSize.height),
    );

    return Rect.fromLTRB(
      clippedScanWndInTexSpace.left / textureSize.width,
      clippedScanWndInTexSpace.top / textureSize.height,
      clippedScanWndInTexSpace.right / textureSize.width,
      clippedScanWndInTexSpace.bottom / textureSize.height,
    );
  }

  void _onOverlayChanged() {
    final currentHasDetected = hasDetectedBarcodes;
    if (currentHasDetected != _lastHasDetected) {
      _lastHasDetected = currentHasDetected;
      widget.onDetectionStateChanged?.call(hasDetectedBarcodes: currentHasDetected);
    }
  }

  // ---------------------------------------------------------------------------
  // 画像キャプチャ（内部）
  // ---------------------------------------------------------------------------

  Future<CaptureResult?> _captureStreamFrame(DetectedBarcode barcode, Size scanImageSize) async {
    final frame = _lastDetectedFrame;
    final frameSize = _lastDetectedFrameSize;
    if (frame == null || frameSize == null || !mounted) {
      return captureImageWithCamera(barcode, scanImageSize);
    }

    try {
      final jpegBytes = await compute(
        _convertFrameToJpeg,
        _FrameConvertParams(
          planes: frame.planes.map((plane) => _PlaneData(plane.bytes, plane.bytesPerRow)).toList(),
          width: frame.width,
          height: frame.height,
          format: frame.format.group,
          sensorOrientation: _cameraController?.description.sensorOrientation ?? 0,
          quality: widget.captureQuality,
        ),
      );

      if (jpegBytes == null || !mounted) {
        return captureImageWithCamera(barcode, scanImageSize);
      }

      final tempDir = await getTemporaryDirectory();
      final captureDir = Directory(p.join(tempDir.path, widget.captureSubdirectory));
      if (!captureDir.existsSync()) {
        await captureDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedCode = barcode.rawValue.replaceAll(RegExp(r'[^\w]'), '_');
      final fileName = '${timestamp}_$sanitizedCode.jpg';
      final destPath = p.join(captureDir.path, fileName);

      await File(destPath).writeAsBytes(jpegBytes);

      final codeMetadata = _createCodeMetadata(barcode, frameSize);
      return CaptureResult(imagePath: destPath, codeMetadata: codeMetadata);
    } on Exception catch (e) {
      debugPrint('Stream frame capture error: $e');
      return captureImageWithCamera(barcode, scanImageSize);
    }
  }

  /// バーコードからCodeMetadataを生成
  CodeMetadata _createCodeMetadata(DetectedBarcode barcode, Size imageSize) {
    final corners = barcode.corners;

    final codeCorners = <CodeCorner>[];
    if (corners != null && corners.length == 4) {
      for (final corner in corners) {
        codeCorners.add(CodeCorner(x: corner.x / imageSize.width, y: corner.y / imageSize.height));
      }
    } else {
      final rect = barcode.boundingBox;
      codeCorners.addAll([
        CodeCorner(x: rect.left / imageSize.width, y: rect.top / imageSize.height),
        CodeCorner(x: rect.right / imageSize.width, y: rect.top / imageSize.height),
        CodeCorner(x: rect.right / imageSize.width, y: rect.bottom / imageSize.height),
        CodeCorner(x: rect.left / imageSize.width, y: rect.bottom / imageSize.height),
      ]);
    }

    return CodeMetadata(codeCorners: codeCorners, codeType: barcode.formatName);
  }

  // ---------------------------------------------------------------------------
  // カメラ画像変換
  // ---------------------------------------------------------------------------

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation = _getInputImageRotation(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = _getInputImageFormat(image.format.group);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation? _getInputImageRotation(int sensorOrientation) {
    return switch (sensorOrientation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => null,
    };
  }

  InputImageFormat? _getInputImageFormat(ImageFormatGroup group) {
    return switch (group) {
      ImageFormatGroup.nv21 => InputImageFormat.nv21,
      ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    if (!_isInitialized || controller == null || !controller.value.isInitialized) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final overlayColor = widget.overlayStyle.cornerColor ?? theme.colorScheme.primary;
    final scanWindowBorderColor = widget.scanWindowStyle.borderColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        _widgetSize = screenSize;
        final previewSize = controller.value.previewSize;
        final isLandscape =
            controller.description.sensorOrientation == 90 ||
            controller.description.sensorOrientation == 270;
        final textureSize = previewSize == null
            ? Size.zero
            : (isLandscape ? previewSize.flipped : previewSize);

        _updateNativeScanWindowWithLayout(screenSize, textureSize);

        return Stack(
          fit: StackFit.expand,
          children: [
            // カメラプレビュー
            _CameraPreview(controller: controller, screenSize: screenSize),
            // スキャンウィンドウオーバーレイ
            if (widget.showScanWindow && widget.scanWindowMarginRatio != null)
              CustomPaint(
                size: screenSize,
                painter: _ScanWindowPainter(
                  marginRatio: widget.scanWindowMarginRatio!,
                  style: widget.scanWindowStyle,
                  borderColor: scanWindowBorderColor,
                ),
              ),
            // スムーズバーコードオーバーレイ
            if (widget.showOverlay)
              AnimatedBuilder(
                animation: _overlayController,
                builder: (context, _) {
                  final trackedBarcodes = _overlayController.trackedBarcodes;
                  if (trackedBarcodes.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return CustomPaint(
                    size: screenSize,
                    painter: _SmoothBarcodeOverlayPainter(
                      trackedBarcodes: trackedBarcodes,
                      imageSize: _imageSize,
                      screenSize: screenSize,
                      style: widget.overlayStyle,
                      color: overlayColor,
                      isFrontCamera:
                          controller.description.lensDirection == CameraLensDirection.front,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// カメラプレビュー
// =============================================================================

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller, required this.screenSize});

  final CameraController controller;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.shrink();
    }

    final isLandscape =
        controller.description.sensorOrientation == 90 ||
        controller.description.sensorOrientation == 270;
    final aspectRatio = isLandscape
        ? previewSize.height / previewSize.width
        : previewSize.width / previewSize.height;

    return ClipRect(
      child: OverflowBox(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.width / aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// スムーズオーバーレイ
// =============================================================================

/// トラッキング中のバーコード
class _TrackedBarcode {
  _TrackedBarcode({
    required this.barcode,
    required this.opacity,
    required BarcodeOverlayStyle style,
  }) : currentCorners = _normalizeCorners(
         barcode.corners?.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList() ??
             _rectToCorners(barcode.boundingBox),
       ),
       currentBoundingBox = barcode.boundingBox,
       _style = style;

  DetectedBarcode barcode;
  List<Offset> currentCorners;
  Rect currentBoundingBox;
  double opacity;
  DateTime lastSeen = DateTime.now();
  BarcodeOverlayStyle _style;

  static List<Offset> _rectToCorners(Rect rect) {
    return [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
  }

  static List<Offset> _normalizeCorners(List<Offset> corners) {
    if (corners.length != 4) return corners;

    final center = Offset(
      corners.map((c) => c.dx).reduce((a, b) => a + b) / 4,
      corners.map((c) => c.dy).reduce((a, b) => a + b) / 4,
    );

    final sorted = List<Offset>.from(corners);
    sorted.sort((a, b) {
      final angleA = (a - center).direction;
      final angleB = (b - center).direction;
      return angleA.compareTo(angleB);
    });

    var minIndex = 0;
    var minAngle = double.infinity;
    for (var i = 0; i < sorted.length; i++) {
      final angle = (sorted[i] - center).direction;
      const targetAngle = -3.14159 * 0.75;
      final diff = (angle - targetAngle).abs();
      if (diff < minAngle) {
        minAngle = diff;
        minIndex = i;
      }
    }

    return [
      sorted[minIndex],
      sorted[(minIndex + 1) % 4],
      sorted[(minIndex + 2) % 4],
      sorted[(minIndex + 3) % 4],
    ];
  }

  void updateWith(DetectedBarcode newBarcode) {
    barcode = newBarcode;
    lastSeen = DateTime.now();

    final rawCorners =
        newBarcode.corners?.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList() ??
        _rectToCorners(newBarcode.boundingBox);
    final targetCorners = _normalizeCorners(rawCorners);

    for (var i = 0; i < currentCorners.length && i < targetCorners.length; i++) {
      currentCorners[i] = Offset.lerp(currentCorners[i], targetCorners[i], _style.lerpFactor)!;
    }

    currentBoundingBox = Rect.lerp(currentBoundingBox, newBarcode.boundingBox, _style.lerpFactor)!;
  }

  bool get isExpired {
    final elapsed = DateTime.now().difference(lastSeen);
    return elapsed > _style.expirationDuration;
  }

  double get fadeProgress {
    final elapsed = DateTime.now().difference(lastSeen).inMilliseconds;
    final displayMs = _style.displayDuration.inMilliseconds;
    final fadeOutMs = _style.fadeOutDuration.inMilliseconds;
    if (elapsed < displayMs) return 1;
    final fadeElapsed = elapsed - displayMs;
    return (1 - fadeElapsed / fadeOutMs).clamp(0, 1);
  }
}

/// スムーズオーバーレイのコントローラー
class _SmoothOverlayController extends ChangeNotifier {
  _SmoothOverlayController({required TickerProvider vsync, required BarcodeOverlayStyle style})
    : _style = style {
    _ticker = vsync.createTicker(_onTick);
    _ticker.start();
  }

  late final Ticker _ticker;
  final Map<String, _TrackedBarcode> _tracked = {};
  BarcodeOverlayStyle _style;

  set style(BarcodeOverlayStyle value) {
    _style = value;
    for (final tracked in _tracked.values) {
      tracked._style = value;
    }
  }

  static const double _positionThreshold = 100;

  List<_TrackedBarcode> get trackedBarcodes => _tracked.values.toList();

  void _onTick(Duration elapsed) {
    var needsUpdate = false;

    final expiredKeys = <String>[];
    for (final entry in _tracked.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
        needsUpdate = true;
      } else if (entry.value.fadeProgress < 1.0) {
        needsUpdate = true;
      }
    }
    for (final key in expiredKeys) {
      _tracked.remove(key);
    }

    if (needsUpdate) {
      notifyListeners();
    }
  }

  Offset _getBarcodeCenter(DetectedBarcode barcode) {
    return barcode.boundingBox.center;
  }

  String? _findMatchingKey(DetectedBarcode barcode) {
    final rawValue = barcode.rawValue;
    final center = _getBarcodeCenter(barcode);

    String? bestKey;
    var bestDistance = double.infinity;

    for (final entry in _tracked.entries) {
      if (!entry.key.startsWith('$rawValue@')) continue;

      final trackedCenter = entry.value.currentBoundingBox.center;
      final distance = (center - trackedCenter).distance;

      if (distance < _positionThreshold && distance < bestDistance) {
        bestDistance = distance;
        bestKey = entry.key;
      }
    }

    return bestKey;
  }

  String _generateUniqueKey(DetectedBarcode barcode) {
    final rawValue = barcode.rawValue;
    var index = 0;
    while (_tracked.containsKey('$rawValue@$index')) {
      index++;
    }
    return '$rawValue@$index';
  }

  void updateBarcodes(List<DetectedBarcode> barcodes) {
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue.isEmpty) continue;

      final existingKey = _findMatchingKey(barcode);

      if (existingKey != null) {
        _tracked[existingKey]!.updateWith(barcode);
      } else {
        final newKey = _generateUniqueKey(barcode);
        _tracked[newKey] = _TrackedBarcode(barcode: barcode, opacity: 1, style: _style);
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// スムーズオーバーレイ用のペインター
class _SmoothBarcodeOverlayPainter extends CustomPainter {
  _SmoothBarcodeOverlayPainter({
    required this.trackedBarcodes,
    required this.imageSize,
    required this.screenSize,
    required this.style,
    required this.color,
    required this.isFrontCamera,
  });

  final List<_TrackedBarcode> trackedBarcodes;
  final Size imageSize;
  final Size screenSize;
  final BarcodeOverlayStyle style;
  final Color color;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    for (final tracked in trackedBarcodes) {
      _drawTrackedBarcode(canvas, tracked);
    }
  }

  void _drawTrackedBarcode(Canvas canvas, _TrackedBarcode tracked) {
    final opacity = tracked.fadeProgress;
    if (opacity <= 0) return;

    final rect = tracked.currentBoundingBox;
    final topLeft = _transformPoint(rect.topLeft);
    final bottomRight = _transformPoint(rect.bottomRight);
    final transformedRect = Rect.fromPoints(topLeft, bottomRight);

    _drawAppleStyleCorners(canvas, transformedRect, opacity);

    if (style.showLabel) {
      _drawBarcodeLabel(canvas, transformedRect, tracked.barcode.rawValue, opacity);
    }
  }

  void _drawAppleStyleCorners(Canvas canvas, Rect rect, double opacity) {
    final paint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.cornerStrokeWidth
      ..strokeCap = StrokeCap.round;

    final minSide = rect.width < rect.height ? rect.width : rect.height;
    final cornerLength = style.cornerLength ?? (minSide * 0.25).clamp(20.0, 40.0);
    final cornerRadius = style.cornerRadius;
    final padding = style.cornerPadding;

    final paddedRect = Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );

    // 左上
    canvas.drawPath(
      Path()
        ..moveTo(paddedRect.left, paddedRect.top + cornerLength)
        ..lineTo(paddedRect.left, paddedRect.top + cornerRadius)
        ..arcToPoint(
          Offset(paddedRect.left + cornerRadius, paddedRect.top),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(paddedRect.left + cornerLength, paddedRect.top),
      paint,
    );

    // 右上
    canvas.drawPath(
      Path()
        ..moveTo(paddedRect.right - cornerLength, paddedRect.top)
        ..lineTo(paddedRect.right - cornerRadius, paddedRect.top)
        ..arcToPoint(
          Offset(paddedRect.right, paddedRect.top + cornerRadius),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(paddedRect.right, paddedRect.top + cornerLength),
      paint,
    );

    // 右下
    canvas.drawPath(
      Path()
        ..moveTo(paddedRect.right, paddedRect.bottom - cornerLength)
        ..lineTo(paddedRect.right, paddedRect.bottom - cornerRadius)
        ..arcToPoint(
          Offset(paddedRect.right - cornerRadius, paddedRect.bottom),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(paddedRect.right - cornerLength, paddedRect.bottom),
      paint,
    );

    // 左下
    canvas.drawPath(
      Path()
        ..moveTo(paddedRect.left + cornerLength, paddedRect.bottom)
        ..lineTo(paddedRect.left + cornerRadius, paddedRect.bottom)
        ..arcToPoint(
          Offset(paddedRect.left, paddedRect.bottom - cornerRadius),
          radius: Radius.circular(cornerRadius),
        )
        ..lineTo(paddedRect.left, paddedRect.bottom - cornerLength),
      paint,
    );
  }

  void _drawBarcodeLabel(Canvas canvas, Rect rect, String rawValue, double opacity) {
    if (rawValue.isEmpty) return;

    final maxLen = style.maxLabelLength;
    final displayText = rawValue.length > maxLen ? '${rawValue.substring(0, maxLen)}...' : rawValue;

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: style.labelTextColor.withAlpha((255 * opacity).round()),
          fontSize: style.labelFontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width + 32);

    final labelWidth = textPainter.width + 12;
    final labelHeight = textPainter.height + 6;
    final labelX = rect.center.dx - labelWidth / 2;
    final labelY = rect.bottom + 12;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX, labelY, labelWidth, labelHeight),
      const Radius.circular(4),
    );
    final bgPaint = Paint()
      ..color = style.labelBackgroundColor.withValues(
        alpha: style.labelBackgroundColor.a * opacity,
      );
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(canvas, Offset(labelX + 6, labelY + 3));
  }

  Offset _transformPoint(Offset point) {
    var x = point.dx;
    final y = point.dy;

    if (isFrontCamera) {
      x = imageSize.width - x;
    }

    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final offsetX = (screenSize.width - imageSize.width * scale) / 2;
    final offsetY = (screenSize.height - imageSize.height * scale) / 2;

    return Offset(x * scale + offsetX, y * scale + offsetY);
  }

  @override
  bool shouldRepaint(covariant _SmoothBarcodeOverlayPainter oldDelegate) {
    return true; // アニメーション中は常に再描画
  }
}

// =============================================================================
// スキャンウィンドウ描画
// =============================================================================

class _ScanWindowPainter extends CustomPainter {
  _ScanWindowPainter({required this.marginRatio, required this.style, required this.borderColor});

  final double marginRatio;
  final ScanWindowStyle style;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final marginX = size.width * marginRatio;
    final marginY = size.height * marginRatio;

    final scanWindow = Rect.fromLTRB(marginX, marginY, size.width - marginX, size.height - marginY);

    // 画面全体を覆うパス
    final backgroundPath = Path()..addRect(Offset.zero & size);

    // スキャンウィンドウのカットアウト（角丸）
    final cutoutRect = RRect.fromRectAndRadius(scanWindow, Radius.circular(style.cornerRadius));
    final cutoutPath = Path()..addRRect(cutoutRect);

    // オーバーレイ描画（カットアウト部分を除く）
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    final overlayPaint = Paint()
      ..color = style.overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // 枠線を描画
    if (style.showBorder) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth
        ..strokeCap = StrokeCap.round;

      if (style.showCorners) {
        _drawCorners(canvas, scanWindow, borderPaint);
      } else {
        canvas.drawRRect(cutoutRect, borderPaint);
      }
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    final cornerLength = style.cornerLength;
    final cornerRadius = style.cornerRadius;

    // 左上
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + cornerRadius)
        ..quadraticBezierTo(left, top, left + cornerRadius, top)
        ..lineTo(left + cornerLength, top),
      paint,
    );

    // 右上
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - cornerRadius, top)
        ..quadraticBezierTo(right, top, right, top + cornerRadius)
        ..lineTo(right, top + cornerLength),
      paint,
    );

    // 右下
    canvas.drawPath(
      Path()
        ..moveTo(right, bottom - cornerLength)
        ..lineTo(right, bottom - cornerRadius)
        ..quadraticBezierTo(right, bottom, right - cornerRadius, bottom)
        ..lineTo(right - cornerLength, bottom),
      paint,
    );

    // 左下
    canvas.drawPath(
      Path()
        ..moveTo(left + cornerLength, bottom)
        ..lineTo(left + cornerRadius, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - cornerRadius)
        ..lineTo(left, bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) {
    return marginRatio != oldDelegate.marginRatio ||
        borderColor != oldDelegate.borderColor ||
        style != oldDelegate.style;
  }
}

// =============================================================================
// ストリームフレーム変換用ヘルパー（Isolate対応）
// =============================================================================

class _FrameConvertParams {
  const _FrameConvertParams({
    required this.planes,
    required this.width,
    required this.height,
    required this.format,
    required this.sensorOrientation,
    this.quality = 80,
  });

  final List<_PlaneData> planes;
  final int width;
  final int height;
  final ImageFormatGroup format;
  final int sensorOrientation;
  final int quality;
}

class _PlaneData {
  const _PlaneData(this.bytes, this.bytesPerRow);

  final Uint8List bytes;
  final int bytesPerRow;
}

Uint8List? _convertFrameToJpeg(_FrameConvertParams params) {
  try {
    img.Image? image;

    if (params.format == ImageFormatGroup.yuv420) {
      image = _convertYuv420ToImage(params);
    } else if (params.format == ImageFormatGroup.bgra8888) {
      image = _convertBgra8888ToImage(params);
    } else if (params.format == ImageFormatGroup.nv21) {
      image = _convertNv21ToImage(params);
    }

    if (image == null) return null;

    if (params.sensorOrientation == 90) {
      image = img.copyRotate(image, angle: 90);
    } else if (params.sensorOrientation == 180) {
      image = img.copyRotate(image, angle: 180);
    } else if (params.sensorOrientation == 270) {
      image = img.copyRotate(image, angle: 270);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
  } on Object {
    return null;
  }
}

img.Image? _convertYuv420ToImage(_FrameConvertParams params) {
  try {
    final yPlane = params.planes[0];
    final uPlane = params.planes[1];
    final vPlane = params.planes[2];

    final image = img.Image(width: params.width, height: params.height);

    for (var y = 0; y < params.height; y++) {
      for (var x = 0; x < params.width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final yValue = yPlane.bytes[yIndex];
        final uValue = uPlane.bytes[uvIndex];
        final vValue = vPlane.bytes[uvIndex];

        final rgb = _yuvToRgb(yValue, uValue, vValue);
        image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  } on Object {
    return null;
  }
}

img.Image? _convertNv21ToImage(_FrameConvertParams params) {
  try {
    final yPlane = params.planes[0];
    final width = params.width;
    final height = params.height;

    final image = img.Image(width: width, height: height);

    final int uvOffset;
    final Uint8List uvBytes;
    final int uvBytesPerRow;

    if (params.planes.length >= 2) {
      uvBytes = params.planes[1].bytes;
      uvBytesPerRow = params.planes[1].bytesPerRow;
      uvOffset = 0;
    } else {
      uvBytes = yPlane.bytes;
      uvBytesPerRow = yPlane.bytesPerRow;
      uvOffset = height * yPlane.bytesPerRow;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = uvOffset + (y ~/ 2) * uvBytesPerRow + (x ~/ 2) * 2;

        if (yIndex >= yPlane.bytes.length || uvIndex + 1 >= uvBytes.length) {
          continue;
        }

        final yValue = yPlane.bytes[yIndex];
        final vValue = uvBytes[uvIndex];
        final uValue = uvBytes[uvIndex + 1];

        final rgb = _yuvToRgb(yValue, uValue, vValue);
        image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  } on Object {
    return null;
  }
}

img.Image? _convertBgra8888ToImage(_FrameConvertParams params) {
  try {
    final plane = params.planes[0];
    final image = img.Image(width: params.width, height: params.height);

    for (var y = 0; y < params.height; y++) {
      for (var x = 0; x < params.width; x++) {
        final index = y * plane.bytesPerRow + x * 4;
        final b = plane.bytes[index];
        final g = plane.bytes[index + 1];
        final r = plane.bytes[index + 2];
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  } on Object {
    return null;
  }
}

List<int> _yuvToRgb(int y, int u, int v) {
  final yValue = y.toDouble();
  final uValue = u.toDouble() - 128;
  final vValue = v.toDouble() - 128;

  final r = (yValue + 1.402 * vValue).round().clamp(0, 255);
  final g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
  final b = (yValue + 1.772 * uValue).round().clamp(0, 255);

  return [r, g, b];
}
