import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// コード検出位置のコーナー座標（正規化済み）
///
/// 座標は画像サイズに対する比率（0.0〜1.0）で保存される。
/// 表示時に [toOffset] で実座標に変換する。
@immutable
class CodeCorner {
  /// コンストラクタ
  const CodeCorner({required this.x, required this.y});

  /// JSONからCodeCornerを生成
  factory CodeCorner.fromJson(Map<String, dynamic> json) {
    return CodeCorner(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  /// 正規化されたX座標（0.0〜1.0）
  final double x;

  /// 正規化されたY座標（0.0〜1.0）
  final double y;

  /// JSONへ変換
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  /// 表示サイズに変換して[Offset]を返す
  Offset toOffset(Size displaySize) {
    return Offset(x * displaySize.width, y * displaySize.height);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeCorner &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CodeCorner($x, $y)';
}

/// コード検出メタデータ
///
/// バーコード/QRコードの検出位置情報を保持する。
/// 画像上にオーバーレイを描画するために使用。
///
/// 座標は正規化されており、画像サイズに依存しない。
@immutable
class CodeMetadata {
  /// コンストラクタ
  const CodeMetadata({required this.codeCorners, required this.codeType});

  /// JSON文字列からCodeMetadataを生成
  factory CodeMetadata.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return CodeMetadata.fromJson(json);
  }

  /// JSONマップからCodeMetadataを生成
  factory CodeMetadata.fromJson(Map<String, dynamic> json) {
    final cornersJson = json['codeCorners'] as List<dynamic>;
    return CodeMetadata(
      codeCorners: cornersJson
          .map((c) => CodeCorner.fromJson(c as Map<String, dynamic>))
          .toList(),
      codeType: json['codeType'] as String,
    );
  }

  /// コード検出位置の4コーナー（左上→右上→右下→左下の順、正規化座標）
  final List<CodeCorner> codeCorners;

  /// コードタイプ（qrCode, ean13, code128など）
  final String codeType;

  /// 4コーナーが有効か（4点あるか）
  bool get hasValidCorners => codeCorners.length == 4;

  /// JSONマップへ変換
  Map<String, dynamic> toJson() {
    return {
      'codeCorners': codeCorners.map((c) => c.toJson()).toList(),
      'codeType': codeType,
    };
  }

  /// JSON文字列へ変換（DB保存用）
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeMetadata &&
          runtimeType == other.runtimeType &&
          listEquals(codeCorners, other.codeCorners) &&
          codeType == other.codeType;

  @override
  int get hashCode => Object.hash(Object.hashAll(codeCorners), codeType);

  @override
  String toString() => 'CodeMetadata($codeType, $codeCorners)';
}

/// 画像キャプチャの結果を保持するクラス
///
/// バーコード検出時にキャプチャした画像パスと、
/// 検出コードの位置情報（メタデータ）を含む。
@immutable
class CaptureResult {
  /// コンストラクタ
  const CaptureResult({required this.imagePath, required this.codeMetadata});

  /// キャプチャした画像のファイルパス
  final String imagePath;

  /// 検出コードのメタデータ（位置情報を含む）
  final CodeMetadata codeMetadata;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureResult &&
          runtimeType == other.runtimeType &&
          imagePath == other.imagePath &&
          codeMetadata == other.codeMetadata;

  @override
  int get hashCode => Object.hash(imagePath, codeMetadata);

  @override
  String toString() => 'CaptureResult($imagePath, $codeMetadata)';
}
