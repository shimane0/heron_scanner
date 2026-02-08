import 'package:pigeon/pigeon.dart';

/// Pigeon設定
///
/// コード生成コマンド:
/// ```bash
/// cd heron_scanner
/// dart run pigeon --input pigeons/scan_window_api.dart
/// ```
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/scan_window_api.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/ochipan/heron_scanner/ScanWindowApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.ochipan.heron_scanner'),
    swiftOut: 'ios/Classes/ScanWindowApi.g.swift',
    dartPackageName: 'heron_scanner',
  ),
)
/// スキャンウィンドウの矩形情報（正規化座標 0.0〜1.0）
class ScanWindowRect {
  ScanWindowRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// 左端（0.0〜1.0）
  final double left;

  /// 上端（0.0〜1.0）
  final double top;

  /// 右端（0.0〜1.0）
  final double right;

  /// 下端（0.0〜1.0）
  final double bottom;
}

/// バーコードの境界ボックス（ピクセル座標）
class BarcodeBoundingBox {
  BarcodeBoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// 画像サイズ
class ImageDimensions {
  ImageDimensions({required this.width, required this.height});

  final double width;
  final double height;
}

/// バーコードフィルタリング結果
class FilterResult {
  FilterResult({required this.indices});

  /// フィルタリング後のインデックスリスト
  final List<int> indices;
}

/// ネイティブ側で実装するスキャンウィンドウAPI
///
/// Dart→ネイティブの呼び出し。
/// バーコードのスキャン領域フィルタリングをネイティブ側で高速に処理する。
@HostApi()
abstract class ScanWindowHostApi {
  /// スキャンウィンドウを更新する
  ///
  /// [rect] がnullの場合、スキャンウィンドウを無効化（全画面スキャン）
  void updateScanWindow(ScanWindowRect? rect);

  /// バーコードがスキャンウィンドウ内にあるかチェック
  ///
  /// [boundingBox] バーコードの境界ボックス（ピクセル座標）
  /// [imageSize] 画像サイズ（センサーのrawサイズ）
  /// スキャンウィンドウ未設定時はtrueを返す
  bool isBarcodeInScanWindow(BarcodeBoundingBox boundingBox, ImageDimensions imageSize);

  /// バーコードリストをスキャンウィンドウでフィルタリング
  ///
  /// [boundingBoxes] 各バーコードの境界ボックスリスト
  /// [imageSize] 画像サイズ
  /// スキャンウィンドウ内のバーコードのインデックスリストを返す
  FilterResult filterBarcodes(List<BarcodeBoundingBox> boundingBoxes, ImageDimensions imageSize);
}
