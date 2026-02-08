# heron_scanner

**camera + Google ML Kit** を統合した、高パフォーマンスなFlutter バーコード/QRコードスキャナー Widget。

リアルタイム検出、スムーズなオーバーレイアニメーション、スキャンウィンドウによる領域フィルタリング、画像キャプチャ機能を備え、カスタマイズ可能なAPIで他のFlutterアプリに簡単に組み込めます。

## 特徴

- **リアルタイムスキャン** — カメラストリームからフレームごとにバーコード/QRコードを検出
- **スムーズオーバーレイ** — 検出されたバーコードに追従するAppleスタイルのコーナーブラケットとラベル、フェードイン/フェードアウトアニメーション
- **スキャンウィンドウ** — 画面上の任意領域に検出範囲を限定し、ネイティブ側で高速フィルタリング
- **Pigeon ベースのプラットフォーム通信** — 型安全なネイティブAPI（Android Kotlin / iOS Swift）によるスキャンウィンドウ計算
- **画像キャプチャ** — ストリームフレームまたはカメラ撮影による画像保存、検出メタデータ付き
- **高いカスタマイズ性** — オーバーレイスタイル、スキャンウィンドウスタイル、対象フォーマット、カメラ解像度などをすべてパラメータで制御
- **Android / iOS 対応** — 両プラットフォームのネイティブプラグインを同梱

## 対応フォーマット

EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, Codabar, ITF, QR Code, Data Matrix, Aztec, PDF417

## インストール

### pubspec.yaml

```yaml
dependencies:
  heron_scanner:
    path: heron_scanner  # ローカルパッケージとして配置する場合
```

> **git 参照を使う場合:**
> ```yaml
> dependencies:
>   heron_scanner:
>     git:
>       url: git@github.com:shimane0/heron_scanner.git
>       ref: main
> ```

### プラットフォーム設定

#### Android

`android/app/build.gradle.kts` で `minSdk` を **21 以上** に設定してください。

`android/settings.gradle.kts` に `com.android.library` プラグインが宣言されていることを確認してください:

```kotlin
plugins {
    id("com.android.application") version "8.x.x" apply false
    id("com.android.library") version "8.x.x" apply false  // 必須
    id("org.jetbrains.kotlin.android") version "x.x.x" apply false
}
```

カメラの権限を `AndroidManifest.xml` に追加:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

#### iOS

`ios/Runner/Info.plist` にカメラ使用理由を追加:

```xml
<key>NSCameraUsageDescription</key>
<string>バーコード/QRコードをスキャンするためにカメラを使用します</string>
```

`Podfile` の最小バージョンを **iOS 12.0 以上** に設定してください。

## 基本的な使い方

### シンプルなスキャン

```dart
import 'package:heron_scanner/heron_scanner.dart';

class ScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeronBarcodeScanner(
        onDetect: (barcodes, imageSize) {
          for (final barcode in barcodes) {
            print('検出: ${barcode.rawValue} (${barcode.formatName})');
          }
        },
      ),
    );
  }
}
```

### GlobalKey で操作する

`HeronBarcodeScannerState` に `GlobalKey` でアクセスし、トーチ切替やスキャン制御を行えます。

```dart
class ScanPage extends StatefulWidget {
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _scannerKey = GlobalKey<HeronBarcodeScannerState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          HeronBarcodeScanner(
            key: _scannerKey,
            onDetect: (barcodes, imageSize) {
              // バーコード検出処理
            },
          ),
          // コントロールボタン
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              children: [
                // トーチ切替
                IconButton(
                  icon: const Icon(Icons.flash_on),
                  onPressed: () => _scannerKey.currentState?.toggleTorch(),
                ),
                // カメラ切替
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: () => _scannerKey.currentState?.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## カスタマイズ

### オーバーレイスタイル

検出バーコードに表示されるコーナーブラケットとラベルの外観を `BarcodeOverlayStyle` で制御します。

```dart
HeronBarcodeScanner(
  onDetect: (barcodes, imageSize) { /* ... */ },
  overlayStyle: BarcodeOverlayStyle(
    cornerColor: Colors.green,          // コーナーブラケットの色
    cornerStrokeWidth: 3.0,             // コーナーの線幅
    cornerLength: 30.0,                 // コーナーの長さ
    cornerRadius: 10.0,                 // コーナーの角丸
    cornerPadding: 10.0,               // バーコードとの間隔
    showLabel: true,                    // ラベル表示
    labelFontSize: 14.0,               // ラベルフォントサイズ
    labelBackgroundColor: Colors.black87, // ラベル背景色
    labelTextColor: Colors.white,       // ラベル文字色
    maxLabelLength: 25,                 // ラベル最大文字数
    lerpFactor: 0.3,                    // 位置追従の速さ(0.0〜1.0)
    fadeOutDuration: Duration(milliseconds: 300),   // フェードアウト時間
    expirationDuration: Duration(milliseconds: 500), // 消去までの時間
  ),
)
```

| パラメータ | 型 | デフォルト | 説明 |
|---|---|---|---|
| `cornerColor` | `Color?` | テーマのprimary色 | コーナーブラケットの色 |
| `cornerStrokeWidth` | `double` | `2.0` | コーナーの線幅 |
| `cornerLength` | `double?` | 短辺の25%(20〜40px) | コーナーの長さ |
| `cornerRadius` | `double` | `8.0` | コーナーの角丸半径 |
| `cornerPadding` | `double` | `8.0` | バーコードとの間隔 |
| `showLabel` | `bool` | `true` | ラベル表示の有無 |
| `labelFontSize` | `double` | `12.0` | ラベルフォントサイズ |
| `labelBackgroundColor` | `Color` | `Color(0xB4000000)` | ラベル背景色 |
| `labelTextColor` | `Color` | `Colors.white` | ラベル文字色 |
| `maxLabelLength` | `int` | `20` | ラベル最大文字数 |
| `lerpFactor` | `double` | `0.3` | 位置補間の速さ |
| `fadeOutDuration` | `Duration` | `300ms` | フェードアウト時間 |
| `displayDuration` | `Duration` | `200ms` | 完全表示時間 |
| `expirationDuration` | `Duration` | `500ms` | 消去までの猶予時間 |

### スキャンウィンドウスタイル

画面上のスキャン範囲を示すガイドの外観を `ScanWindowStyle` で制御します。

```dart
HeronBarcodeScanner(
  onDetect: (barcodes, imageSize) { /* ... */ },
  scanWindowMarginRatio: 0.15,          // 画面端から15%の余白
  showScanWindow: true,                 // ガイド表示
  scanWindowStyle: ScanWindowStyle(
    overlayColor: Color(0x80000000),     // ウィンドウ外の暗転色
    borderColor: Colors.blue,           // 枠線の色
    borderWidth: 2.0,                   // 枠線の太さ
    cornerRadius: 16.0,                 // 角丸半径
    cornerLength: 28.0,                 // コーナー装飾の長さ
    cornerStrokeWidth: 4.0,             // コーナー装飾の太さ
    showBorder: true,                   // 枠線表示
    showCorners: true,                  // コーナー装飾表示
  ),
)
```

| パラメータ | 型 | デフォルト | 説明 |
|---|---|---|---|
| `overlayColor` | `Color` | `Color(0x80000000)` | ウィンドウ外のオーバーレイ色 |
| `borderColor` | `Color?` | テーマのprimary色 | 枠線の色 |
| `borderWidth` | `double` | `2.0` | 枠線の太さ |
| `cornerRadius` | `double` | `12.0` | 角丸半径 |
| `cornerLength` | `double` | `24.0` | コーナー装飾の長さ |
| `cornerStrokeWidth` | `double` | `3.0` | コーナー装飾の太さ |
| `showBorder` | `bool` | `true` | 枠線表示の有無 |
| `showCorners` | `bool` | `true` | コーナー装飾表示の有無 |

### 対象フォーマットの指定

```dart
HeronBarcodeScanner(
  formats: [BarcodeFormat.qrCode, BarcodeFormat.ean13],
  onDetect: (barcodes, imageSize) { /* ... */ },
)
```

### 自動停止

一定時間バーコードが検出されない場合に自動的にスキャンを停止できます。

```dart
HeronBarcodeScanner(
  autoStopDuration: Duration(seconds: 30),
  onAutoStopped: () {
    print('スキャンが自動停止されました');
  },
  onDetect: (barcodes, imageSize) { /* ... */ },
)
```

## 画像キャプチャ

検出されたバーコード付きの画像をキャプチャし、メタデータと共に保存できます。

```dart
final scannerKey = GlobalKey<HeronBarcodeScannerState>();

// ストリームフレームからキャプチャ（座標完全一致、標準画質）
final result = await scannerKey.currentState?.captureImage(
  barcode,
  imageSize,
  useStreamFrame: true,
);

// カメラ撮影によるキャプチャ（高画質、座標ずれの可能性あり）
final result = await scannerKey.currentState?.captureImage(
  barcode,
  imageSize,
  useStreamFrame: false,
);

if (result != null) {
  print('保存先: ${result.imagePath}');
  print('コードタイプ: ${result.codeMetadata.codeType}');
  print('コーナー座標: ${result.codeMetadata.codeCorners}');
}
```

### CaptureResult

| プロパティ | 型 | 説明 |
|---|---|---|
| `imagePath` | `String` | 保存された画像ファイルのパス |
| `codeMetadata` | `CodeMetadata` | バーコード検出位置のメタデータ |

### CodeMetadata

| プロパティ | 型 | 説明 |
|---|---|---|
| `codeCorners` | `List<CodeCorner>` | 正規化された4コーナー座標(0.0〜1.0) |
| `codeType` | `String` | コードタイプ文字列 |

一時的にキャプチャされた画像は以下でクリアできます:

```dart
// インスタンスメソッド
await scannerKey.currentState?.clearCapturedImages();

// static メソッド（Widget外から呼び出し可能）
await HeronBarcodeScannerState.clearImages();
```

## 公開メソッド一覧

`GlobalKey<HeronBarcodeScannerState>` を通じて以下のメソッドにアクセスできます:

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `toggleTorch()` | `Future<void>` | トーチ（フラッシュライト）のON/OFF切替 |
| `switchCamera()` | `Future<void>` | フロント/バックカメラの切替 |
| `pauseScanning()` | `Future<void>` | スキャンを一時停止（カメラ解放） |
| `resumeScanning()` | `Future<void>` | スキャンを再開（カメラ再初期化） |
| `captureImage(...)` | `Future<CaptureResult?>` | 画像キャプチャ |
| `captureImageWithCamera(...)` | `Future<CaptureResult?>` | カメラ撮影による高画質キャプチャ |
| `startImageCapture()` | `void` | キャプチャモード開始 |
| `stopImageCapture()` | `void` | キャプチャモード終了 |
| `clearCapturedImages()` | `Future<void>` | 一時画像のクリア |

### 公開プロパティ

| プロパティ | 型 | 説明 |
|---|---|---|
| `torchEnabled` | `bool` | トーチがONか |
| `isInitialized` | `bool` | カメラが初期化済みか |
| `isAutoStopped` | `bool` | 自動停止中か |
| `hasDetectedBarcodes` | `bool` | バーコードを検出中か |
| `isCapturing` | `bool` | キャプチャモードか |

## コールバック

| パラメータ | 型 | 説明 |
|---|---|---|
| `onDetect` | `void Function(List<DetectedBarcode>, Size)?` | バーコード検出時（バーコードリストと画像サイズ） |
| `onCameraReady` | `void Function(CameraController)?` | カメラ準備完了時 |
| `onDetectionStateChanged` | `void Function({required bool hasDetectedBarcodes})?` | 検出状態の変化時 |
| `onAutoStopped` | `VoidCallback?` | 自動停止時 |

## DetectedBarcode

ML Kit の検出結果を抽象化したモデルクラスです。ライブラリ利用側が `google_mlkit_barcode_scanning` パッケージに直接依存する必要がない設計です（`BarcodeFormat` のみ再エクスポート）。

| プロパティ | 型 | 説明 |
|---|---|---|
| `rawValue` | `String` | デコードされた文字列 |
| `format` | `BarcodeFormat` | バーコードフォーマット |
| `boundingBox` | `Rect` | 境界ボックス（画像座標系） |
| `corners` | `List<Point<int>>?` | 4コーナーポイント（画像座標系） |
| `formatName` | `String` (getter) | フォーマットの表示名 |

## アーキテクチャ

```
┌────────────────────────────────────┐
│      HeronBarcodeScanner Widget    │  ← アプリが利用する Widget
│  ┌──────────┐  ┌────────────────┐  │
│  │ Camera   │  │ ML Kit Barcode │  │
│  │ Preview  │  │ Scanner        │  │
│  └──────────┘  └────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ Smooth Overlay Painter       │  │  ← コーナーブラケット + ラベル描画
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ Scan Window Painter          │  │  ← スキャン領域ガイド描画
│  └──────────────────────────────┘  │
└────────────────┬───────────────────┘
                 │ Pigeon (型安全チャネル)
                 ▼
┌────────────────────────────────────┐
│    ScanWindowHostApi (Native)      │
│  ┌──────────┐  ┌────────────────┐  │
│  │ Android  │  │     iOS        │  │
│  │ Kotlin   │  │     Swift      │  │
│  └──────────┘  └────────────────┘  │
│  スキャンウィンドウ計算・フィルタリング │
└────────────────────────────────────┘
```

### ネイティブ API（Pigeon 経由）

スキャンウィンドウ領域でのバーコードフィルタリングはネイティブ側で実行され、パフォーマンスを確保しています:

- `updateScanWindow(ScanWindowRect?)` — スキャンウィンドウの更新
- `isBarcodeInScanWindow(BarcodeBoundingBox, ImageDimensions)` — 単一バーコードの判定
- `filterBarcodes(List<BarcodeBoundingBox>, ImageDimensions)` — 複数バーコードの一括フィルタリング

## Pigeon コード生成

ネイティブ API の定義を変更した場合は、以下のコマンドで再生成してください:

```bash
cd heron_scanner
dart run pigeon --input pigeons/scan_window_api.dart
```

## 依存パッケージ

| パッケージ | バージョン | 用途 |
|---|---|---|
| `camera` | ^0.11.1 | カメラプレビューとストリーム |
| `google_mlkit_barcode_scanning` | ^0.12.0 | バーコード/QRコード検出 |
| `image` | ^4.7.2 | フレーム画像のJPEG変換 |
| `path` | ^1.9.1 | ファイルパス操作 |
| `path_provider` | ^2.1.5 | 一時ディレクトリ取得 |

## 動作要件

| | 最小バージョン |
|---|---|
| Flutter | 3.27.0 以上 |
| Dart SDK | 3.10.7 以上 |
| Android | minSdk 21 (Android 5.0) 以上 |
| iOS | 12.0 以上 |

## ライセンス

MIT License
