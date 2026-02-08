import 'package:flutter/material.dart';

/// スキャンウィンドウの表示スタイル
///
/// スキャナーWidget上に描画されるスキャンウィンドウ（読み取りエリア）の
/// 外観をカスタマイズするための設定クラス。
@immutable
class ScanWindowStyle {
  /// コンストラクタ
  const ScanWindowStyle({
    this.overlayColor = const Color(0x80000000),
    this.borderColor,
    this.borderWidth = 2.0,
    this.cornerRadius = 12.0,
    this.cornerLength = 24.0,
    this.cornerStrokeWidth = 3.0,
    this.showBorder = true,
    this.showCorners = true,
  });

  /// スキャンウィンドウ外のオーバーレイ色
  final Color overlayColor;

  /// スキャンウィンドウ枠の色（nullの場合はテーマのprimary色）
  final Color? borderColor;

  /// スキャンウィンドウ枠の線幅
  final double borderWidth;

  /// スキャンウィンドウの角丸半径
  final double cornerRadius;

  /// コーナー装飾の長さ
  final double cornerLength;

  /// コーナー装飾の線幅
  final double cornerStrokeWidth;

  /// 枠線を表示するか
  final bool showBorder;

  /// コーナー装飾を表示するか
  final bool showCorners;

  /// デフォルトスタイル
  static const ScanWindowStyle defaults = ScanWindowStyle();

  /// スタイルをコピーして新しいインスタンスを作成
  ScanWindowStyle copyWith({
    Color? overlayColor,
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
    double? cornerLength,
    double? cornerStrokeWidth,
    bool? showBorder,
    bool? showCorners,
  }) {
    return ScanWindowStyle(
      overlayColor: overlayColor ?? this.overlayColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      cornerLength: cornerLength ?? this.cornerLength,
      cornerStrokeWidth: cornerStrokeWidth ?? this.cornerStrokeWidth,
      showBorder: showBorder ?? this.showBorder,
      showCorners: showCorners ?? this.showCorners,
    );
  }
}
