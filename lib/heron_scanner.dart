/// heron_scanner — camera + ML Kit バーコードスキャナーライブラリ
///
/// [HeronBarcodeScanner] Widgetを中心に、バーコード/QRコードのスキャン、
/// スムーズオーバーレイ描画、スキャンウィンドウフィルタリング、
/// 画像キャプチャ機能を提供する。
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
/// ## オーバーレイのカスタマイズ
///
/// ```dart
/// HeronBarcodeScanner(
///   onDetect: (barcodes, imageSize) { /* ... */ },
///   overlayStyle: BarcodeOverlayStyle(
///     cornerColor: Colors.green,
///     cornerStrokeWidth: 3.0,
///     showLabel: true,
///   ),
/// )
/// ```
///
/// ## スキャンウィンドウの設定
///
/// ```dart
/// HeronBarcodeScanner(
///   onDetect: (barcodes, imageSize) { /* ... */ },
///   scanWindowMarginRatio: 0.15, // 余白15%
/// )
/// ```
library;

// モデル
export 'src/models/detected_barcode.dart';
export 'src/models/capture_result.dart';
export 'src/models/barcode_overlay_style.dart';
export 'src/models/scan_window_style.dart';

// Widget
export 'src/scanner/heron_barcode_scanner.dart';

// サービス
export 'src/services/scan_window_service.dart';

// Pigeon生成API（上級利用者向け）
export 'src/generated/scan_window_api.g.dart'
    show ScanWindowHostApi, ScanWindowRect, BarcodeBoundingBox, ImageDimensions, FilterResult;
