import Flutter
import UIKit

/// heron_scanner Flutterプラグインのネイティブ（iOS）実装
///
/// Pigeon生成の `ScanWindowHostApi` プロトコルを実装し、
/// バーコードのスキャンウィンドウフィルタリングをネイティブ側で高速に処理する。
public class HeronScannerPlugin: NSObject, FlutterPlugin, ScanWindowHostApi {

    /// スキャンウィンドウ（正規化座標: left, top, right, bottom）
    private var scanWindow: ScanWindowRect?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HeronScannerPlugin()
        ScanWindowHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: instance
        )
    }

    // =========================================================================
    // ScanWindowHostApi 実装
    // =========================================================================

    func updateScanWindow(rect: ScanWindowRect?) throws {
        scanWindow = rect
    }

    func isBarcodeInScanWindow(
        boundingBox: BarcodeBoundingBox,
        imageSize: ImageDimensions
    ) throws -> Bool {
        guard let window = scanWindow else {
            return true
        }

        // iOS では cameraパッケージが回転補正済みのサイズを返すため、
        // そのまま width/height として使用する
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height

        guard imageWidth > 0, imageHeight > 0 else {
            return true
        }

        // スキャンウィンドウをピクセル座標に変換
        let windowLeft = window.left * imageWidth
        let windowTop = window.top * imageHeight
        let windowRight = window.right * imageWidth
        let windowBottom = window.bottom * imageHeight

        // バーコード全体がスキャンウィンドウに含まれるかチェック
        return boundingBox.left >= windowLeft &&
               boundingBox.top >= windowTop &&
               boundingBox.right <= windowRight &&
               boundingBox.bottom <= windowBottom
    }

    func filterBarcodes(
        boundingBoxes: [BarcodeBoundingBox],
        imageSize: ImageDimensions
    ) throws -> FilterResult {
        guard scanWindow != nil else {
            return FilterResult(indices: Array(0..<Int64(boundingBoxes.count)).map { $0 })
        }

        let indices: [Int64] = boundingBoxes.enumerated().compactMap { index, box in
            let isInWindow = (try? isBarcodeInScanWindow(
                boundingBox: box,
                imageSize: imageSize
            )) ?? true
            return isInWindow ? Int64(index) : nil
        }

        return FilterResult(indices: indices)
    }
}
