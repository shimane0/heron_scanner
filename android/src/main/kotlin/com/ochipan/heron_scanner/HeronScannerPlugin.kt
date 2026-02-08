package com.ochipan.heron_scanner

import android.graphics.Rect
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlin.math.roundToInt

/// heron_scanner Flutterプラグインのネイティブ（Android）実装
///
/// Pigeon生成の [ScanWindowHostApi] を実装し、
/// バーコードのスキャンウィンドウフィルタリングをネイティブ側で高速に処理する。
class HeronScannerPlugin : FlutterPlugin, ScanWindowHostApi {

    /// スキャンウィンドウ（正規化座標: left, top, right, bottom）
    private var scanWindow: ScanWindowRect? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ScanWindowHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ScanWindowHostApi.setUp(binding.binaryMessenger, null)
    }

    // =========================================================================
    // ScanWindowHostApi 実装
    // =========================================================================

    override fun updateScanWindow(rect: ScanWindowRect?) {
        scanWindow = rect
    }

    override fun isBarcodeInScanWindow(
        boundingBox: BarcodeBoundingBox,
        imageSize: ImageDimensions
    ): Boolean {
        val window = scanWindow ?: return true

        // mobile_scannerと同じ座標変換:
        // Android では inputImage.height が実質的な画像幅になる
        // Dartからのrawサイズを [width, height] で受け取り、
        // imageWidth = height, imageHeight = width として処理する
        val imageWidth = imageSize.height
        val imageHeight = imageSize.width

        if (imageWidth <= 0 || imageHeight <= 0) return true

        // スキャンウィンドウをピクセル座標に変換
        val left = (window.left * imageWidth).roundToInt()
        val top = (window.top * imageHeight).roundToInt()
        val right = (window.right * imageWidth).roundToInt()
        val bottom = (window.bottom * imageHeight).roundToInt()

        val scaledScanWindow = Rect(left, top, right, bottom)

        // バーコードの境界ボックス
        val barcodeRect = Rect(
            boundingBox.left.roundToInt(),
            boundingBox.top.roundToInt(),
            boundingBox.right.roundToInt(),
            boundingBox.bottom.roundToInt()
        )

        return scaledScanWindow.contains(barcodeRect)
    }

    override fun filterBarcodes(
        boundingBoxes: List<BarcodeBoundingBox>,
        imageSize: ImageDimensions
    ): FilterResult {
        if (scanWindow == null) {
            return FilterResult(indices = boundingBoxes.indices.map { it.toLong() })
        }

        val indices = boundingBoxes.indices.filter { index ->
            isBarcodeInScanWindow(boundingBoxes[index], imageSize)
        }.map { it.toLong() }

        return FilterResult(indices = indices)
    }
}
