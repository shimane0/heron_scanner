import 'package:flutter/foundation.dart';

import '../generated/scan_window_api.g.dart';

/// Pigeon APIを利用したスキャンウィンドウサービス
///
/// ネイティブ側（Android/iOS）にスキャンウィンドウ情報を送信し、
/// バーコードのフィルタリングをネイティブ側で高速に行う。
class ScanWindowService {
  /// シングルトン
  ScanWindowService._();

  static final _api = ScanWindowHostApi();

  /// スキャンウィンドウを更新
  ///
  /// [rect] 正規化座標（0.0〜1.0）のスキャンウィンドウ。
  ///        nullを渡すとスキャンウィンドウを無効化（全画面スキャン）。
  static Future<void> updateScanWindow(ScanWindowRect? rect) async {
    try {
      await _api.updateScanWindow(rect);
    } on Exception catch (e) {
      debugPrint('ScanWindowService.updateScanWindow error: $e');
    }
  }

  /// バーコードがスキャンウィンドウ内にあるか判定
  ///
  /// [boundingBox] バーコードのバウンディングボックス（ピクセル座標）
  /// [imageDimensions] 画像の幅と高さ
  /// Returns: スキャンウィンドウ内にある場合true
  static Future<bool> isBarcodeInScanWindow(
    BarcodeBoundingBox boundingBox,
    ImageDimensions imageDimensions,
  ) async {
    try {
      return await _api.isBarcodeInScanWindow(boundingBox, imageDimensions);
    } on Exception catch (e) {
      debugPrint('ScanWindowService.isBarcodeInScanWindow error: $e');
      return true; // エラー時はフィルタリングしない
    }
  }

  /// 複数バーコードを一括フィルタリング
  ///
  /// [boundingBoxes] バーコードのバウンディングボックスリスト
  /// [imageDimensions] 画像の幅と高さ
  /// Returns: スキャンウィンドウ内のバーコードのインデックスリスト
  static Future<List<int>> filterBarcodes(
    List<BarcodeBoundingBox> boundingBoxes,
    ImageDimensions imageDimensions,
  ) async {
    try {
      final result = await _api.filterBarcodes(boundingBoxes, imageDimensions);
      return result.indices;
    } on Exception catch (e) {
      debugPrint('ScanWindowService.filterBarcodes error: $e');
      // エラー時は全てのインデックスを返す
      return List.generate(boundingBoxes.length, (i) => i);
    }
  }

  /// [left, top, right, bottom]リストからScanWindowRectを生成
  ///
  /// 便利メソッド。旧APIからの移行用。
  static ScanWindowRect rectFromList(List<double> values) {
    assert(values.length == 4, 'values must have 4 elements');
    return ScanWindowRect(
      left: values[0],
      top: values[1],
      right: values[2],
      bottom: values[3],
    );
  }
}
