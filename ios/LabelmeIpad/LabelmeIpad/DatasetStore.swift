import Foundation
import ImageIO
import SwiftUI
import UIKit
import zlib

enum ShortcutModifier: String, CaseIterable, Identifiable {
    case shift
    case control
    case option
    case command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: "Shift"
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        }
    }

    var eventModifiers: EventModifiers {
        switch self {
        case .shift: .shift
        case .control: .control
        case .option: .option
        case .command: .command
        }
    }

    var uiModifierFlag: UIKeyModifierFlags {
        switch self {
        case .shift: .shift
        case .control: .control
        case .option: .alternate
        case .command: .command
        }
    }

    func matches(_ flags: UIKeyModifierFlags) -> Bool {
        flags.contains(uiModifierFlag)
    }

    func isPhysicalModifierPress(_ press: UIPress) -> Bool {
        guard let key = press.key else { return false }
        switch (self, key.keyCode) {
        case (.shift, .keyboardLeftShift), (.shift, .keyboardRightShift):
            return true
        case (.control, .keyboardLeftControl), (.control, .keyboardRightControl):
            return true
        case (.option, .keyboardLeftAlt), (.option, .keyboardRightAlt):
            return true
        case (.command, .keyboardLeftGUI), (.command, .keyboardRightGUI):
            return true
        default:
            return false
        }
    }
}

enum ImageAdjustmentDefaults {
    static let range: ClosedRange<Double> = 0...3
    static let neutral = 1.0
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case close
    case open
    case openDir
    case openZip
    case openDocumentsDataset
    case showSettings
    case quit
    case save
    case saveAs
    case saveTo
    case deleteFile
    case openNext
    case openPrev
    case zoomIn
    case zoomOut
    case zoomToOriginal
    case fitWindow
    case fitWidth
    case createPolygon
    case createRectangle
    case createOrientedRectangle
    case createCircle
    case createLine
    case createPoint
    case createLinestrip
    case editShape
    case selectAllShapes
    case clearShapeSelection
    case deleteShape
    case duplicateShape
    case copyShape
    case pasteShape
    case connectPolygons
    case subtractOverlap
    case changeSelectedToPolygon
    case changeSelectedToRectangle
    case changeSelectedToCircle
    case changeSelectedToLine
    case changeSelectedToPoint
    case changeSelectedToLinestrip
    case undo
    case undoLastPoint
    case editLabel
    case toggleKeepPrevMode
    case removeSelectedPoint
    case showAllShapes
    case hideAllShapes
    case toggleAllShapes
    case showSelectedShapes
    case hideSelectedShapes
    case toggleSelectedShapes
    case toggleLabels
    case toggleFillPolygons
    case toggleFileList
    case toggleLabelPanel
    case showBrightnessContrast
    case resetBrightnessContrast
    case redo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .close: "画像を閉じる"
        case .open: "サーバーへ接続"
        case .openDir: "ローカルフォルダを開く"
        case .openZip: "Zip を読み込む"
        case .openDocumentsDataset: "アプリ内データセットを開く"
        case .showSettings: "設定を開く"
        case .quit: "終了"
        case .save: "保存"
        case .saveAs: "別名で保存"
        case .saveTo: "出力先を変更"
        case .deleteFile: "画像ファイルを削除"
        case .openNext: "次の画像"
        case .openPrev: "前の画像"
        case .zoomIn: "拡大"
        case .zoomOut: "縮小"
        case .zoomToOriginal: "100% 表示"
        case .fitWindow: "ウィンドウに合わせる"
        case .fitWidth: "幅に合わせる"
        case .createPolygon: "ポリゴン作成"
        case .createRectangle: "矩形作成"
        case .createOrientedRectangle: "回転矩形作成"
        case .createCircle: "円作成"
        case .createLine: "ライン作成"
        case .createPoint: "点作成"
        case .createLinestrip: "折れ線作成"
        case .editShape: "図形編集"
        case .selectAllShapes: "すべて選択"
        case .clearShapeSelection: "選択解除"
        case .deleteShape: "図形を削除"
        case .duplicateShape: "図形を複製"
        case .copyShape: "図形をコピー"
        case .pasteShape: "図形を貼り付け"
        case .connectPolygons: "ポリゴンを結合"
        case .subtractOverlap: "重なり部分を削る"
        case .changeSelectedToPolygon: "選択図形をポリゴンに変更"
        case .changeSelectedToRectangle: "選択図形を矩形に変更"
        case .changeSelectedToCircle: "選択図形を円に変更"
        case .changeSelectedToLine: "選択図形をラインに変更"
        case .changeSelectedToPoint: "選択図形を点に変更"
        case .changeSelectedToLinestrip: "選択図形を折れ線に変更"
        case .undo: "元に戻す"
        case .undoLastPoint: "最後の点を取り消す"
        case .editLabel: "ラベルを編集"
        case .toggleKeepPrevMode: "前画像の図形引き継ぎ"
        case .removeSelectedPoint: "選択頂点を削除"
        case .showAllShapes: "すべての図形を表示"
        case .hideAllShapes: "すべての図形を非表示"
        case .toggleAllShapes: "全図形の表示切替"
        case .showSelectedShapes: "選択図形を表示"
        case .hideSelectedShapes: "選択図形を非表示"
        case .toggleSelectedShapes: "選択図形の表示切替"
        case .toggleLabels: "ラベル表示切替"
        case .toggleFillPolygons: "塗りつぶし表示切替"
        case .toggleFileList: "ファイルリスト表示切替"
        case .toggleLabelPanel: "ラベルパネル表示切替"
        case .showBrightnessContrast: "明るさ/コントラスト"
        case .resetBrightnessContrast: "明るさ/コントラストをリセット"
        case .redo: "やり直す"
        }
    }

    var section: String {
        switch self {
        case .close, .open, .openDir, .openZip, .openDocumentsDataset, .quit, .save, .saveAs, .saveTo, .deleteFile, .openNext, .openPrev:
            "ファイル"
        case .zoomIn, .zoomOut, .zoomToOriginal, .fitWindow, .fitWidth, .showAllShapes, .hideAllShapes, .toggleAllShapes, .showSelectedShapes, .hideSelectedShapes, .toggleSelectedShapes, .toggleLabels, .toggleFillPolygons, .toggleFileList, .toggleLabelPanel, .showBrightnessContrast, .resetBrightnessContrast, .showSettings:
            "表示"
        case .createPolygon, .createRectangle, .createOrientedRectangle, .createCircle, .createLine, .createPoint, .createLinestrip, .editShape, .selectAllShapes, .clearShapeSelection, .deleteShape, .duplicateShape, .copyShape, .pasteShape, .connectPolygons, .subtractOverlap, .changeSelectedToPolygon, .changeSelectedToRectangle, .changeSelectedToCircle, .changeSelectedToLine, .changeSelectedToPoint, .changeSelectedToLinestrip, .undo, .undoLastPoint, .editLabel, .toggleKeepPrevMode, .removeSelectedPoint, .redo:
            "編集"
        }
    }

    var detail: String {
        switch self {
        case .close: "現在の画像を閉じます。データセット自体は開いたままです。"
        case .open: "設定済みのサーバーデータセットへ接続します。"
        case .openDir: "Files からローカルの Labelme データセットフォルダを開きます。"
        case .openZip: "Files から Labelme データセットの Zip を読み込みます。"
        case .openDocumentsDataset: "アプリ内 Documents に置いたデータセットを開きます。"
        case .showSettings: "設定画面を開きます。"
        case .quit: "デスクトップ版 Labelme 互換用の予約項目です。"
        case .save: "現在のアノテーション JSON を保存します。"
        case .saveAs: "Labelme の Save As 相当として予約しています。"
        case .saveTo: "出力先ラベルディレクトリ変更用として予約しています。"
        case .deleteFile: "現在の画像ファイル削除用として予約しています。"
        case .openNext: "ファイルリストの次の画像へ移動します。"
        case .openPrev: "ファイルリストの前の画像へ移動します。"
        case .zoomIn: "キャンバスを拡大します。"
        case .zoomOut: "キャンバスを縮小します。"
        case .zoomToOriginal: "キャンバスのズームを 100% にします。"
        case .fitWindow: "画像全体がキャンバス内に収まるように表示します。"
        case .fitWidth: "画像の幅がキャンバス幅に合うように表示します。"
        case .createPolygon: "ポリゴン作成モードに切り替えます。"
        case .createRectangle: "矩形作成モードに切り替えます。"
        case .createOrientedRectangle: "回転矩形作成用として予約しています。"
        case .createCircle: "円作成モードに切り替えます。"
        case .createLine: "ライン作成モードに切り替えます。"
        case .createPoint: "点作成モードに切り替えます。"
        case .createLinestrip: "折れ線作成モードに切り替えます。"
        case .editShape: "編集・選択モードに戻します。作成モードと同じショートカットにすると、押すたびに編集と作成を切り替えます。"
        case .selectAllShapes: "現在の画像内のすべての図形を選択します。"
        case .clearShapeSelection: "図形の選択状態を解除します。"
        case .deleteShape: "選択中の図形を削除します。複数選択にも対応します。"
        case .duplicateShape: "選択中の図形を複製します。複数選択にも対応します。"
        case .copyShape: "選択中の図形をコピーします。複数選択にも対応します。"
        case .pasteShape: "コピーした図形を現在のアノテーションに貼り付けます。"
        case .connectPolygons: "選択中の同じラベルのポリゴン2つを結合します。"
        case .subtractOverlap: "選択中ポリゴンだけを対象に、上レイヤー優先で重なり部分を削ります。"
        case .changeSelectedToPolygon: "選択中の図形タイプをポリゴンに変更します。"
        case .changeSelectedToRectangle: "選択中の図形タイプを矩形に変更します。"
        case .changeSelectedToCircle: "選択中の図形タイプを円に変更します。"
        case .changeSelectedToLine: "選択中の図形タイプをラインに変更します。"
        case .changeSelectedToPoint: "選択中の図形タイプを点に変更します。"
        case .changeSelectedToLinestrip: "選択中の図形タイプを折れ線に変更します。"
        case .undo: "直前の編集を元に戻します。"
        case .undoLastPoint: "図形作成中に最後に追加した点を取り消します。"
        case .editLabel: "選択中の図形のラベル入力欄にフォーカスします。"
        case .toggleKeepPrevMode: "空のアノテーションへ前画像の図形を引き継ぐモードを切り替えます。"
        case .removeSelectedPoint: "選択中の図形から選択頂点を削除します。"
        case .showAllShapes: "現在のアノテーション内のすべての図形を表示します。"
        case .hideAllShapes: "現在のアノテーション内のすべての図形を非表示にします。"
        case .toggleAllShapes: "すべての図形の表示・非表示を切り替えます。"
        case .showSelectedShapes: "選択中の図形を表示します。ポリゴンを選択して使えます。"
        case .hideSelectedShapes: "選択中の図形を非表示にします。ポリゴンを選択して使えます。"
        case .toggleSelectedShapes: "選択中の図形の表示・非表示を切り替えます。"
        case .toggleLabels: "キャンバス上のラベル名表示を切り替えます。"
        case .toggleFillPolygons: "ポリゴン塗りつぶし表示を切り替えます。"
        case .toggleFileList: "左側のファイルリスト表示を切り替えます。"
        case .toggleLabelPanel: "右側のラベル・図形パネル表示を切り替えます。"
        case .showBrightnessContrast: "画像の明るさ・コントラスト調整パネルを開きます。"
        case .resetBrightnessContrast: "現在の画像の明るさ・コントラストを標準値に戻します。"
        case .redo: "取り消した編集をやり直します。"
        }
    }

    var defaultShortcutText: String {
        switch self {
        case .close: "Ctrl+W"
        case .open: "Ctrl+O"
        case .openDir: "Ctrl+U"
        case .openZip: ""
        case .openDocumentsDataset: ""
        case .showSettings: "Ctrl+,"
        case .quit: "Ctrl+Q"
        case .save: "Ctrl+S"
        case .saveAs: "Ctrl+Shift+S"
        case .saveTo: ""
        case .deleteFile: "Ctrl+Delete"
        case .openNext: "D, Ctrl+Shift+D"
        case .openPrev: "A, Ctrl+Shift+A"
        case .zoomIn: "Ctrl++, Ctrl+="
        case .zoomOut: "Ctrl+-"
        case .zoomToOriginal: "Ctrl+0"
        case .fitWindow: "Ctrl+F"
        case .fitWidth: "Ctrl+Shift+F"
        case .createPolygon: "Ctrl+N"
        case .createRectangle: "Ctrl+R"
        case .createOrientedRectangle: ""
        case .createCircle: ""
        case .createLine: ""
        case .createPoint: ""
        case .createLinestrip: ""
        case .editShape: "Ctrl+J"
        case .selectAllShapes: "Ctrl+A"
        case .clearShapeSelection: "Esc"
        case .deleteShape: "Delete"
        case .duplicateShape: "Ctrl+D"
        case .copyShape: "Ctrl+C"
        case .pasteShape: "Ctrl+V"
        case .connectPolygons: ""
        case .subtractOverlap: ""
        case .changeSelectedToPolygon: ""
        case .changeSelectedToRectangle: ""
        case .changeSelectedToCircle: ""
        case .changeSelectedToLine: ""
        case .changeSelectedToPoint: ""
        case .changeSelectedToLinestrip: ""
        case .undo: "Ctrl+Z"
        case .undoLastPoint: "Ctrl+Z"
        case .editLabel: "Ctrl+E"
        case .toggleKeepPrevMode: "Ctrl+P"
        case .removeSelectedPoint: "Meta+H, Backspace"
        case .showAllShapes: ""
        case .hideAllShapes: ""
        case .toggleAllShapes: "T"
        case .showSelectedShapes: ""
        case .hideSelectedShapes: ""
        case .toggleSelectedShapes: ""
        case .toggleLabels: ""
        case .toggleFillPolygons: ""
        case .toggleFileList: ""
        case .toggleLabelPanel: ""
        case .showBrightnessContrast: ""
        case .resetBrightnessContrast: ""
        case .redo: "Ctrl+Y"
        }
    }

    var isOriginalLabelmeShortcut: Bool {
        switch self {
        case .openZip, .openDocumentsDataset, .showSettings, .redo, .selectAllShapes, .clearShapeSelection, .connectPolygons, .subtractOverlap, .changeSelectedToPolygon, .changeSelectedToRectangle, .changeSelectedToCircle, .changeSelectedToLine, .changeSelectedToPoint, .changeSelectedToLinestrip, .showSelectedShapes, .hideSelectedShapes, .toggleSelectedShapes, .toggleLabels, .toggleFillPolygons, .toggleFileList, .toggleLabelPanel, .showBrightnessContrast, .resetBrightnessContrast:
            false
        default:
            true
        }
    }

    var placeholderShortcutText: String {
        defaultShortcutText.isEmpty ? "Unassigned" : defaultShortcutText
    }

    var isShapeCreationMode: Bool {
        switch self {
        case .createPolygon, .createRectangle, .createCircle, .createLine, .createPoint, .createLinestrip:
            true
        default:
            false
        }
    }

    func canShareShortcut(with other: ShortcutAction) -> Bool {
        (self == .editShape && other.isShapeCreationMode) || (other == .editShape && isShapeCreationMode)
    }
}

struct ShortcutRegistry {
    private var overrides: [String: String]

    init(json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            overrides = [:]
            return
        }
        overrides = decoded
    }

    func shortcutText(for action: ShortcutAction) -> String {
        overrides[action.rawValue] ?? action.defaultShortcutText
    }

    func shortcuts(for action: ShortcutAction) -> [KeyStroke] {
        KeyStroke.parseList(shortcutText(for: action))
    }

    func conflicts(for action: ShortcutAction, shortcutText: String) -> [ShortcutConflict] {
        let newShortcuts = Set(KeyStroke.parseList(shortcutText))
        guard !newShortcuts.isEmpty else { return [] }
        return ShortcutAction.allCases.compactMap { otherAction in
            guard otherAction != action else { return nil }
            guard !action.canShareShortcut(with: otherAction) else { return nil }
            let overlaps = shortcuts(for: otherAction).filter { newShortcuts.contains($0) }
            guard !overlaps.isEmpty else { return nil }
            return ShortcutConflict(action: otherAction, shortcuts: overlaps)
        }
    }

    func actions(for press: UIPress) -> [ShortcutAction] {
        ShortcutAction.allCases.filter { action in
            shortcuts(for: action).contains(where: { $0.matches(press) })
        }
    }

    func action(for press: UIPress) -> ShortcutAction? {
        actions(for: press).first
    }

    static func json(updating json: String, action: ShortcutAction, shortcutText: String) -> String {
        var registry = ShortcutRegistry(json: json)
        let trimmed = shortcutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == action.defaultShortcutText {
            registry.overrides.removeValue(forKey: action.rawValue)
        } else {
            registry.overrides[action.rawValue] = trimmed
        }
        return registry.encodedJSON
    }

    static func jsonResolvingConflicts(updating json: String, action: ShortcutAction, shortcutText: String) -> String {
        let registry = ShortcutRegistry(json: json)
        let newShortcuts = Set(KeyStroke.parseList(shortcutText))
        var updatedJSON = json
        if !newShortcuts.isEmpty {
            for otherAction in ShortcutAction.allCases where otherAction != action {
                guard !action.canShareShortcut(with: otherAction) else { continue }
                let remaining = registry.shortcuts(for: otherAction).filter { !newShortcuts.contains($0) }
                if remaining.count != registry.shortcuts(for: otherAction).count {
                    let remainingText = remaining.map(\.shortcutText).joined(separator: ", ")
                    updatedJSON = ShortcutRegistry.json(
                        updating: updatedJSON,
                        action: otherAction,
                        shortcutText: remainingText
                    )
                }
            }
        }
        return ShortcutRegistry.json(updating: updatedJSON, action: action, shortcutText: shortcutText)
    }

    static func defaultJSON() -> String {
        "{}"
    }

    private var encodedJSON: String {
        guard let data = try? JSONEncoder().encode(overrides),
              let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }
}

struct ShortcutConflict: Identifiable {
    let action: ShortcutAction
    let shortcuts: [KeyStroke]

    var id: String {
        action.rawValue
    }

    var shortcutText: String {
        shortcuts.map(\.shortcutText).joined(separator: ", ")
    }
}

struct KeyStroke: Hashable {
    var key: String
    var modifiers: Set<ShortcutModifier>

    var shortcutText: String {
        let modifierText = ShortcutModifier.allCases
            .filter { modifiers.contains($0) }
            .map(\.shortcutDisplayName)
        return (modifierText + [Self.displayKey(key)]).joined(separator: "+")
    }

    static func fromPress(_ press: UIPress) -> KeyStroke? {
        guard let key = press.key else { return nil }
        let keyName: String?
        switch key.keyCode {
        case .keyboardDeleteOrBackspace:
            keyName = "backspace"
        case .keyboardDeleteForward:
            keyName = "delete"
        case .keyboardEscape:
            keyName = "escape"
        case .keyboardReturnOrEnter:
            keyName = "enter"
        case .keyboardSpacebar:
            keyName = "space"
        case .keyboardTab:
            keyName = "tab"
        case .keyboardLeftShift, .keyboardRightShift,
             .keyboardLeftControl, .keyboardRightControl,
             .keyboardLeftAlt, .keyboardRightAlt,
             .keyboardLeftGUI, .keyboardRightGUI:
            keyName = nil
        default:
            let ignoringModifiers = key.charactersIgnoringModifiers.trimmingCharacters(in: .whitespacesAndNewlines)
            let characters = key.characters.trimmingCharacters(in: .whitespacesAndNewlines)
            keyName = ignoringModifiers.isEmpty ? characters : ignoringModifiers
        }
        guard let keyName, !keyName.isEmpty else { return nil }
        return KeyStroke(key: normalizedKey(keyName), modifiers: modifiers(for: press))
    }

    static func parseList(_ text: String) -> [KeyStroke] {
        text
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .compactMap { parse(String($0)) }
    }

    static func parse(_ text: String) -> KeyStroke? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == "+" {
            return KeyStroke(key: "+", modifiers: [])
        }

        if trimmed.hasSuffix("++") {
            let modifierText = String(trimmed.dropLast(2))
            let modifiers = parseModifiers(modifierText)
            return KeyStroke(key: "+", modifiers: modifiers)
        }

        let parts = trimmed
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let keyPart = parts.last else { return nil }
        let modifiers = parseModifiers(parts.dropLast().joined(separator: "+"))
        return KeyStroke(key: Self.normalizedKey(keyPart), modifiers: modifiers)
    }

    private static func parseModifiers(_ text: String) -> Set<ShortcutModifier> {
        var modifiers = Set<ShortcutModifier>()
        for part in text.split(separator: "+") {
            guard let modifier = ShortcutModifier(shortcutToken: String(part)) else { continue }
            modifiers.insert(modifier)
        }
        return modifiers
    }

    func matches(_ press: UIPress) -> Bool {
        Self.keyNames(for: press).contains(key) && modifiers == Self.modifiers(for: press)
    }

    private static func normalizedKey(_ value: String) -> String {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "del":
            return "delete"
        case "return":
            return "enter"
        case "esc":
            return "escape"
        case "spacebar":
            return "space"
        case "plus":
            return "+"
        case "minus":
            return "-"
        case "comma":
            return ","
        case "period":
            return "."
        default:
            return key
        }
    }

    private static func displayKey(_ value: String) -> String {
        switch value {
        case "backspace": "Backspace"
        case "delete": "Delete"
        case "escape": "Esc"
        case "enter": "Enter"
        case "space": "Space"
        case "tab": "Tab"
        default:
            value.count == 1 ? value.uppercased() : value
        }
    }

    private static func keyNames(for press: UIPress) -> Set<String> {
        guard let key = press.key else { return [] }
        let specialKey: String?
        switch key.keyCode {
        case .keyboardDeleteOrBackspace:
            specialKey = "backspace"
        case .keyboardDeleteForward:
            specialKey = "delete"
        case .keyboardEscape:
            specialKey = "escape"
        case .keyboardReturnOrEnter:
            specialKey = "enter"
        case .keyboardSpacebar:
            specialKey = "space"
        default:
            specialKey = nil
        }

        var names = Set<String>()
        if let specialKey {
            names.insert(specialKey)
        }

        let characters = key.characters.lowercased()
        if !characters.isEmpty {
            names.insert(normalizedKey(characters))
        }

        let ignoringModifiers = key.charactersIgnoringModifiers.lowercased()
        if !ignoringModifiers.isEmpty {
            names.insert(normalizedKey(ignoringModifiers))
        }

        return names
    }

    private static func modifiers(for press: UIPress) -> Set<ShortcutModifier> {
        guard let flags = press.key?.modifierFlags else { return [] }
        return Set(ShortcutModifier.allCases.filter { $0.matches(flags) })
    }
}

extension ShortcutModifier {
    var shortcutDisplayName: String {
        switch self {
        case .shift: "Shift"
        case .control: "Ctrl"
        case .option: "Alt"
        case .command: "Meta"
        }
    }

    init?(shortcutToken: String) {
        switch shortcutToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ctrl", "control":
            self = .control
        case "shift":
            self = .shift
        case "alt", "option":
            self = .option
        case "meta", "cmd", "command":
            self = .command
        default:
            return nil
        }
    }
}

private struct LocalImageRecord {
    let id: String
    let imageURL: URL
    let relativePath: String
    let labelURL: URL
}

private protocol LocalDatasetProviding: AnyObject {
    func health() -> ServerHealth
    func images(query: String) throws -> DatasetImageListResponse
    func annotation(for item: DatasetImageItem) throws -> LabelmeAnnotation
    func loadImage(for item: DatasetImageItem) throws -> UIImage
    func save(_ annotation: LabelmeAnnotation, for item: DatasetImageItem) throws -> LabelmeAnnotation
    func importImages(from urls: [URL]) throws -> [DatasetImageItem]
}

private final class LocalLabelmeDataset: LocalDatasetProviding {
    let rootURL: URL
    let imagesURL: URL
    let labelsURL: URL

    private let securityScopeURL: URL
    private let hasSecurityScope: Bool
    private var records: [LocalImageRecord] = []
    private var recordByID: [String: LocalImageRecord] = [:]
    private let fileManager = FileManager.default

    init(rootURL: URL) throws {
        let pickedURL = rootURL.standardizedFileURL
        securityScopeURL = pickedURL
        hasSecurityScope = pickedURL.startAccessingSecurityScopedResource()
        let standardizedRoot = try Self.datasetRootCandidate(for: pickedURL, fileManager: fileManager)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: standardizedRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LocalDatasetError.notDirectory(standardizedRoot.path)
        }

        let imagesCandidate = standardizedRoot.appendingPathComponent("images", isDirectory: true)
        if Self.isDirectory(imagesCandidate, fileManager: fileManager) {
            self.rootURL = standardizedRoot
            self.imagesURL = imagesCandidate
            self.labelsURL = standardizedRoot.appendingPathComponent("labels", isDirectory: true)
        } else if standardizedRoot.lastPathComponent.lowercased() == "images",
                  let parent = standardizedRoot.deletingLastPathComponentIfPossible {
            self.rootURL = parent
            self.imagesURL = standardizedRoot
            self.labelsURL = parent.appendingPathComponent("labels", isDirectory: true)
        } else {
            self.rootURL = standardizedRoot
            self.imagesURL = standardizedRoot
            self.labelsURL = standardizedRoot.appendingPathComponent("labels", isDirectory: true)
        }

        try fileManager.createDirectory(at: labelsURL, withIntermediateDirectories: true, attributes: nil)
        try refresh()
        guard !records.isEmpty else {
            throw LocalDatasetError.noImages(imagesURL.path)
        }
    }

    deinit {
        if hasSecurityScope {
            securityScopeURL.stopAccessingSecurityScopedResource()
        }
    }

    func refresh() throws {
        let imageFiles = try imageFiles(in: imagesURL)
        let records = imageFiles.map { imageURL in
            let relativePath = Self.relativePath(from: imagesURL, to: imageURL)
            return LocalImageRecord(
                id: Self.recordID(relativePath),
                imageURL: imageURL,
                relativePath: relativePath,
                labelURL: labelURL(for: relativePath)
            )
        }
        self.records = records.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        recordByID = Dictionary(uniqueKeysWithValues: self.records.map { ($0.id, $0) })
    }

    func health() -> ServerHealth {
        ServerHealth(
            ok: true,
            datasetRoot: rootURL.path,
            imagesRoot: imagesURL.path,
            labelsRoot: labelsURL.path,
            imageCount: records.count,
            annotatedCount: records.filter { fileManager.fileExists(atPath: $0.labelURL.path) }.count,
            hostHint: nil
        )
    }

    func images(query: String) throws -> DatasetImageListResponse {
        try refresh()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = records.filter { record in
            needle.isEmpty
                || record.relativePath.lowercased().contains(needle)
                || record.imageURL.deletingPathExtension().lastPathComponent.lowercased().contains(needle)
        }
        return DatasetImageListResponse(
            datasetRoot: rootURL.path,
            imagesRoot: imagesURL.path,
            labelsRoot: labelsURL.path,
            offset: 0,
            limit: filtered.count,
            total: filtered.count,
            items: filtered.map(itemPayload)
        )
    }

    func annotation(for item: DatasetImageItem) throws -> LabelmeAnnotation {
        let record = try record(for: item)
        let size = imageSize(record.imageURL)
        var annotation: LabelmeAnnotation
        if fileManager.fileExists(atPath: record.labelURL.path) {
            let data = try Data(contentsOf: record.labelURL)
            annotation = try JSONDecoder.labelme.decode(LabelmeAnnotation.self, from: data)
        } else {
            annotation = LabelmeAnnotation(
                version: "5.5.0",
                flags: [:],
                shapes: [],
                imagePath: Self.labelImagePath(record.relativePath),
                imageData: nil,
                imageHeight: size.height,
                imageWidth: size.width,
                imageUrl: record.imageURL.absoluteString
            )
        }
        annotation.imagePath = Self.labelImagePath(record.relativePath)
        annotation.imageData = nil
        annotation.imageHeight = annotation.imageHeight > 0 ? annotation.imageHeight : size.height
        annotation.imageWidth = annotation.imageWidth > 0 ? annotation.imageWidth : size.width
        annotation.imageUrl = record.imageURL.absoluteString
        return annotation
    }

    func loadImage(for item: DatasetImageItem) throws -> UIImage {
        let record = try record(for: item)
        guard let image = UIImage(contentsOfFile: record.imageURL.path) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }

    func save(_ annotation: LabelmeAnnotation, for item: DatasetImageItem) throws -> LabelmeAnnotation {
        let record = try record(for: item)
        let size = imageSize(record.imageURL)
        var saved = annotation
        saved.imagePath = Self.labelImagePath(record.relativePath)
        saved.imageData = nil
        saved.imageUrl = nil
        saved.imageHeight = size.height
        saved.imageWidth = size.width
        try fileManager.createDirectory(at: record.labelURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        let data = try JSONEncoder.labelme.encode(saved)
        try data.write(to: record.labelURL, options: [.atomic])
        saved.imageUrl = record.imageURL.absoluteString
        return saved
    }

    func importImages(from urls: [URL]) throws -> [DatasetImageItem] {
        guard !urls.isEmpty else { return [] }
        try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true, attributes: nil)
        var importedRelativePaths: [String] = []
        for sourceURL in urls {
            let source = sourceURL.standardizedFileURL
            guard Self.imageExtensions.contains(source.pathExtension.lowercased()) else {
                throw LocalDatasetError.unsupportedImage(source.lastPathComponent)
            }
            let destination = uniqueImageURL(for: source.lastPathComponent)
            try fileManager.copyItem(at: source, to: destination)
            importedRelativePaths.append(Self.relativePath(from: imagesURL, to: destination))
        }
        try refresh()
        return importedRelativePaths.compactMap { recordByID[Self.recordID($0)].map(itemPayload) }
    }

    private func record(for item: DatasetImageItem) throws -> LocalImageRecord {
        if let record = recordByID[item.id] {
            return record
        }
        throw LocalDatasetError.missingImage(item.relativePath)
    }

    private func imageFiles(in root: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LocalDatasetError.notDirectory(root.path)
        }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard Self.imageExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            urls.append(url.standardizedFileURL)
        }
        return urls
    }

    private func labelURL(for relativePath: String) -> URL {
        let labelRelative = (relativePath as NSString).deletingPathExtension + ".json"
        return Self.childURL(root: labelsURL, relativePath: labelRelative)
    }

    private func uniqueImageURL(for filename: String) -> URL {
        let fallbackName = filename.isEmpty ? "image.jpg" : filename
        let base = URL(fileURLWithPath: fallbackName).lastPathComponent
        let candidate = imagesURL.appendingPathComponent(base)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        let stem = (base as NSString).deletingPathExtension
        let ext = (base as NSString).pathExtension
        for index in 1..<10000 {
            let name = ext.isEmpty ? "\(stem)_\(index)" : "\(stem)_\(index).\(ext)"
            let next = imagesURL.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: next.path) {
                return next
            }
        }
        return imagesURL.appendingPathComponent(UUID().uuidString + "-" + base)
    }

    private func itemPayload(_ record: LocalImageRecord) -> DatasetImageItem {
        return DatasetImageItem(
            id: record.id,
            fileName: record.imageURL.lastPathComponent,
            stem: record.imageURL.deletingPathExtension().lastPathComponent,
            relativePath: record.relativePath,
            labelPath: record.labelURL.path,
            imageUrl: record.imageURL.absoluteString,
            annotationUrl: record.labelURL.absoluteString,
            annotated: fileManager.fileExists(atPath: record.labelURL.path),
            shapeCount: 0,
            labels: [],
            imageWidth: nil,
            imageHeight: nil,
            updatedAt: max(modificationTime(record.imageURL), modificationTime(record.labelURL))
        )
    }

    private func imageSize(_ url: URL) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else {
            return (0, 0)
        }
        return (width.intValue, height.intValue)
    }

    private func modificationTime(_ url: URL) -> Double {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date
        else { return 0 }
        return date.timeIntervalSince1970
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func datasetRootCandidate(for pickedURL: URL, fileManager: FileManager) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: pickedURL.path, isDirectory: &isDirectory) else {
            throw LocalDatasetError.notDirectory(pickedURL.path)
        }

        let baseURL = isDirectory.boolValue ? pickedURL : pickedURL.deletingLastPathComponent()
        if let imagesAncestor = ancestor(named: "images", from: baseURL) {
            return imagesAncestor.deletingLastPathComponent()
        }
        if let labelsAncestor = ancestor(named: "labels", from: baseURL) {
            return labelsAncestor.deletingLastPathComponent()
        }
        return baseURL
    }

    private static func ancestor(named name: String, from url: URL) -> URL? {
        var current = url.standardizedFileURL
        while true {
            if current.lastPathComponent.lowercased() == name {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent == current {
                return nil
            }
            current = parent
        }
    }

    private static func recordID(_ relativePath: String) -> String {
        let data = Data(relativePath.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func relativePath(from root: URL, to url: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let relative = filePath.hasPrefix(rootPath) ? String(filePath.dropFirst(rootPath.count)) : url.lastPathComponent
        return relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func childURL(root: URL, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(root) { partial, component in
                partial.appendingPathComponent(String(component))
            }
    }

    private static func labelImagePath(_ relativePath: String) -> String {
        "..\\images\\" + relativePath.replacingOccurrences(of: "/", with: "\\")
    }

    private static let imageExtensions = Set(["jpg", "jpeg", "png", "bmp", "gif", "webp", "tif", "tiff"])
}

private struct ZipImageRecord {
    let id: String
    let imageEntry: ZipArchiveEntry
    let relativePath: String
    let labelPathInZip: String
    let sidecarLabelURL: URL
}

private final class ZipLabelmeDataset: LocalDatasetProviding {
    let zipURL: URL
    let labelsURL: URL

    private let securityScopeURL: URL
    private let hasSecurityScope: Bool
    private let index: ZipArchiveIndex
    private let records: [ZipImageRecord]
    private let recordByID: [String: ZipImageRecord]
    private let fileManager = FileManager.default

    init(zipURL pickedURL: URL) throws {
        let sourceURL = pickedURL.standardizedFileURL
        securityScopeURL = sourceURL
        hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        zipURL = sourceURL
        index = try ZipArchiveExtractor.index(zipURL: sourceURL)

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let sidecarName = Self.sidecarName(for: sourceURL)
        labelsURL = applicationSupportURL
            .appendingPathComponent("ZipDatasetEdits", isDirectory: true)
            .appendingPathComponent(sidecarName, isDirectory: true)
            .appendingPathComponent("labels", isDirectory: true)
        try fileManager.createDirectory(at: labelsURL, withIntermediateDirectories: true, attributes: nil)

        let imageRecords = try Self.imageRecords(in: index, labelsURL: labelsURL)
        guard !imageRecords.isEmpty else {
            throw LocalDatasetError.noImages(sourceURL.path)
        }
        records = imageRecords.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        recordByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    deinit {
        if hasSecurityScope {
            securityScopeURL.stopAccessingSecurityScopedResource()
        }
    }

    func health() -> ServerHealth {
        ServerHealth(
            ok: true,
            datasetRoot: zipURL.path,
            imagesRoot: "\(zipURL.lastPathComponent)/images",
            labelsRoot: labelsURL.path,
            imageCount: records.count,
            annotatedCount: records.filter { isAnnotated($0) }.count,
            hostHint: nil
        )
    }

    func images(query: String) throws -> DatasetImageListResponse {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = records.filter { record in
            needle.isEmpty
                || record.relativePath.lowercased().contains(needle)
                || record.imageEntry.relativePath.lowercased().contains(needle)
        }
        return DatasetImageListResponse(
            datasetRoot: zipURL.path,
            imagesRoot: "\(zipURL.lastPathComponent)/images",
            labelsRoot: labelsURL.path,
            offset: 0,
            limit: filtered.count,
            total: filtered.count,
            items: filtered.map(itemPayload)
        )
    }

    func annotation(for item: DatasetImageItem) throws -> LabelmeAnnotation {
        let record = try record(for: item)
        let size = imageSize(for: record.imageEntry)
        var annotation: LabelmeAnnotation
        if fileManager.fileExists(atPath: record.sidecarLabelURL.path) {
            let data = try Data(contentsOf: record.sidecarLabelURL)
            annotation = try JSONDecoder.labelme.decode(LabelmeAnnotation.self, from: data)
        } else if let labelEntry = index.entryByPath[record.labelPathInZip] {
            let data = try ZipArchiveExtractor.data(for: labelEntry, in: zipURL)
            annotation = try JSONDecoder.labelme.decode(LabelmeAnnotation.self, from: data)
        } else {
            annotation = LabelmeAnnotation(
                version: "5.5.0",
                flags: [:],
                shapes: [],
                imagePath: Self.labelImagePath(record.relativePath),
                imageData: nil,
                imageHeight: size.height,
                imageWidth: size.width,
                imageUrl: "zip://\(zipURL.lastPathComponent)/\(record.imageEntry.relativePath)"
            )
        }
        annotation.imagePath = Self.labelImagePath(record.relativePath)
        annotation.imageData = nil
        annotation.imageHeight = annotation.imageHeight > 0 ? annotation.imageHeight : size.height
        annotation.imageWidth = annotation.imageWidth > 0 ? annotation.imageWidth : size.width
        annotation.imageUrl = "zip://\(zipURL.lastPathComponent)/\(record.imageEntry.relativePath)"
        return annotation
    }

    func loadImage(for item: DatasetImageItem) throws -> UIImage {
        let record = try record(for: item)
        let data = try ZipArchiveExtractor.data(for: record.imageEntry, in: zipURL)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }

    func save(_ annotation: LabelmeAnnotation, for item: DatasetImageItem) throws -> LabelmeAnnotation {
        let record = try record(for: item)
        let size = imageSize(for: record.imageEntry)
        var saved = annotation
        saved.imagePath = Self.labelImagePath(record.relativePath)
        saved.imageData = nil
        saved.imageUrl = nil
        saved.imageHeight = size.height
        saved.imageWidth = size.width
        try fileManager.createDirectory(at: record.sidecarLabelURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        let data = try JSONEncoder.labelme.encode(saved)
        try data.write(to: record.sidecarLabelURL, options: [.atomic])
        saved.imageUrl = "zip://\(zipURL.lastPathComponent)/\(record.imageEntry.relativePath)"
        return saved
    }

    func importImages(from urls: [URL]) throws -> [DatasetImageItem] {
        throw LocalDatasetError.readOnlyZipImport
    }

    private func record(for item: DatasetImageItem) throws -> ZipImageRecord {
        if let record = recordByID[item.id] {
            return record
        }
        throw LocalDatasetError.missingImage(item.relativePath)
    }

    private func itemPayload(_ record: ZipImageRecord) -> DatasetImageItem {
        DatasetImageItem(
            id: record.id,
            fileName: (record.relativePath as NSString).lastPathComponent,
            stem: ((record.relativePath as NSString).lastPathComponent as NSString).deletingPathExtension,
            relativePath: record.relativePath,
            labelPath: record.sidecarLabelURL.path,
            imageUrl: "zip://\(zipURL.lastPathComponent)/\(record.imageEntry.relativePath)",
            annotationUrl: record.sidecarLabelURL.absoluteString,
            annotated: isAnnotated(record),
            shapeCount: 0,
            labels: [],
            imageWidth: nil,
            imageHeight: nil,
            updatedAt: nil
        )
    }

    private func isAnnotated(_ record: ZipImageRecord) -> Bool {
        fileManager.fileExists(atPath: record.sidecarLabelURL.path)
            || index.entryByPath[record.labelPathInZip] != nil
    }

    private func imageSize(for entry: ZipArchiveEntry) -> (width: Int, height: Int) {
        guard let data = try? ZipArchiveExtractor.data(for: entry, in: zipURL),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else {
            return (0, 0)
        }
        return (width.intValue, height.intValue)
    }

    private static func imageRecords(in index: ZipArchiveIndex, labelsURL: URL) throws -> [ZipImageRecord] {
        index.entries.compactMap { entry in
            guard !entry.isDirectory, imageExtensions.contains((entry.relativePath as NSString).pathExtension.lowercased()) else {
                return nil
            }
            let parts = entry.relativePath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let imagesIndex = parts.firstIndex(where: { $0.lowercased() == "images" }),
                  imagesIndex < parts.count - 1
            else {
                return nil
            }
            let rootParts = Array(parts[..<imagesIndex])
            let relativeParts = Array(parts[(imagesIndex + 1)...])
            let relativePath = relativeParts.joined(separator: "/")
            let labelRelative = ((relativePath as NSString).deletingPathExtension + ".json")
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            let labelPathInZip = (rootParts + ["labels"] + labelRelative).joined(separator: "/")
            let sidecarLabelURL = childURL(root: labelsURL, relativePath: labelRelative.joined(separator: "/"))
            return ZipImageRecord(
                id: recordID(relativePath),
                imageEntry: entry,
                relativePath: relativePath,
                labelPathInZip: labelPathInZip,
                sidecarLabelURL: sidecarLabelURL
            )
        }
    }

    private static func sidecarName(for url: URL) -> String {
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let modified = ((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0).rounded()
        let raw = "\(url.lastPathComponent)-\(size)-\(Int(modified))"
        return raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func recordID(_ relativePath: String) -> String {
        let data = Data(relativePath.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func labelImagePath(_ relativePath: String) -> String {
        "..\\images\\" + relativePath.replacingOccurrences(of: "/", with: "\\")
    }

    private static func childURL(root: URL, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(root) { partial, component in
                partial.appendingPathComponent(String(component))
            }
    }

    private static let imageExtensions = Set(["jpg", "jpeg", "png", "bmp", "gif", "webp", "tif", "tiff"])
}

private enum LocalDatasetError: LocalizedError {
    case notDirectory(String)
    case noImages(String)
    case noAppDocumentsDataset(String)
    case missingImage(String)
    case invalidZip(String)
    case unsupportedZipEntry(String)
    case unsupportedImage(String)
    case readOnlyZipImport

    var errorDescription: String? {
        switch self {
        case .notDirectory(let path):
            "\(path) is not a folder."
        case .noImages(let path):
            "No supported image files found in \(path)."
        case .noAppDocumentsDataset(let path):
            "No dataset found in app Documents. Put a dataset folder with images/ and labels/ into \(path), then tap Docs."
        case .missingImage(let path):
            "Image not found in local dataset: \(path)"
        case .invalidZip(let message):
            "Invalid zip: \(message)"
        case .unsupportedZipEntry(let message):
            "Unsupported zip entry: \(message)"
        case .unsupportedImage(let filename):
            "Unsupported image file: \(filename)"
        case .readOnlyZipImport:
            "Zip datasets are read-only. Open or import a folder dataset to add images."
        }
    }
}

private extension URL {
    var deletingLastPathComponentIfPossible: URL? {
        let parent = deletingLastPathComponent()
        return parent == self ? nil : parent
    }
}

private enum LocalDatasetCopyImporter {
    static func copyToApplicationSupport(from pickedURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let sourceURL = pickedURL.standardizedFileURL
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LocalDatasetError.notDirectory(sourceURL.path)
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let importsURL = applicationSupportURL.appendingPathComponent("ImportedDatasets", isDirectory: true)
        try fileManager.createDirectory(at: importsURL, withIntermediateDirectories: true, attributes: nil)

        let destinationName = [
            sanitizedName(sourceURL.lastPathComponent),
            "\(Int(Date().timeIntervalSince1970))",
            String(UUID().uuidString.prefix(8)),
        ].joined(separator: "-")
        let destinationURL = importsURL.appendingPathComponent(destinationName, isDirectory: true)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private static func sanitizedName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Dataset" : cleaned
    }
}

private enum LocalDatasetRootFinder {
    static func preferredDatasetRoot(in containerURL: URL, missingError: LocalDatasetError) throws -> URL {
        let fileManager = FileManager.default
        var candidates = [containerURL]
        let childDirectories = (try? fileManager.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))?
            .filter { url in
                guard url.lastPathComponent != "__MACOSX" else { return false }
                return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending } ?? []
        candidates.append(contentsOf: childDirectories)

        for candidate in candidates {
            let imagesURL = candidate.appendingPathComponent("images", isDirectory: true)
            if isDirectory(imagesURL, fileManager: fileManager), containsImageFiles(in: imagesURL, fileManager: fileManager) {
                return candidate
            }
            if candidate.lastPathComponent.lowercased() == "images", containsImageFiles(in: candidate, fileManager: fileManager) {
                return candidate.deletingLastPathComponent()
            }
        }

        for candidate in candidates where containsImageFiles(in: candidate, fileManager: fileManager) {
            return candidate
        }

        throw missingError
    }

    private static func containsImageFiles(in url: URL, fileManager: FileManager) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        for case let fileURL as URL in enumerator {
            guard imageExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                return true
            }
        }
        return false
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static let imageExtensions = Set(["jpg", "jpeg", "png", "bmp", "gif", "webp", "tif", "tiff"])
}

private enum LocalZipDatasetImporter {
    static func importZip(from pickedURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let sourceURL = pickedURL.standardizedFileURL
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw LocalDatasetError.invalidZip(sourceURL.path)
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let importsURL = applicationSupportURL.appendingPathComponent("ImportedZipDatasets", isDirectory: true)
        try fileManager.createDirectory(at: importsURL, withIntermediateDirectories: true, attributes: nil)

        let destinationName = [
            sanitizedName(sourceURL.deletingPathExtension().lastPathComponent),
            "\(Int(Date().timeIntervalSince1970))",
            String(UUID().uuidString.prefix(8)),
        ].joined(separator: "-")
        let destinationURL = importsURL.appendingPathComponent(destinationName, isDirectory: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

        do {
            try ZipArchiveExtractor.extract(zipURL: sourceURL, to: destinationURL)
            return try LocalDatasetRootFinder.preferredDatasetRoot(
                in: destinationURL,
                missingError: .noImages(destinationURL.path)
            )
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    private static func sanitizedName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Dataset" : cleaned
    }
}

private struct ZipArchiveEntry {
    let relativePath: String
    let isDirectory: Bool
    let compressionMethod: UInt16
    let compressedSize: UInt64
    let uncompressedSize: UInt64
    let localHeaderOffset: UInt64
}

private struct ZipArchiveIndex {
    let zipURL: URL
    let entries: [ZipArchiveEntry]
    let entryByPath: [String: ZipArchiveEntry]
}

private enum ZipArchiveExtractor {
    private struct EntryPath {
        let relativePath: String
        let isDirectory: Bool
    }

    static func index(zipURL: URL) throws -> ZipArchiveIndex {
        let fileHandle = try FileHandle(forReadingFrom: zipURL)
        defer { try? fileHandle.close() }

        let fileSize = try fileHandle.seekToEnd()
        let eocdOffset = try endOfCentralDirectoryOffset(in: fileHandle, fileSize: fileSize)
        let eocd = try readData(from: fileHandle, offset: eocdOffset, count: 22)

        guard try eocd.uint16LE(at: 0) == 0x4b50,
              try eocd.uint16LE(at: 2) == 0x0605
        else {
            throw LocalDatasetError.invalidZip("end of central directory is corrupt")
        }

        let diskNumber = try eocd.uint16LE(at: 4)
        let centralDirectoryDisk = try eocd.uint16LE(at: 6)
        let entryCountOnDisk = try eocd.uint16LE(at: 8)
        let totalEntryCount = try eocd.uint16LE(at: 10)
        let centralDirectorySize32 = try eocd.uint32LE(at: 12)
        let centralDirectoryOffset32 = try eocd.uint32LE(at: 16)

        guard diskNumber == 0, centralDirectoryDisk == 0, entryCountOnDisk == totalEntryCount else {
            throw LocalDatasetError.unsupportedZipEntry("multi-disk zip archives are not supported")
        }
        guard totalEntryCount != UInt16.max,
              centralDirectorySize32 != UInt32.max,
              centralDirectoryOffset32 != UInt32.max
        else {
            throw LocalDatasetError.unsupportedZipEntry("ZIP64 archives are not supported")
        }

        let centralDirectorySize = UInt64(centralDirectorySize32)
        let centralDirectoryOffset = UInt64(centralDirectoryOffset32)
        guard centralDirectoryOffset <= fileSize,
              centralDirectorySize <= fileSize - centralDirectoryOffset,
              centralDirectorySize <= UInt64(Int.max)
        else {
            throw LocalDatasetError.invalidZip("central directory is outside the file")
        }

        let centralDirectory = try readData(
            from: fileHandle,
            offset: centralDirectoryOffset,
            count: Int(centralDirectorySize)
        )

        var entries: [ZipArchiveEntry] = []
        var cursor = 0
        for _ in 0..<Int(totalEntryCount) {
            guard try centralDirectory.uint32LE(at: cursor) == 0x0201_4b50 else {
                throw LocalDatasetError.invalidZip("central directory entry is corrupt")
            }

            let flags = try centralDirectory.uint16LE(at: cursor + 8)
            let compressionMethod = try centralDirectory.uint16LE(at: cursor + 10)
            let compressedSize32 = try centralDirectory.uint32LE(at: cursor + 20)
            let uncompressedSize32 = try centralDirectory.uint32LE(at: cursor + 24)
            let fileNameLength = Int(try centralDirectory.uint16LE(at: cursor + 28))
            let extraLength = Int(try centralDirectory.uint16LE(at: cursor + 30))
            let commentLength = Int(try centralDirectory.uint16LE(at: cursor + 32))
            let localHeaderOffset32 = try centralDirectory.uint32LE(at: cursor + 42)

            guard compressedSize32 != UInt32.max,
                  uncompressedSize32 != UInt32.max,
                  localHeaderOffset32 != UInt32.max
            else {
                throw LocalDatasetError.unsupportedZipEntry("ZIP64 archives are not supported")
            }

            let nameStart = cursor + 46
            let nameEnd = nameStart + fileNameLength
            guard nameEnd <= centralDirectory.count else {
                throw LocalDatasetError.invalidZip("entry name is outside the file")
            }

            let nameData = centralDirectory.subdata(in: nameStart..<nameEnd)
            let rawName = String(data: nameData, encoding: .utf8)
                ?? String(decoding: nameData, as: UTF8.self)
            let entryPath = try safeEntryPath(rawName)
            cursor = nameEnd + extraLength + commentLength

            guard let entryPath else { continue }
            if flags & 0x0001 != 0 {
                throw LocalDatasetError.unsupportedZipEntry("\(entryPath.relativePath) is encrypted")
            }

            entries.append(ZipArchiveEntry(
                relativePath: entryPath.relativePath,
                isDirectory: entryPath.isDirectory,
                compressionMethod: compressionMethod,
                compressedSize: UInt64(compressedSize32),
                uncompressedSize: UInt64(uncompressedSize32),
                localHeaderOffset: UInt64(localHeaderOffset32)
            ))
        }

        var entryByPath: [String: ZipArchiveEntry] = [:]
        for entry in entries {
            entryByPath[entry.relativePath] = entry
        }
        return ZipArchiveIndex(zipURL: zipURL, entries: entries, entryByPath: entryByPath)
    }

    static func data(for entry: ZipArchiveEntry, in zipURL: URL) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: zipURL)
        defer { try? fileHandle.close() }
        let fileSize = try fileHandle.seekToEnd()
        let compressedData = try compressedPayload(
            in: fileHandle,
            fileSize: fileSize,
            localHeaderOffset: entry.localHeaderOffset,
            compressedSize: entry.compressedSize
        )
        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            guard entry.uncompressedSize <= UInt64(Int.max) else {
                throw LocalDatasetError.unsupportedZipEntry("\(entry.relativePath) is too large to extract")
            }
            return try inflateRawDeflate(compressedData, expectedSize: Int(entry.uncompressedSize))
        default:
            throw LocalDatasetError.unsupportedZipEntry("\(entry.relativePath) uses compression method \(entry.compressionMethod)")
        }
    }

    static func extract(zipURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let fileHandle = try FileHandle(forReadingFrom: zipURL)
        defer { try? fileHandle.close() }

        let fileSize = try fileHandle.seekToEnd()
        let eocdOffset = try endOfCentralDirectoryOffset(in: fileHandle, fileSize: fileSize)
        let eocd = try readData(from: fileHandle, offset: eocdOffset, count: 22)

        guard try eocd.uint16LE(at: 0) == 0x4b50,
              try eocd.uint16LE(at: 2) == 0x0605
        else {
            throw LocalDatasetError.invalidZip("end of central directory is corrupt")
        }

        let diskNumber = try eocd.uint16LE(at: 4)
        let centralDirectoryDisk = try eocd.uint16LE(at: 6)
        let entryCountOnDisk = try eocd.uint16LE(at: 8)
        let totalEntryCount = try eocd.uint16LE(at: 10)
        let centralDirectorySize32 = try eocd.uint32LE(at: 12)
        let centralDirectoryOffset32 = try eocd.uint32LE(at: 16)

        guard diskNumber == 0, centralDirectoryDisk == 0, entryCountOnDisk == totalEntryCount else {
            throw LocalDatasetError.unsupportedZipEntry("multi-disk zip archives are not supported")
        }
        guard totalEntryCount != UInt16.max,
              centralDirectorySize32 != UInt32.max,
              centralDirectoryOffset32 != UInt32.max
        else {
            throw LocalDatasetError.unsupportedZipEntry("ZIP64 archives are not supported")
        }

        let entryCount = Int(totalEntryCount)
        let centralDirectorySize = UInt64(centralDirectorySize32)
        let centralDirectoryOffset = UInt64(centralDirectoryOffset32)

        guard centralDirectoryOffset <= fileSize,
              centralDirectorySize <= fileSize - centralDirectoryOffset,
              centralDirectorySize <= UInt64(Int.max)
        else {
            throw LocalDatasetError.invalidZip("central directory is outside the file")
        }

        let centralDirectory = try readData(
            from: fileHandle,
            offset: centralDirectoryOffset,
            count: Int(centralDirectorySize)
        )

        var cursor = 0
        for _ in 0..<entryCount {
            guard try centralDirectory.uint32LE(at: cursor) == 0x0201_4b50 else {
                throw LocalDatasetError.invalidZip("central directory entry is corrupt")
            }

            let flags = try centralDirectory.uint16LE(at: cursor + 8)
            let compressionMethod = try centralDirectory.uint16LE(at: cursor + 10)
            let compressedSize32 = try centralDirectory.uint32LE(at: cursor + 20)
            let uncompressedSize32 = try centralDirectory.uint32LE(at: cursor + 24)
            let fileNameLength = Int(try centralDirectory.uint16LE(at: cursor + 28))
            let extraLength = Int(try centralDirectory.uint16LE(at: cursor + 30))
            let commentLength = Int(try centralDirectory.uint16LE(at: cursor + 32))
            let localHeaderOffset32 = try centralDirectory.uint32LE(at: cursor + 42)

            guard compressedSize32 != UInt32.max,
                  uncompressedSize32 != UInt32.max,
                  localHeaderOffset32 != UInt32.max
            else {
                throw LocalDatasetError.unsupportedZipEntry("ZIP64 archives are not supported")
            }

            let nameStart = cursor + 46
            let nameEnd = nameStart + fileNameLength
            guard nameEnd <= centralDirectory.count else {
                throw LocalDatasetError.invalidZip("entry name is outside the file")
            }

            let nameData = centralDirectory.subdata(in: nameStart..<nameEnd)
            let rawName = String(data: nameData, encoding: .utf8)
                ?? String(decoding: nameData, as: UTF8.self)
            let entryPath = try safeEntryPath(rawName)
            cursor = nameEnd + extraLength + commentLength

            guard let entryPath else { continue }
            if flags & 0x0001 != 0 {
                throw LocalDatasetError.unsupportedZipEntry("\(entryPath.relativePath) is encrypted")
            }

            try autoreleasepool {
                let targetURL = destinationURL.appendingPathComponent(entryPath.relativePath)
                if entryPath.isDirectory {
                    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
                    return
                }

                let compressedSize = UInt64(compressedSize32)
                let uncompressedSize = UInt64(uncompressedSize32)
                let compressedData = try compressedPayload(
                    in: fileHandle,
                    fileSize: fileSize,
                    localHeaderOffset: UInt64(localHeaderOffset32),
                    compressedSize: compressedSize
                )
                let outputData: Data
                switch compressionMethod {
                case 0:
                    outputData = compressedData
                case 8:
                    guard uncompressedSize <= UInt64(Int.max) else {
                        throw LocalDatasetError.unsupportedZipEntry("\(entryPath.relativePath) is too large to extract")
                    }
                    outputData = try inflateRawDeflate(compressedData, expectedSize: Int(uncompressedSize))
                default:
                    throw LocalDatasetError.unsupportedZipEntry("\(entryPath.relativePath) uses compression method \(compressionMethod)")
                }

                guard UInt64(outputData.count) == uncompressedSize else {
                    throw LocalDatasetError.invalidZip("\(entryPath.relativePath) has an unexpected uncompressed size")
                }

                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try outputData.write(to: targetURL, options: [.atomic])
            }
        }
    }

    private static func endOfCentralDirectoryOffset(in fileHandle: FileHandle, fileSize: UInt64) throws -> UInt64 {
        guard fileSize >= 22 else {
            throw LocalDatasetError.invalidZip("file is too small")
        }

        let tailSize = min(fileSize, UInt64(65_557))
        let tailOffset = fileSize - tailSize
        let tail = try readData(from: fileHandle, offset: tailOffset, count: Int(tailSize))

        var offset = tail.count - 22
        while offset >= 0 {
            if (try? tail.uint32LE(at: offset)) == 0x0605_4b50 {
                let commentLength = Int(try tail.uint16LE(at: offset + 20))
                if tailOffset + UInt64(offset + 22 + commentLength) == fileSize {
                    return tailOffset + UInt64(offset)
                }
            }
            offset -= 1
        }
        throw LocalDatasetError.invalidZip("end of central directory was not found")
    }

    private static func compressedPayload(
        in fileHandle: FileHandle,
        fileSize: UInt64,
        localHeaderOffset: UInt64,
        compressedSize: UInt64
    ) throws -> Data {
        guard localHeaderOffset <= fileSize,
              30 <= fileSize - localHeaderOffset
        else {
            throw LocalDatasetError.invalidZip("local file header is corrupt")
        }

        let header = try readData(from: fileHandle, offset: localHeaderOffset, count: 30)
        guard try header.uint32LE(at: 0) == 0x0403_4b50 else {
            throw LocalDatasetError.invalidZip("local file header is corrupt")
        }

        let fileNameLength = UInt64(try header.uint16LE(at: 26))
        let extraLength = UInt64(try header.uint16LE(at: 28))
        let payloadStart = localHeaderOffset + 30 + fileNameLength + extraLength
        guard payloadStart <= fileSize,
              compressedSize <= fileSize - payloadStart,
              compressedSize <= UInt64(Int.max)
        else {
            throw LocalDatasetError.invalidZip("compressed payload is outside the file")
        }
        return try readData(from: fileHandle, offset: payloadStart, count: Int(compressedSize))
    }

    private static func readData(from fileHandle: FileHandle, offset: UInt64, count: Int) throws -> Data {
        guard count >= 0 else {
            throw LocalDatasetError.invalidZip("negative read size")
        }
        try fileHandle.seek(toOffset: offset)
        let data = try fileHandle.read(upToCount: count) ?? Data()
        guard data.count == count else {
            throw LocalDatasetError.invalidZip("unexpected end of file")
        }
        return data
    }

    private static func safeEntryPath(_ rawName: String) throws -> EntryPath? {
        let normalized = rawName.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else {
            throw LocalDatasetError.invalidZip("absolute paths are not allowed")
        }

        let isDirectory = normalized.hasSuffix("/")
        let parts = normalized
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !parts.isEmpty else { return nil }
        guard parts.first != "__MACOSX", parts.last != ".DS_Store" else { return nil }

        for part in parts {
            guard part != "." && part != ".." else {
                throw LocalDatasetError.invalidZip("relative path traversal is not allowed")
            }
        }

        return EntryPath(relativePath: parts.joined(separator: "/"), isDirectory: isDirectory)
    }

    private static func inflateRawDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize >= 0 else {
            throw LocalDatasetError.invalidZip("negative uncompressed size")
        }
        guard expectedSize > 0 else { return Data() }

        var output = Data(count: expectedSize)
        let inputCount = data.count
        let outputCount = output.count
        let result: Int32 = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                guard let inputBase = inputBuffer.bindMemory(to: Bytef.self).baseAddress,
                      let outputBase = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                else {
                    return Z_MEM_ERROR
                }

                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBase)
                stream.avail_in = uInt(inputCount)
                stream.next_out = outputBase
                stream.avail_out = uInt(outputCount)

                let initResult = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard initResult == Z_OK else { return initResult }
                defer { inflateEnd(&stream) }

                let inflateResult = inflate(&stream, Z_FINISH)
                guard inflateResult == Z_STREAM_END else { return inflateResult }
                guard Int(stream.total_out) == expectedSize else { return Z_DATA_ERROR }
                return Z_OK
            }
        }

        guard result == Z_OK else {
            throw LocalDatasetError.invalidZip("deflate decompression failed with zlib code \(result)")
        }
        return output
    }
}

private extension Data {
    func uint16LE(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw LocalDatasetError.invalidZip("unexpected end of file")
        }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw LocalDatasetError.invalidZip("unexpected end of file")
        }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}

private enum LocalAppDocumentsDatasetFinder {
    static func preferredDataset() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try LocalDatasetRootFinder.preferredDatasetRoot(
            in: documentsURL,
            missingError: .noAppDocumentsDataset(documentsURL.path)
        )
    }
}

@MainActor
final class DatasetStore: ObservableObject {
    @AppStorage("serverBaseURL") var serverBaseURL = "http://127.0.0.1:8765"
    @AppStorage("cloudflareAccessClientId") var cloudflareAccessClientId = ""
    @AppStorage("cloudflareAccessClientSecret") var cloudflareAccessClientSecret = ""

    @Published var health: ServerHealth?
    @Published var items: [DatasetImageItem] = []
    @Published var selectedItem: DatasetImageItem?
    @Published var annotation: LabelmeAnnotation?
    @Published var image: UIImage?
    @Published var selectedShapeID: UUID?
    @Published var selectedShapeIDs = Set<UUID>()
    @Published var tool: CanvasTool = .edit
    @Published var currentLabel = "pet"
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var statusMessage = "Disconnected"
    @Published var isLoading = false
    @Published var isTestingConnection = false
    @Published var isSaving = false
    @Published var isUploading = false
    @Published var isDirty = false
    @Published var showsLabels = true
    @Published var fillsShapes = true
    @AppStorage("polygonFillOpacity") var polygonFillOpacity = 0.20
    @Published var imageBrightness = ImageAdjustmentDefaults.neutral
    @Published var imageContrast = ImageAdjustmentDefaults.neutral
    @Published var keepsPreviousShapes = false
    @Published var copiedShapes: [LabelmeShape] = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var lastSavedAnnotation: LabelmeAnnotation?
    private var historyBaseline: EditHistoryState?
    private var undoStack: [EditHistoryState] = []
    private var redoStack: [EditHistoryState] = []
    private var undoGroupingDepth = 0
    private var undoGroupStart: EditHistoryState?
    private var imageAdjustments: [String: ImageAdjustmentState] = [:]
    private var localDataset: LocalDatasetProviding?
    private let maxHistoryDepth = 120
    private var client: LabelmeAPI? {
        try? LabelmeAPI(
            baseURLString: serverBaseURL,
            cloudflareAccess: CloudflareAccessCredentials(
                clientId: cloudflareAccessClientId.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: cloudflareAccessClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    private struct ImageAdjustmentState {
        var brightness: Double
        var contrast: Double

        var isNeutral: Bool {
            abs(brightness - ImageAdjustmentDefaults.neutral) < 0.005
                && abs(contrast - ImageAdjustmentDefaults.neutral) < 0.005
        }

        static let neutral = ImageAdjustmentState(
            brightness: ImageAdjustmentDefaults.neutral,
            contrast: ImageAdjustmentDefaults.neutral
        )
    }

    private struct EditHistoryState: Equatable {
        var annotation: LabelmeAnnotation
        var selectedShapeID: UUID?
        var selectedShapeIDs: Set<UUID>
        var currentLabel: String
    }

    var filteredItems: [DatasetImageItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.fileName.lowercased().contains(query)
                || item.relativePath.lowercased().contains(query)
                || item.labels.contains { $0.lowercased().contains(query) }
        }
    }

    var selectedShape: LabelmeShape? {
        guard let selectedShapeID, let annotation else { return nil }
        return annotation.shapes.first { $0.id == selectedShapeID }
    }

    var selectedShapes: [LabelmeShape] {
        guard let annotation else { return [] }
        let ids = selectedShapeIDs.isEmpty ? Set([selectedShapeID].compactMap { $0 }) : selectedShapeIDs
        return annotation.shapes.filter { ids.contains($0.id) }
    }

    var canPasteShapes: Bool {
        annotation != nil && !copiedShapes.isEmpty
    }

    var canConnectSelectedPolygons: Bool {
        let shapes = selectedShapes
        guard shapes.count == 2 else { return false }
        guard shapes.allSatisfy({ $0.shapeType == .polygon && !$0.label.isEmpty }) else { return false }
        return shapes[0].label == shapes[1].label
    }

    var canSubtractOverlappingPolygons: Bool {
        selectedShapes.filter { $0.shapeType == .polygon && $0.points.count >= 3 }.count >= 2
    }

    var hasImageAdjustment: Bool {
        !ImageAdjustmentState(brightness: imageBrightness, contrast: imageContrast).isNeutral
    }

    var currentDatasetDirectory: String {
        let root = health?.datasetRoot.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return root.isEmpty ? "No dataset" : root
    }

    var recentLabels: [String] {
        var seen = Set<String>()
        let annotationLabels = annotation?.shapes.map(\.label) ?? []
        let imageLabels = items.flatMap(\.labels)
        return ([currentLabel] + annotationLabels + imageLabels)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(16)
            .map { $0 }
    }

    func connect() async {
        guard let client else {
            errorMessage = "Invalid server URL"
            return
        }
        if isDirty {
            await save()
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let health = try await client.health()
            let response = try await client.allImages(query: "")
            localDataset = nil
            resetDatasetState()
            self.health = health
            items = response.items
            statusMessage = "\(response.total) images / \(health.annotatedCount) annotated"
            if let first = items.first {
                await select(first)
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Disconnected"
        }
    }

    func testConnection() async {
        guard let client else {
            errorMessage = "Invalid server URL"
            statusMessage = "Disconnected"
            return
        }
        isTestingConnection = true
        defer { isTestingConnection = false }
        do {
            let health = try await client.health()
            self.health = health
            statusMessage = "Server OK: \(health.imageCount) images / \(health.annotatedCount) annotated"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Connection failed"
        }
    }

    func openLocalDataset(at url: URL) async {
        if isDirty {
            await save()
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let dataset = try LocalLabelmeDataset(rootURL: url)
            let response = try dataset.images(query: "")
            localDataset = dataset
            resetDatasetState()
            health = dataset.health()
            items = response.items
            statusMessage = "Local: \(response.total) images / \(health?.annotatedCount ?? 0) annotated"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Local dataset failed"
        }
    }

    func importLocalDatasetCopy(at url: URL) async {
        if isDirty {
            await save()
        }
        isLoading = true
        statusMessage = "Importing local dataset..."
        defer { isLoading = false }
        do {
            let copiedURL = try await Task.detached(priority: .userInitiated) {
                try LocalDatasetCopyImporter.copyToApplicationSupport(from: url)
            }.value
            let dataset = try LocalLabelmeDataset(rootURL: copiedURL)
            let response = try dataset.images(query: "")
            localDataset = dataset
            resetDatasetState()
            health = dataset.health()
            items = response.items
            statusMessage = "Imported: \(response.total) images / \(health?.annotatedCount ?? 0) annotated"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Local import failed"
        }
    }

    func importZipDataset(at url: URL) async {
        if isDirty {
            await save()
        }
        isLoading = true
        statusMessage = "Importing zip..."
        defer { isLoading = false }
        do {
            let dataset = try await Task.detached(priority: .userInitiated) {
                try ZipLabelmeDataset(zipURL: url)
            }.value
            let response = try dataset.images(query: "")
            localDataset = dataset
            resetDatasetState()
            health = dataset.health()
            items = response.items
            statusMessage = "Zip index: \(response.total) images / \(health?.annotatedCount ?? 0) annotated"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Zip import failed"
        }
    }

    func openAppDocumentsDataset() async {
        do {
            let url = try LocalAppDocumentsDatasetFinder.preferredDataset()
            await openLocalDataset(at: url)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "App Documents dataset failed"
        }
    }

    func refreshList() async {
        if let localDataset {
            do {
                let response = try localDataset.images(query: searchText)
                health = localDataset.health()
                items = response.items
                statusMessage = "Local: \(response.total) images"
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard let client else { return }
        do {
            let response = try await client.allImages(query: searchText)
            items = response.items
            statusMessage = "\(response.total) images"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadImages(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        if isDirty {
            await save()
        }
        let scopedURLs = urls.map { url in
            (url, url.startAccessingSecurityScopedResource())
        }
        defer {
            scopedURLs.forEach { url, accessed in
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        isUploading = true
        statusMessage = "Uploading \(urls.count) image\(urls.count == 1 ? "" : "s")..."
        defer { isUploading = false }
        do {
            let uploaded: [DatasetImageItem]
            if let localDataset {
                uploaded = try localDataset.importImages(from: urls)
            } else {
                guard let client else {
                    throw URLError(.badURL)
                }
                uploaded = try await client.uploadImages(from: urls).items
            }
            await refreshList()
            statusMessage = "Added \(uploaded.count) image\(uploaded.count == 1 ? "" : "s")"
            if let first = uploaded.first,
               let current = items.first(where: { $0.id == first.id }) ?? items.first(where: { $0.relativePath == first.relativePath }) {
                await select(current)
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Image upload failed"
        }
    }

    func select(_ item: DatasetImageItem) async {
        if isDirty {
            await save()
        }
        let previousShapes = annotation?.shapes ?? []
        selectedItem = item
        restoreImageAdjustment(for: item)
        selectedShapeID = nil
        selectedShapeIDs.removeAll()
        image = nil
        annotation = nil
        resetUndoHistory()
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded: (LabelmeAnnotation, UIImage)
            if let localDataset {
                loaded = (
                    try localDataset.annotation(for: item),
                    try localDataset.loadImage(for: item)
                )
            } else {
                guard let client else { return }
                async let loadedAnnotation = client.annotation(for: item)
                async let loadedImage = client.loadImage(for: item)
                loaded = try await (loadedAnnotation, loadedImage)
            }
            var (annotation, image) = loaded
            let savedAnnotation = annotation
            if keepsPreviousShapes, annotation.shapes.isEmpty, !previousShapes.isEmpty {
                annotation.shapes = previousShapes.map { shape in
                    var copy = shape
                    copy.id = UUID()
                    return copy
                }
            }
            self.annotation = annotation
            self.lastSavedAnnotation = savedAnnotation
            self.image = image
            currentLabel = annotation.shapes.first?.label ?? currentLabel
            updateLoadedItemSummary(item, annotation: annotation, image: image)
            isDirty = annotation != savedAnnotation
            resetUndoHistory()
            statusMessage = item.relativePath
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLoadedItemSummary(_ item: DatasetImageItem, annotation: LabelmeAnnotation, image: UIImage) {
        var seen = Set<String>()
        let labels = annotation.shapes
            .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted()
        let pixelWidth = image.cgImage?.width ?? annotation.imageWidth
        let pixelHeight = image.cgImage?.height ?? annotation.imageHeight
        let updated = DatasetImageItem(
            id: item.id,
            fileName: item.fileName,
            stem: item.stem,
            relativePath: item.relativePath,
            labelPath: item.labelPath,
            imageUrl: item.imageUrl,
            annotationUrl: item.annotationUrl,
            annotated: item.annotated || !annotation.shapes.isEmpty,
            shapeCount: annotation.shapes.count,
            labels: labels,
            imageWidth: pixelWidth > 0 ? pixelWidth : item.imageWidth,
            imageHeight: pixelHeight > 0 ? pixelHeight : item.imageHeight,
            updatedAt: item.updatedAt
        )

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updated
        }
        selectedItem = updated
    }

    func save() async {
        guard let selectedItem, let annotation else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved: LabelmeAnnotation
            if let localDataset {
                saved = try localDataset.save(annotation, for: selectedItem)
            } else {
                guard let client else { return }
                saved = try await client.save(annotation, for: selectedItem)
            }
            self.annotation = saved
            self.lastSavedAnnotation = saved
            isDirty = false
            syncHistoryBaseline()
            statusMessage = "Saved \(selectedItem.fileName)"
            await refreshList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPrevious() async {
        guard let selectedItem, let index = filteredItems.firstIndex(of: selectedItem), index > 0 else { return }
        await select(filteredItems[index - 1])
    }

    func selectNext() async {
        guard let selectedItem, let index = filteredItems.firstIndex(of: selectedItem), index < filteredItems.count - 1 else { return }
        await select(filteredItems[index + 1])
    }

    func setImageBrightness(_ value: Double) {
        imageBrightness = Self.clampedImageAdjustment(value)
        rememberImageAdjustment()
    }

    func setImageContrast(_ value: Double) {
        imageContrast = Self.clampedImageAdjustment(value)
        rememberImageAdjustment()
    }

    func resetImageAdjustment() {
        imageBrightness = ImageAdjustmentDefaults.neutral
        imageContrast = ImageAdjustmentDefaults.neutral
        rememberImageAdjustment()
    }

    func toggleKeepPreviousShapes() {
        keepsPreviousShapes.toggle()
        statusMessage = keepsPreviousShapes ? "Keep Prev Mode: On" : "Keep Prev Mode: Off"
    }

    func closeCurrentFile() {
        selectedItem = nil
        annotation = nil
        image = nil
        selectedShapeID = nil
        selectedShapeIDs.removeAll()
        resetUndoHistory()
        isDirty = false
        statusMessage = "Closed"
    }

    private func resetDatasetState() {
        selectedItem = nil
        annotation = nil
        image = nil
        selectedShapeID = nil
        selectedShapeIDs.removeAll()
        lastSavedAnnotation = nil
        imageAdjustments.removeAll()
        resetUndoHistory()
        isDirty = false
    }

    func reportUnsupportedShortcut(_ action: ShortcutAction) {
        errorMessage = "\(action.title) is not available in the iPad version."
    }

    func addShape(_ shape: LabelmeShape) {
        guard annotation != nil else { return }
        annotation?.shapes.append(shape)
        selectedShapeID = shape.id
        selectedShapeIDs = [shape.id]
        currentLabel = shape.label
        markDirty()
    }

    func replaceShape(_ shape: LabelmeShape) {
        guard let index = annotation?.shapes.firstIndex(where: { $0.id == shape.id }) else { return }
        annotation?.shapes[index] = shape
        selectedShapeID = shape.id
        if selectedShapeIDs.isEmpty {
            selectedShapeIDs = [shape.id]
        }
        markDirty()
    }

    func deleteSelectedShape() {
        let ids = selectedIDsForAction()
        guard !ids.isEmpty else { return }
        annotation?.shapes.removeAll { ids.contains($0.id) }
        selectedShapeID = annotation?.shapes.last?.id
        selectedShapeIDs = selectedShapeID.map { Set([$0]) } ?? []
        markDirty()
    }

    func duplicateSelectedShape() {
        let copies = selectedShapes.map { $0.copyForPaste(offset: 12) }
        guard !copies.isEmpty, annotation != nil else { return }
        annotation?.shapes.append(contentsOf: copies)
        selectedShapeID = copies.last?.id
        selectedShapeIDs = Set(copies.map(\.id))
        if let label = copies.last?.label {
            currentLabel = label
        }
        markDirty()
    }

    func reorderShape(draggedID: UUID, before targetID: UUID?) {
        guard var shapes = annotation?.shapes,
              let sourceIndex = shapes.firstIndex(where: { $0.id == draggedID })
        else { return }
        if targetID == draggedID {
            return
        }

        let original = shapes
        let moved = shapes.remove(at: sourceIndex)
        let destinationIndex: Int
        if let targetID, let targetIndex = shapes.firstIndex(where: { $0.id == targetID }) {
            destinationIndex = targetIndex
        } else {
            destinationIndex = shapes.endIndex
        }

        shapes.insert(moved, at: destinationIndex)
        guard shapes != original else { return }
        annotation?.shapes = shapes
        selectedShapeID = moved.id
        selectedShapeIDs = [moved.id]
        currentLabel = moved.label
        markDirty()
    }

    func copySelectedShape() {
        let shapes = selectedShapes
        guard !shapes.isEmpty else { return }
        copiedShapes = shapes
        statusMessage = "Copied \(shapes.count) shape\(shapes.count == 1 ? "" : "s")"
    }

    func pasteShapes() {
        guard annotation != nil, !copiedShapes.isEmpty else { return }
        let pasted = copiedShapes.map { $0.copyForPaste(offset: 18) }
        annotation?.shapes.append(contentsOf: pasted)
        selectedShapeID = pasted.last?.id
        selectedShapeIDs = Set(pasted.map(\.id))
        if let label = pasted.last?.label {
            currentLabel = label
        }
        markDirty()
    }

    func selectShape(_ shape: LabelmeShape, extending: Bool = false) {
        selectedShapeID = shape.id
        if extending {
            if selectedShapeIDs.contains(shape.id) {
                selectedShapeIDs.remove(shape.id)
            } else {
                selectedShapeIDs.insert(shape.id)
            }
            if selectedShapeIDs.isEmpty {
                selectedShapeID = nil
            }
        } else {
            selectedShapeIDs = [shape.id]
        }
        currentLabel = shape.label
        syncHistoryBaselineIfAnnotationUnchanged()
    }

    func selectAllShapes() {
        guard let annotation else { return }
        selectedShapeIDs = Set(annotation.shapes.map(\.id))
        selectedShapeID = annotation.shapes.last?.id
        syncHistoryBaselineIfAnnotationUnchanged()
    }

    func setShapeSelected(_ shape: LabelmeShape, selected: Bool) {
        if selected {
            selectedShapeIDs.insert(shape.id)
            selectedShapeID = shape.id
            currentLabel = shape.label
        } else {
            selectedShapeIDs.remove(shape.id)
            if selectedShapeID == shape.id {
                selectedShapeID = selectedShapeIDs.first
            }
        }
        syncHistoryBaselineIfAnnotationUnchanged()
    }

    func clearShapeSelection() {
        selectedShapeID = nil
        selectedShapeIDs.removeAll()
        syncHistoryBaselineIfAnnotationUnchanged()
    }

    func updateSelectedShapeLabel(_ label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ids = selectedIDsForAction()
        guard !ids.isEmpty else { return }
        annotation?.shapes = annotation?.shapes.map { shape in
            guard ids.contains(shape.id) else { return shape }
            var updated = shape
            updated.label = trimmed
            return updated
        } ?? []
        currentLabel = trimmed
        markDirty()
    }

    func updateShapeLabel(id: UUID, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, annotation != nil else { return }
        annotation?.shapes = annotation?.shapes.map { shape in
            guard shape.id == id else { return shape }
            var updated = shape
            updated.label = trimmed
            return updated
        } ?? []
        currentLabel = trimmed
        if selectedShapeIDs.contains(id) || selectedShapeID == id {
            selectedShapeID = id
        }
        markDirty()
    }

    func updateSelectedShapeType(_ shapeType: LabelmeShapeType) {
        guard var shape = selectedShape else { return }
        shape.shapeType = shapeType
        replaceShape(shape)
    }

    func toggleSelectedShapeVisibility() {
        setSelectedShapeVisibility(nil)
    }

    func toggleShapeVisibility(id: UUID) {
        guard var annotation else { return }
        annotation.shapes = annotation.shapes.map { shape in
            guard shape.id == id else { return shape }
            var updated = shape
            updated.isVisible.toggle()
            return updated
        }
        self.annotation = annotation
    }

    func setSelectedShapeVisibility(_ visible: Bool?) {
        let ids = selectedIDsForAction()
        guard !ids.isEmpty else { return }
        guard var annotation else { return }
        annotation.shapes = annotation.shapes.map { shape in
            guard ids.contains(shape.id) else { return shape }
            var updated = shape
            updated.isVisible = visible ?? !shape.isVisible
            return updated
        }
        self.annotation = annotation
    }

    func toggleAllShapesVisibility(_ visible: Bool?) {
        guard var annotation else { return }
        annotation.shapes = annotation.shapes.map { shape in
            var next = shape
            next.isVisible = visible ?? !shape.isVisible
            return next
        }
        self.annotation = annotation
    }

    func moveShape(id: UUID, by delta: CGPoint) {
        guard var shape = annotation?.shapes.first(where: { $0.id == id }) else { return }
        shape.points = shape.points.map { LabelmePoint(x: $0.x + delta.x, y: $0.y + delta.y) }
        replaceShape(shape)
    }

    func moveVertex(shapeID: UUID, vertexIndex: Int, to point: CGPoint) {
        guard var shape = annotation?.shapes.first(where: { $0.id == shapeID }),
              shape.points.indices.contains(vertexIndex)
        else { return }
        shape.points[vertexIndex] = LabelmePoint(point)
        replaceShape(shape)
    }

    func insertPoint(shapeID: UUID, after vertexIndex: Int, at point: CGPoint) {
        guard var shape = annotation?.shapes.first(where: { $0.id == shapeID }),
              shape.shapeType == .polygon || shape.shapeType == .linestrip
        else { return }
        let insertion = min(max(vertexIndex + 1, 0), shape.points.count)
        shape.points.insert(LabelmePoint(point), at: insertion)
        replaceShape(shape)
    }

    func removeVertex(shapeID: UUID, vertexIndex: Int) {
        guard var shape = annotation?.shapes.first(where: { $0.id == shapeID }),
              shape.points.indices.contains(vertexIndex)
        else { return }
        if shape.shapeType == .polygon, shape.points.count <= 3 { return }
        if shape.shapeType == .linestrip, shape.points.count <= 2 { return }
        shape.points.remove(at: vertexIndex)
        replaceShape(shape)
    }

    func connectSelectedPolygons() {
        let shapes = selectedShapes
        guard shapes.count == 2 else {
            errorMessage = "Select exactly two polygons with the same label."
            return
        }
        let shape1 = shapes[0]
        let shape2 = shapes[1]
        guard shape1.shapeType == .polygon, shape2.shapeType == .polygon, !shape1.label.isEmpty, shape1.label == shape2.label else {
            errorMessage = "Select exactly two polygons with the same label."
            return
        }
        do {
            let connected = try LabelmePolygonConnector.connect(shape1.points, shape2.points)
            let merged = LabelmeShape(
                label: shape1.label,
                points: connected,
                groupID: shape1.groupID == shape2.groupID ? shape1.groupID : nil,
                description: (shape1.description?.isEmpty == false ? shape1.description : shape2.description) ?? "",
                shapeType: .polygon,
                flags: Self.mergedFlags(shape1.flags, shape2.flags),
                mask: nil,
                isVisible: true,
                extra: shape1.extra
            )
            let removed = Set([shape1.id, shape2.id])
            annotation?.shapes.removeAll { removed.contains($0.id) }
            annotation?.shapes.append(merged)
            selectedShapeID = merged.id
            selectedShapeIDs = [merged.id]
            currentLabel = merged.label
            markDirty()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subtractOverlappingPolygons() {
        guard var annotation else { return }
        let selectedIDs = selectedIDsForAction()
        guard selectedIDs.count >= 2 else {
            errorMessage = "Select at least two polygons."
            return
        }
        do {
            let result = try LabelmePolygonOverlapResolver.subtractUpperLayers(
                from: annotation.shapes,
                limitedTo: selectedIDs
            )
            annotation.shapes = result
            self.annotation = annotation
            selectedShapeIDs = selectedIDs.intersection(Set(result.map(\.id)))
            selectedShapeID = selectedShapeIDs.first
            markDirty()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markDirty() {
        guard let current = makeHistoryState() else {
            isDirty = false
            historyBaseline = nil
            updateHistoryAvailability()
            return
        }
        if undoGroupingDepth > 0 {
            isDirty = annotation != lastSavedAnnotation
            return
        }
        recordHistoryChange(from: historyBaseline, to: current)
    }

    func beginUndoGrouping() {
        guard let current = makeHistoryState() else { return }
        if undoGroupingDepth == 0 {
            undoGroupStart = current
        }
        undoGroupingDepth += 1
    }

    func endUndoGrouping() {
        guard undoGroupingDepth > 0 else { return }
        undoGroupingDepth -= 1
        guard undoGroupingDepth == 0 else { return }
        defer { undoGroupStart = nil }
        guard let current = makeHistoryState() else {
            updateHistoryAvailability()
            return
        }
        recordHistoryChange(from: undoGroupStart, to: current)
    }

    func undo() {
        guard let target = undoStack.popLast(),
              let current = makeHistoryState()
        else { return }
        redoStack.append(current)
        restoreHistoryState(target)
        historyBaseline = target
        isDirty = target.annotation != lastSavedAnnotation
        statusMessage = "Undo"
        updateHistoryAvailability()
    }

    func redo() {
        guard let target = redoStack.popLast(),
              let current = makeHistoryState()
        else { return }
        appendUndo(current)
        restoreHistoryState(target)
        historyBaseline = target
        isDirty = target.annotation != lastSavedAnnotation
        statusMessage = "Redo"
        updateHistoryAvailability()
    }

    private func selectedIDsForAction() -> Set<UUID> {
        if !selectedShapeIDs.isEmpty {
            return selectedShapeIDs
        }
        return Set([selectedShapeID].compactMap { $0 })
    }

    private func makeHistoryState() -> EditHistoryState? {
        guard let annotation else { return nil }
        return EditHistoryState(
            annotation: annotation,
            selectedShapeID: selectedShapeID,
            selectedShapeIDs: selectedShapeIDs,
            currentLabel: currentLabel
        )
    }

    private func recordHistoryChange(from previous: EditHistoryState?, to current: EditHistoryState) {
        if let previous, previous.annotation != current.annotation {
            appendUndo(previous)
            redoStack.removeAll()
        }
        historyBaseline = current
        isDirty = current.annotation != lastSavedAnnotation
        updateHistoryAvailability()
    }

    private func appendUndo(_ state: EditHistoryState) {
        if undoStack.last != state {
            undoStack.append(state)
        }
        if undoStack.count > maxHistoryDepth {
            undoStack.removeFirst(undoStack.count - maxHistoryDepth)
        }
    }

    private func restoreHistoryState(_ state: EditHistoryState) {
        annotation = state.annotation
        let validIDs = Set(state.annotation.shapes.map(\.id))
        selectedShapeIDs = state.selectedShapeIDs.intersection(validIDs)
        if let selected = state.selectedShapeID, validIDs.contains(selected) {
            selectedShapeID = selected
        } else {
            selectedShapeID = selectedShapeIDs.first
        }
        currentLabel = state.currentLabel
        undoGroupingDepth = 0
        undoGroupStart = nil
    }

    private func resetUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        undoGroupingDepth = 0
        undoGroupStart = nil
        syncHistoryBaseline()
    }

    private func syncHistoryBaseline() {
        historyBaseline = makeHistoryState()
        updateHistoryAvailability()
    }

    private func syncHistoryBaselineIfAnnotationUnchanged() {
        guard let current = makeHistoryState() else { return }
        if historyBaseline?.annotation == current.annotation {
            historyBaseline = current
        }
    }

    private func updateHistoryAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func restoreImageAdjustment(for item: DatasetImageItem) {
        let adjustment = imageAdjustments[item.id] ?? .neutral
        imageBrightness = adjustment.brightness
        imageContrast = adjustment.contrast
    }

    private func rememberImageAdjustment() {
        guard let selectedItem else { return }
        let adjustment = ImageAdjustmentState(brightness: imageBrightness, contrast: imageContrast)
        if adjustment.isNeutral {
            imageAdjustments.removeValue(forKey: selectedItem.id)
        } else {
            imageAdjustments[selectedItem.id] = adjustment
        }
    }

    private static func clampedImageAdjustment(_ value: Double) -> Double {
        min(max(value, ImageAdjustmentDefaults.range.lowerBound), ImageAdjustmentDefaults.range.upperBound)
    }

    private static func mergedFlags(_ lhs: [String: Bool], _ rhs: [String: Bool]) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for key in Set(lhs.keys).union(rhs.keys) {
            result[key] = (lhs[key] ?? false) || (rhs[key] ?? false)
        }
        return result
    }
}
