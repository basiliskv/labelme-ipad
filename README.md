# Labelme iPad

PC/Mac 側の Labelme データセットを HTTP で公開し、iPad の SwiftUI アプリから編集するための最小実装です。

`basiliskv/labelme` を `reference/labelme` に clone して、Labelme 5.x の JSON 形式に合わせています。保存先は既存の `labels/*.json` で、`images/*.JPG` などの画像を直接編集対象にします。

## 構成

- `server/labelme_server.py`: Python 標準ライブラリだけで動く dataset server
- `ios/LabelmeIpad/LabelmeIpad.xcodeproj`: iPad 用 SwiftUI アプリ
- `reference/labelme`: 参照用に clone した basiliskv/labelme

## サーバー起動

```sh
cd /Users/koheikato/dev/labelme-ipad
chmod +x scripts/start_server.sh
./scripts/start_server.sh
```

デフォルトでは `/Users/koheikato/Downloads/mygarbageseg` を使います。別のデータセットを使う場合:

```sh
./scripts/start_server.sh /path/to/dataset
```

起動すると、iPad から入力する URL が表示されます。

```text
Use on iPad: http://192.168.x.x:8765
```

## iPad アプリ

1. Xcode で `ios/LabelmeIpad/LabelmeIpad.xcodeproj` を開く
2. 実機 iPad または Simulator を選ぶ
3. Run
4. 上部の URL 欄に `http://PCのIP:8765` を入力して `Open Dir`

## UI

Labelme のデスクトップ UI に寄せて、左から `File List`、中央 `Canvas`、右 `Labels` の 3 ペイン構成です。

- `Edit Shapes`: 図形選択、図形移動、頂点移動、選択中 polygon/linestrip の辺タップで点追加
- `Polygon`: タップで頂点追加、始点タップまたは `Finish` で確定
- `Rectangle/Circle/Line`: ドラッグで作成
- `Point`: タップで作成
- `LineStrip`: タップで点追加、`Finish` で確定
- Shape List の長押し: Edit、Shape Type、Duplicate、Copy/Paste、Hide/Show、Delete、Select All など
- Undo/Redo: toolbar の戻る/進むボタン、または外部キーボードの `Ctrl+Z` / `Ctrl+Y`（`Keys` で変更可）
- 複数選択: 外部キーボードのShiftを押しながらCanvas上のpolygon/shapeをタップ（修飾キーは `Keys` で変更可）
- Polygon 結合: 同じラベルのpolygonを2つ選択した状態で `Connect Polygon`
- 左右ペイン切替: toolbar の sidebar アイコン
- `Fit Window / Zoom In / Zoom Out`
- `Brightness Contrast`: 元画像を変更せず、表示中の画像だけを `0.00` から `3.00` の範囲で明るさ・コントラスト調整
- `Fill Drawing Polygon`
- `Toggle Labels / Toggle Shapes`
- `Duplicate Shapes / Delete Shapes`
- `Save`

保存形式は Labelme JSON の主要キーに合わせています。

```json
{
  "version": "5.5.0",
  "flags": {},
  "shapes": [],
  "imagePath": "..\\images\\IMG_1442.JPG",
  "imageData": null,
  "imageHeight": 2448,
  "imageWidth": 3264
}
```

## API

- `GET /api/health`
- `GET /api/images`
- `GET /api/image/{id}`
- `GET /api/annotation/{id}`
- `PUT /api/annotation/{id}`

`PUT` すると `labels/<image-stem>.json` が atomic write で更新されます。
