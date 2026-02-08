import 'package:flutter/material.dart';

/// バーコードオーバーレイの表示スタイル
///
/// スキャナーWidget上に描画されるバーコード検出オーバーレイの
/// 外観をカスタマイズするための設定クラス。
@immutable
class BarcodeOverlayStyle {
  /// コンストラクタ
  const BarcodeOverlayStyle({
    this.cornerColor,
    this.cornerStrokeWidth = 2.0,
    this.cornerLength,
    this.cornerRadius = 8.0,
    this.cornerPadding = 8.0,
    this.showLabel = true,
    this.labelFontSize = 12.0,
    this.labelBackgroundColor = const Color(0xB4000000),
    this.labelTextColor = Colors.white,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.displayDuration = const Duration(milliseconds: 200),
    this.maxLabelLength = 20,
    this.lerpFactor = 0.3,
    this.expirationDuration = const Duration(milliseconds: 500),
  });

  /// コーナーブラケットの色（nullの場合はテーマのprimary色）
  final Color? cornerColor;

  /// コーナーブラケットの線幅
  final double cornerStrokeWidth;

  /// コーナーブラケットの長さ（nullの場合は短辺の25%、20〜40px）
  final double? cornerLength;

  /// コーナーの角丸半径
  final double cornerRadius;

  /// コーナーブラケットとバーコードの間のパディング
  final double cornerPadding;

  /// バーコード値のラベルを表示するか
  final bool showLabel;

  /// ラベルのフォントサイズ
  final double labelFontSize;

  /// ラベル背景色
  final Color labelBackgroundColor;

  /// ラベル文字色
  final Color labelTextColor;

  /// 表示時間（この時間は完全に表示）
  final Duration displayDuration;

  /// フェードイン時間（現在は即時表示のため未使用、将来拡張用）
  final Duration fadeInDuration;

  /// フェードアウト時間
  final Duration fadeOutDuration;

  /// ラベルの最大文字数（超過分は省略表示）
  final int maxLabelLength;

  /// 位置補間の係数（0.0〜1.0、大きいほど追従が速い）
  final double lerpFactor;

  /// バーコードが消えてから削除されるまでの時間
  final Duration expirationDuration;

  /// デフォルトスタイル
  static const BarcodeOverlayStyle defaults = BarcodeOverlayStyle();

  /// スタイルをコピーして新しいインスタンスを作成
  BarcodeOverlayStyle copyWith({
    Color? cornerColor,
    double? cornerStrokeWidth,
    double? cornerLength,
    double? cornerRadius,
    double? cornerPadding,
    bool? showLabel,
    double? labelFontSize,
    Color? labelBackgroundColor,
    Color? labelTextColor,
    Duration? fadeInDuration,
    Duration? fadeOutDuration,
    Duration? displayDuration,
    int? maxLabelLength,
    double? lerpFactor,
    Duration? expirationDuration,
  }) {
    return BarcodeOverlayStyle(
      cornerColor: cornerColor ?? this.cornerColor,
      cornerStrokeWidth: cornerStrokeWidth ?? this.cornerStrokeWidth,
      cornerLength: cornerLength ?? this.cornerLength,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      cornerPadding: cornerPadding ?? this.cornerPadding,
      showLabel: showLabel ?? this.showLabel,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelBackgroundColor: labelBackgroundColor ?? this.labelBackgroundColor,
      labelTextColor: labelTextColor ?? this.labelTextColor,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
      displayDuration: displayDuration ?? this.displayDuration,
      maxLabelLength: maxLabelLength ?? this.maxLabelLength,
      lerpFactor: lerpFactor ?? this.lerpFactor,
      expirationDuration: expirationDuration ?? this.expirationDuration,
    );
  }
}
