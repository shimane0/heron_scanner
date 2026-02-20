import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    show BarcodeFormat;

// BarcodeFormat をライブラリ利用側に再エクスポートする
export 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    show BarcodeFormat;

/// スキャナーが検出したバーコード情報
///
/// ML Kitの検出結果を抽象化し、ライブラリ利用側に
/// google_mlkit_barcode_scanningへの直接依存を要求しない。
@immutable
class DetectedBarcode {
  /// コンストラクタ
  const DetectedBarcode({
    required this.rawValue,
    required this.format,
    required this.boundingBox,
    this.corners,
  });

  /// バーコードの値（デコード文字列）
  final String rawValue;

  /// バーコードフォーマット（EAN-13, QR Code等）
  final BarcodeFormat format;

  /// 境界ボックス（画像座標系、ピクセル単位）
  final Rect boundingBox;

  /// コーナーポイント（4点、画像座標系）
  ///
  /// ML Kitが返すcornerPointsに対応。
  /// nullの場合は[boundingBox]から矩形コーナーが生成される。
  final List<Point<int>>? corners;

  /// フォーマットの表示名を返す
  String get formatName => switch (format) {
    BarcodeFormat.aztec => 'Aztec',
    BarcodeFormat.codabar => 'Codabar',
    BarcodeFormat.code39 => 'Code 39',
    BarcodeFormat.code93 => 'Code 93',
    BarcodeFormat.code128 => 'Code 128',
    BarcodeFormat.dataMatrix => 'Data Matrix',
    BarcodeFormat.ean8 => 'EAN-8',
    BarcodeFormat.ean13 => 'EAN-13',
    BarcodeFormat.itf => 'ITF',
    BarcodeFormat.pdf417 => 'PDF417',
    BarcodeFormat.qrCode => 'QR Code',
    BarcodeFormat.upca => 'UPC-A',
    BarcodeFormat.upce => 'UPC-E',
    _ => 'Unknown',
  };

  @override
  String toString() => 'DetectedBarcode($rawValue, $formatName)';
}
