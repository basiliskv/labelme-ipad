import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = DatasetStore()
    @AppStorage("multiSelectModifier") private var multiSelectModifierRaw = ShortcutModifier.shift.rawValue
    @AppStorage("addPointModifier") private var addPointModifierRaw = ShortcutModifier.option.rawValue
    @AppStorage("pencilOnlyEditing") private var pencilOnlyEditing = true
    @AppStorage("keyboardShortcutOverrides") private var keyboardShortcutOverrides = ShortcutRegistry.defaultJSON()
    @State private var serverDraft = ""
    @State private var cloudflareAccessClientIdDraft = ""
    @State private var cloudflareAccessClientSecretDraft = ""
    @State private var canvasCommand: CanvasCommand?
    @State private var showsFileList = true
    @State private var showsInspector = true
    @State private var showsSettings = false
    @State private var showsBrightnessContrast = false
    @State private var localDatasetPickerMode: LocalDatasetPickerMode?
    @State private var imageUploadPickerPresented = false
    @State private var canUndoLastPoint = false
    @State private var labelFocusRequest = 0
    @State private var isMultiSelectModifierPressed = false
    @State private var isAddPointModifierPressed = false

    var body: some View {
        VStack(spacing: 0) {
            connectionBar
            Divider()
            HStack(spacing: 0) {
                if showsFileList {
                    ImageListPanel(store: store)
                        .frame(width: 220)

                    Divider()
                }

                VStack(spacing: 0) {
                    LabelmeToolbar(
                        store: store,
                        canvasCommand: $canvasCommand,
                        showsFileList: $showsFileList,
                        showsInspector: $showsInspector,
                        showsBrightnessContrast: $showsBrightnessContrast,
                        onShowSettings: { showsSettings = true },
                        onUploadImages: { imageUploadPickerPresented = true }
                    )
                    Divider()
                    editorSurface
                }

                if showsInspector {
                    Divider()

                    InspectorPanel(
                        store: store,
                        labelFocusRequest: $labelFocusRequest,
                        isMultiSelectModifierPressed: isMultiSelectModifierPressed
                    )
                        .frame(width: 242)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            AppKeyboardShortcutObserver(
                registry: shortcutRegistry,
                multiSelectModifier: multiSelectModifier,
                addPointModifier: addPointModifier,
                isMultiSelectPressed: $isMultiSelectModifierPressed,
                isAddPointPressed: $isAddPointModifierPressed,
                onActions: handleShortcuts
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .task {
            serverDraft = store.serverBaseURL
            cloudflareAccessClientIdDraft = store.cloudflareAccessClientId
            cloudflareAccessClientSecretDraft = store.cloudflareAccessClientSecret
            await store.connect()
        }
        .alert("Error", isPresented: Binding(get: { store.errorMessage != nil }, set: { _ in store.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $showsSettings) {
            AppSettingsView(
                store: store,
                serverURL: $serverDraft,
                clientId: $cloudflareAccessClientIdDraft,
                clientSecret: $cloudflareAccessClientSecretDraft,
                multiSelectModifierRaw: $multiSelectModifierRaw,
                addPointModifierRaw: $addPointModifierRaw,
                pencilOnlyEditing: $pencilOnlyEditing,
                keyboardShortcutOverrides: $keyboardShortcutOverrides,
                onTest: testServer,
                onConnect: openServer,
                onClearAccess: clearCloudflareAccessSettings,
                onOpenDocuments: {
                    Task { await store.openAppDocumentsDataset() }
                    showsSettings = false
                },
                onOpenZip: {
                    localDatasetPickerMode = .openZip
                    showsSettings = false
                },
                onOpenFolder: {
                    localDatasetPickerMode = .openFolder
                    showsSettings = false
                },
                onUploadImages: {
                    imageUploadPickerPresented = true
                    showsSettings = false
                }
            )
            .presentationDetents([.large])
        }
        .fileImporter(
            isPresented: $imageUploadPickerPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImageUploadSelection(result)
        }
        .fullScreenCover(item: $localDatasetPickerMode) { mode in
            LocalDatasetPicker(mode: mode) { url in
                localDatasetPickerMode = nil
                openLocalDataset(url, mode: mode)
            } onCancel: {
                localDatasetPickerMode = nil
            }
            .ignoresSafeArea()
        }
    }

    private var multiSelectModifier: ShortcutModifier {
        ShortcutModifier(rawValue: multiSelectModifierRaw) ?? .shift
    }

    private var addPointModifier: ShortcutModifier {
        ShortcutModifier(rawValue: addPointModifierRaw) ?? .option
    }

    private var shortcutRegistry: ShortcutRegistry {
        ShortcutRegistry(json: keyboardShortcutOverrides)
    }

    private var connectionBar: some View {
        HStack(spacing: 7) {
            LabelmeIconView(icon: .fileList, size: 18)

            Text("Labelme")
                .font(.subheadline.weight(.semibold))

            Button {
                refreshConnectionDrafts()
                showsSettings = true
            } label: {
                Label {
                    Text("Settings")
                } icon: {
                    LabelmeIconView(icon: .info, size: 15)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if store.isLoading || store.isTestingConnection || store.isUploading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(store.statusMessage)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(store.currentDatasetDirectory)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 320, alignment: .trailing)

            if store.isDirty {
                Text("Modified")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(Color(.systemBackground))
    }

    private func handleShortcuts(_ actions: [ShortcutAction]) {
        guard let action = resolvedShortcutAction(from: actions) else { return }
        handleShortcut(action)
    }

    private func resolvedShortcutAction(from actions: [ShortcutAction]) -> ShortcutAction? {
        guard !actions.isEmpty else { return nil }
        if actions.contains(.editShape),
           let creationAction = preferredCreationAction(in: actions) {
            if store.tool.shortcutAction == creationAction {
                return .editShape
            }
            if store.tool == .edit {
                return creationAction
            }
            return actions.contains(store.tool.shortcutAction) ? .editShape : creationAction
        }
        return actions.first
    }

    private func preferredCreationAction(in actions: [ShortcutAction]) -> ShortcutAction? {
        let creationPriority: [ShortcutAction] = [
            .createPolygon,
            .createFreehand,
            .createRectangle,
            .createCircle,
            .createLine,
            .createPoint,
            .createLinestrip
        ]
        return creationPriority.first { actions.contains($0) }
    }

    private func handleShortcut(_ action: ShortcutAction) {
        switch action {
        case .close:
            store.closeCurrentFile()
        case .open:
            openServer()
        case .openDir:
            localDatasetPickerMode = .openFolder
        case .openZip:
            localDatasetPickerMode = .openZip
        case .openDocumentsDataset:
            Task { await store.openAppDocumentsDataset() }
        case .showSettings:
            showsSettings = true
        case .quit, .saveAs, .saveTo, .deleteFile, .createOrientedRectangle:
            store.reportUnsupportedShortcut(action)
        case .save:
            Task { await store.save() }
        case .openNext:
            Task { await store.selectNext() }
        case .openPrev:
            Task { await store.selectPrevious() }
        case .zoomIn:
            canvasCommand = .zoomIn
        case .zoomOut:
            canvasCommand = .zoomOut
        case .zoomToOriginal:
            canvasCommand = .zoomToOriginal
        case .fitWindow:
            canvasCommand = .fit
        case .fitWidth:
            canvasCommand = .fitWidth
        case .createPolygon:
            store.tool = .polygon
        case .createFreehand:
            store.tool = .freehand
        case .createRectangle:
            store.tool = .rectangle
        case .createCircle:
            store.tool = .circle
        case .createLine:
            store.tool = .line
        case .createPoint:
            store.tool = .point
        case .createLinestrip:
            store.tool = .linestrip
        case .editShape:
            store.tool = .edit
        case .selectAllShapes:
            store.selectAllShapes()
        case .clearShapeSelection:
            store.clearShapeSelection()
        case .deleteShape:
            store.deleteSelectedShape()
        case .duplicateShape:
            store.duplicateSelectedShape()
        case .copyShape:
            store.copySelectedShape()
        case .pasteShape:
            store.pasteShapes()
        case .connectPolygons:
            store.connectSelectedPolygons()
        case .subtractOverlap:
            store.subtractOverlappingPolygons()
        case .changeSelectedToPolygon:
            store.updateSelectedShapeType(.polygon)
        case .changeSelectedToRectangle:
            store.updateSelectedShapeType(.rectangle)
        case .changeSelectedToCircle:
            store.updateSelectedShapeType(.circle)
        case .changeSelectedToLine:
            store.updateSelectedShapeType(.line)
        case .changeSelectedToPoint:
            store.updateSelectedShapeType(.point)
        case .changeSelectedToLinestrip:
            store.updateSelectedShapeType(.linestrip)
        case .undo:
            if canUndoLastPoint {
                canvasCommand = .undoLastPoint
            } else {
                store.undo()
            }
        case .undoLastPoint:
            canvasCommand = .undoLastPoint
        case .editLabel:
            showsInspector = true
            labelFocusRequest += 1
        case .toggleKeepPrevMode:
            store.toggleKeepPreviousShapes()
        case .removeSelectedPoint:
            canvasCommand = .removeSelectedPoint
        case .showAllShapes:
            store.toggleAllShapesVisibility(true)
        case .hideAllShapes:
            store.toggleAllShapesVisibility(false)
        case .toggleAllShapes:
            store.toggleAllShapesVisibility(nil)
        case .showSelectedShapes:
            store.setSelectedShapeVisibility(true)
        case .hideSelectedShapes:
            store.setSelectedShapeVisibility(false)
        case .toggleSelectedShapes:
            store.toggleSelectedShapeVisibility()
        case .toggleLabels:
            store.showsLabels.toggle()
        case .toggleFillPolygons:
            store.fillsShapes.toggle()
        case .toggleFileList:
            showsFileList.toggle()
        case .toggleLabelPanel:
            showsInspector.toggle()
        case .showBrightnessContrast:
            if store.image != nil {
                showsBrightnessContrast = true
            }
        case .resetBrightnessContrast:
            store.resetImageAdjustment()
        case .redo:
            store.redo()
        }
    }

    private func openServer() {
        store.serverBaseURL = serverDraft
        saveCloudflareAccessSettings()
        Task { await store.connect() }
    }

    private func testServer() {
        store.serverBaseURL = serverDraft
        saveCloudflareAccessSettings()
        Task { await store.testConnection() }
    }

    private func saveCloudflareAccessSettings() {
        store.cloudflareAccessClientId = cloudflareAccessClientIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.cloudflareAccessClientSecret = cloudflareAccessClientSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clearCloudflareAccessSettings() {
        cloudflareAccessClientIdDraft = ""
        cloudflareAccessClientSecretDraft = ""
        saveCloudflareAccessSettings()
    }

    private func refreshConnectionDrafts() {
        serverDraft = store.serverBaseURL
        cloudflareAccessClientIdDraft = store.cloudflareAccessClientId
        cloudflareAccessClientSecretDraft = store.cloudflareAccessClientSecret
    }

    private func openLocalDataset(_ url: URL, mode: LocalDatasetPickerMode) {
        Task {
            switch mode {
            case .openFolder:
                await store.openLocalDataset(at: url)
            case .openZip:
                await store.importZipDataset(at: url)
            }
        }
    }

    private func handleImageUploadSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await store.uploadImages(from: urls) }
        case .failure(let error):
            store.errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var editorSurface: some View {
        if let image = store.image, store.annotation != nil {
            LabelmeCanvasView(
                image: image,
                annotation: annotationBinding,
                selectedShapeID: $store.selectedShapeID,
                selectedShapeIDs: $store.selectedShapeIDs,
                tool: $store.tool,
                currentLabel: $store.currentLabel,
                command: $canvasCommand,
                showsLabels: $store.showsLabels,
                fillsShapes: $store.fillsShapes,
                polygonFillOpacity: store.polygonFillOpacity,
                imageBrightness: store.imageBrightness,
                imageContrast: store.imageContrast,
                isMultiSelectModifierPressed: isMultiSelectModifierPressed,
                isAddPointModifierPressed: isAddPointModifierPressed,
                isPencilOnlyEditingEnabled: pencilOnlyEditing,
                canUndoLastPoint: $canUndoLastPoint,
                onEditingBegan: store.beginUndoGrouping,
                onEditingEnded: store.endUndoGrouping,
                onChange: store.markDirty
            )
        } else {
            VStack(spacing: 10) {
                LabelmeIconView(icon: .image, size: 42)
                Text("No Image")
                    .font(.title3.weight(.semibold))
                Text(store.items.isEmpty ? "Start the PC server, or open a local dataset folder." : "Select an image from the file list.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.17, green: 0.18, blue: 0.19))
            .foregroundStyle(.white)
        }
    }

    private var annotationBinding: Binding<LabelmeAnnotation> {
        Binding(
            get: {
                store.annotation ?? LabelmeAnnotation(
                    version: "5.5.0",
                    flags: [:],
                    shapes: [],
                    imagePath: "",
                    imageData: nil,
                    imageHeight: 1,
                    imageWidth: 1,
                    imageUrl: nil
                )
            },
            set: { newValue in
                store.annotation = newValue
                store.markDirty()
            }
        )
    }
}

private enum LocalDatasetPickerMode: String, Identifiable {
    case openFolder
    case openZip

    var id: String { rawValue }

    var contentTypes: [UTType] {
        switch self {
        case .openFolder:
            [.folder]
        case .openZip:
            [UTType(filenameExtension: "zip") ?? .data]
        }
    }

    var asCopy: Bool {
        self == .openZip
    }
}

private struct LocalDatasetPicker: UIViewControllerRepresentable {
    let mode: LocalDatasetPickerMode
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: mode.contentTypes,
            asCopy: mode.asCopy
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .fullScreen
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case connection
    case dataset
    case view
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "よく使う"
        case .connection: "接続設定"
        case .dataset: "データセット"
        case .view: "表示設定"
        case .shortcuts: "ショートカット"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .connection: "network"
        case .dataset: "folder"
        case .view: "eye"
        case .shortcuts: "keyboard"
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range = ImageAdjustmentDefaults.range

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 88, alignment: .leading)
            Slider(value: $value, in: range, step: 0.01)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.caption.monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
    }
}

private struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DatasetStore
    @Binding var serverURL: String
    @Binding var clientId: String
    @Binding var clientSecret: String
    @Binding var multiSelectModifierRaw: String
    @Binding var addPointModifierRaw: String
    @Binding var pencilOnlyEditing: Bool
    @Binding var keyboardShortcutOverrides: String
    @State private var recordingAction: ShortcutAction?
    @State private var selectedCategory = SettingsCategory.general
    @State private var pendingShortcutConflict: PendingShortcutConflict?
    let onTest: () -> Void
    let onConnect: () -> Void
    let onClearAccess: () -> Void
    let onOpenDocuments: () -> Void
    let onOpenZip: () -> Void
    let onOpenFolder: () -> Void
    let onUploadImages: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                settingsSidebar

                Divider()

                VStack(spacing: 0) {
                    settingsHeader
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            settingsContent
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .overlay {
                if let recordingAction {
                    ShortcutCaptureOverlay(
                        action: recordingAction,
                        onCancel: { self.recordingAction = nil },
                        onCapture: { keyStroke in
                            requestSetShortcut(keyStroke.shortcutText, for: recordingAction)
                            self.recordingAction = nil
                        }
                    )
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("変更を保存") {
                    onConnect()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isTestingConnection || store.isLoading)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(.systemGroupedBackground))
        .alert(
            "ショートカットが重複しています",
            isPresented: Binding(
                get: { pendingShortcutConflict != nil },
                set: { if !$0 { pendingShortcutConflict = nil } }
            )
        ) {
            Button("キャンセル", role: .cancel) {
                pendingShortcutConflict = nil
            }
            Button("続行して置き換える", role: .destructive) {
                guard let pendingShortcutConflict else { return }
                applyShortcutResolvingConflicts(
                    pendingShortcutConflict.shortcutText,
                    for: pendingShortcutConflict.action
                )
                self.pendingShortcutConflict = nil
            }
        } message: {
            Text(pendingShortcutConflict?.message ?? "")
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("環境設定")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 14)

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.systemImage)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            selectedCategory == category ? Color(.tertiarySystemFill) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 190)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var settingsHeader: some View {
        HStack {
            Label(selectedCategory.title, systemImage: selectedCategory.systemImage)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedCategory {
        case .general:
            generalSettings
        case .connection:
            connectionSettings
        case .dataset:
            datasetSettings
        case .view:
            viewSettings
        case .shortcuts:
            shortcutSettings
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(title: "よく使う") {
                settingsStatusRows
                Divider()
                Button {
                    onTest()
                } label: {
                    Label("接続テスト", systemImage: "network")
                }
                .disabled(store.isTestingConnection || store.isLoading)

                Button {
                    onConnect()
                    dismiss()
                } label: {
                    Label("サーバーへ接続", systemImage: "checkmark.circle")
                }
                .disabled(store.isTestingConnection || store.isLoading)
            }

            SettingsGroup(title: "表示") {
                Toggle("ラベル名を表示", isOn: $store.showsLabels)
                Toggle("ポリゴンを塗りつぶす", isOn: $store.fillsShapes)
                SliderRow(
                    title: "塗り濃さ",
                    value: Binding(
                        get: { store.polygonFillOpacity },
                        set: { store.polygonFillOpacity = min(max($0, 0), 0.75) }
                    ),
                    range: 0...0.75
                )
                .disabled(!store.fillsShapes)
                Toggle("Apple Pencil のみで編集", isOn: $pencilOnlyEditing)
            }
        }
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(title: "サーバー") {
                TextField("https://labelme.example.com", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                settingsStatusRows
            }

            SettingsGroup(title: "Cloudflare Access") {
                TextField("CF-Access-Client-Id", text: $clientId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())

                SecureField("CF-Access-Client-Secret", text: $clientSecret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .privacySensitive()

                Button("Access Token を消去", role: .destructive) {
                    onClearAccess()
                }
                .disabled(clientId.isEmpty && clientSecret.isEmpty)
            }

            SettingsGroup(title: "接続操作") {
                Button {
                    onTest()
                } label: {
                    Label("接続テスト", systemImage: "network")
                }
                .disabled(store.isTestingConnection || store.isLoading)

                Button {
                    onConnect()
                    dismiss()
                } label: {
                    Label("サーバーへ接続", systemImage: "checkmark.circle")
                }
                .disabled(store.isTestingConnection || store.isLoading)
            }
        }
    }

    private var datasetSettings: some View {
        SettingsGroup(title: "ローカルデータセット") {
            settingsStatusRows
            Divider()
            Button {
                onOpenDocuments()
            } label: {
                Label("アプリ内 Documents を開く", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                onOpenZip()
            } label: {
                Label("Zip を読み込む", systemImage: "doc.zipper")
            }

            Button {
                onOpenFolder()
            } label: {
                Label("Files からフォルダを開く", systemImage: "folder")
            }

            Divider()

            Button {
                onUploadImages()
            } label: {
                Label("画像ファイルを追加", systemImage: "photo.badge.plus")
            }
            .disabled(store.isUploading || store.isLoading)
        }
    }

    private var viewSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(title: "キャンバス表示") {
                Toggle("ラベル名を表示", isOn: $store.showsLabels)
                Toggle("ポリゴンを塗りつぶす", isOn: $store.fillsShapes)
                SliderRow(
                    title: "塗り濃さ",
                    value: Binding(
                        get: { store.polygonFillOpacity },
                        set: { store.polygonFillOpacity = min(max($0, 0), 0.75) }
                    ),
                    range: 0...0.75
                )
                .disabled(!store.fillsShapes)
                Toggle("Apple Pencil のみでポリゴン作成・編集", isOn: $pencilOnlyEditing)
                Button {
                    store.toggleAllShapesVisibility(true)
                } label: {
                    Label("すべての図形を表示", systemImage: "eye")
                }
                Button {
                    store.toggleAllShapesVisibility(false)
                } label: {
                    Label("すべての図形を非表示", systemImage: "eye.slash")
                }
            }

            SettingsGroup(title: "画像調整") {
                SliderRow(title: "明るさ", value: Binding(get: { store.imageBrightness }, set: { store.setImageBrightness($0) }))
                SliderRow(title: "コントラスト", value: Binding(get: { store.imageContrast }, set: { store.setImageContrast($0) }))
                Button("初期値に戻す") {
                    store.resetImageAdjustment()
                }
            }
        }
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(title: "修飾キー") {
                Picker("複数選択", selection: modifierBinding($multiSelectModifierRaw, default: .shift)) {
                    ForEach(ShortcutModifier.allCases) { modifier in
                        Text(modifier.title).tag(modifier.rawValue)
                    }
                }

                Picker("辺に点を追加", selection: modifierBinding($addPointModifierRaw, default: .option)) {
                    ForEach(ShortcutModifier.allCases) { modifier in
                        Text(modifier.title).tag(modifier.rawValue)
                    }
                }
            }

            ForEach(shortcutSections, id: \.self) { section in
                SettingsGroup(title: section) {
                    ForEach(actions(in: section)) { action in
                        ShortcutCaptureRow(
                            action: action,
                            shortcutText: shortcutText(for: action),
                            isRecording: recordingAction == action,
                            onRecord: { recordingAction = action },
                            onClear: { setShortcut("", for: action) },
                            onReset: { requestSetShortcut(action.defaultShortcutText, for: action) }
                        )
                        if action.id != actions(in: section).last?.id {
                            Divider()
                        }
                    }
                }
            }

            Button("ショートカットを初期値に戻す", role: .destructive) {
                multiSelectModifierRaw = ShortcutModifier.shift.rawValue
                addPointModifierRaw = ShortcutModifier.option.rawValue
                keyboardShortcutOverrides = ShortcutRegistry.defaultJSON()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var settingsStatusRows: some View {
        LabeledContent("状態") {
            HStack(spacing: 8) {
                if store.isTestingConnection || store.isLoading || store.isUploading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(store.statusMessage)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }

        LabeledContent("データセット") {
            Text(store.currentDatasetDirectory)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func modifierBinding(_ binding: Binding<String>, default defaultModifier: ShortcutModifier) -> Binding<String> {
        Binding(
            get: {
                ShortcutModifier(rawValue: binding.wrappedValue)?.rawValue ?? defaultModifier.rawValue
            },
            set: { newValue in
                binding.wrappedValue = ShortcutModifier(rawValue: newValue)?.rawValue ?? defaultModifier.rawValue
            }
        )
    }

    private var shortcutSections: [String] {
        ShortcutAction.allCases.reduce(into: [String]()) { sections, action in
            if !sections.contains(action.section) {
                sections.append(action.section)
            }
        }
    }

    private func actions(in section: String) -> [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.section == section }
    }

    private func shortcutText(for action: ShortcutAction) -> String {
        ShortcutRegistry(json: keyboardShortcutOverrides).shortcutText(for: action)
    }

    private func setShortcut(_ shortcutText: String, for action: ShortcutAction) {
        keyboardShortcutOverrides = ShortcutRegistry.json(
            updating: keyboardShortcutOverrides,
            action: action,
            shortcutText: shortcutText
        )
    }

    private func requestSetShortcut(_ shortcutText: String, for action: ShortcutAction) {
        let conflicts = ShortcutRegistry(json: keyboardShortcutOverrides).conflicts(
            for: action,
            shortcutText: shortcutText
        )
        if conflicts.isEmpty {
            setShortcut(shortcutText, for: action)
        } else {
            pendingShortcutConflict = PendingShortcutConflict(
                action: action,
                shortcutText: shortcutText,
                conflicts: conflicts
            )
        }
    }

    private func applyShortcutResolvingConflicts(_ shortcutText: String, for action: ShortcutAction) {
        keyboardShortcutOverrides = ShortcutRegistry.jsonResolvingConflicts(
            updating: keyboardShortcutOverrides,
            action: action,
            shortcutText: shortcutText
        )
    }
}

private struct PendingShortcutConflict {
    let action: ShortcutAction
    let shortcutText: String
    let conflicts: [ShortcutConflict]

    var message: String {
        let target = shortcutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未設定" : shortcutText
        let conflictText = conflicts
            .map { "\($0.shortcutText): \($0.action.title)" }
            .joined(separator: "\n")
        return "\(target) はすでに次の機能で使われています。\n\n\(conflictText)\n\n続行すると、既存側から重複しているショートカットを削除して、この機能に割り当てます。"
    }
}

private struct LabelmeToolbar: View {
    @ObservedObject var store: DatasetStore
    @Binding var canvasCommand: CanvasCommand?
    @Binding var showsFileList: Bool
    @Binding var showsInspector: Bool
    @Binding var showsBrightnessContrast: Bool
    let onShowSettings: () -> Void
    let onUploadImages: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ToolButton(title: "File List", icon: .fileList, isSelected: showsFileList) {
                    showsFileList.toggle()
                }

                ToolButton(title: "Labels", icon: .labels, isSelected: showsInspector) {
                    showsInspector.toggle()
                }

                ToolButton(title: "Settings", icon: .info, isSelected: false) {
                    onShowSettings()
                }

                ToolButton(title: store.isUploading ? "Uploading" : "Add\nImages", icon: .folderOpen, isSelected: false) {
                    onUploadImages()
                }
                .disabled(store.isUploading || store.isLoading)

                toolbarDivider

                ToolButton(title: "Prev Image", icon: .previous, isSelected: false) {
                    Task { await store.selectPrevious() }
                }

                ToolButton(title: "Next Image", icon: .next, isSelected: false) {
                    Task { await store.selectNext() }
                }

                toolbarDivider

                ToolButton(title: "Undo", icon: .undo, isSelected: false) {
                    store.undo()
                }
                .disabled(!store.canUndo)

                ToolButton(title: "Redo", icon: .redo, isSelected: false) {
                    store.redo()
                }
                .disabled(!store.canRedo)

                toolbarDivider

                ForEach(CanvasTool.allCases) { tool in
                    ToolButton(
                        title: tool.title,
                        icon: tool.icon,
                        isSelected: store.tool == tool
                    ) {
                        store.tool = tool
                    }
                }

                toolbarDivider

                ToolButton(title: "Brightness\nContrast", icon: .brightnessContrast, isSelected: store.hasImageAdjustment) {
                    showsBrightnessContrast = true
                }
                .disabled(store.image == nil)
                .popover(isPresented: $showsBrightnessContrast, arrowEdge: .top) {
                    BrightnessContrastPanel(store: store)
                }

                ToolButton(title: "Fit Window", icon: .fitWindow, isSelected: false) {
                    canvasCommand = .fit
                }
                ToolButton(title: "Zoom Out", icon: .zoomOut, isSelected: false) {
                    canvasCommand = .zoomOut
                }
                ToolButton(title: "Zoom In", icon: .zoomIn, isSelected: false) {
                    canvasCommand = .zoomIn
                }

                toolbarDivider

                ToolButton(title: "Fill Poly", icon: .paintBucket, isSelected: store.fillsShapes) {
                    store.fillsShapes.toggle()
                }
                ToolButton(title: "Labels", icon: .labels, isSelected: store.showsLabels) {
                    store.showsLabels.toggle()
                }
                ToolButton(title: "Shapes", icon: .image, isSelected: true) {
                    store.toggleAllShapesVisibility(nil)
                }

                ToolButton(title: "Connect", icon: .connect, isSelected: store.canConnectSelectedPolygons) {
                    store.connectSelectedPolygons()
                }
                .disabled(!store.canConnectSelectedPolygons)
                ToolButton(title: "Subtract\nOverlap", icon: .paintBucket, isSelected: false) {
                    store.subtractOverlappingPolygons()
                }
                .disabled(!store.canSubtractOverlappingPolygons)

                toolbarDivider

                ToolButton(title: "Duplicate", icon: .copy, isSelected: false) {
                    store.duplicateSelectedShape()
                }
                .disabled(store.selectedShapes.isEmpty)
                ToolButton(title: "Delete", icon: .delete, isSelected: false, role: .destructive) {
                    store.deleteSelectedShape()
                }
                .disabled(store.selectedShapes.isEmpty)

                toolbarDivider

                ToolButton(title: store.isSaving ? "Saving" : "Save", icon: .save, isSelected: false, isProminent: true) {
                    Task { await store.save() }
                }
                .disabled(store.annotation == nil || store.isSaving)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .frame(height: 58)
        .background(Color(.systemBackground))
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 42)
            .padding(.horizontal, 1)
    }
}

private struct ToolButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let icon: LabelmeIcon
    let isSelected: Bool
    var role: ButtonRole?
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                LabelmeIconView(icon: icon, size: 20)
                    .opacity(isEnabled ? 1 : 0.42)

                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(height: 22)
            }
            .frame(width: 58, height: 48)
            .foregroundStyle(textColor)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Color(.tertiarySystemFill)
        }
        if isSelected || isProminent {
            return Color.accentColor
        }
        return Color(.secondarySystemFill)
    }

    private var textColor: Color {
        if !isEnabled {
            return .secondary.opacity(0.62)
        }
        if isSelected || isProminent {
            return .white
        }
        if role == .destructive {
            return .red
        }
        return .primary
    }
}

private struct BrightnessContrastPanel: View {
    @ObservedObject var store: DatasetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                LabelmeIconView(icon: .brightnessContrast, size: 18)
                Text("Brightness/Contrast")
                    .font(.callout.weight(.semibold))
                Spacer()
                Button("Defaults") {
                    store.resetImageAdjustment()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            adjustmentRow(
                title: "Brightness:",
                value: Binding(
                    get: { store.imageBrightness },
                    set: { store.setImageBrightness($0) }
                )
            )

            adjustmentRow(
                title: "Contrast:",
                value: Binding(
                    get: { store.imageContrast },
                    set: { store.setImageContrast($0) }
                )
            )
        }
        .padding(12)
        .frame(width: 310)
        .presentationCompactAdaptation(.popover)
    }

    private func adjustmentRow(title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.callout)
                .frame(width: 86, alignment: .leading)

            Slider(value: value, in: ImageAdjustmentDefaults.range, step: 0.01)

            Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                .font(.callout.monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
    }
}

private struct ShortcutSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var multiSelectModifierRaw: String
    @Binding var addPointModifierRaw: String
    @Binding var keyboardShortcutOverrides: String
    @State private var recordingAction: ShortcutAction?

    var body: some View {
        NavigationStack {
            Form {
                Section("Modifiers") {
                    Picker("Multi-select", selection: modifierBinding($multiSelectModifierRaw, default: .shift)) {
                        ForEach(ShortcutModifier.allCases) { modifier in
                            Text(modifier.title).tag(modifier.rawValue)
                        }
                    }

                    Picker("Add point to edge", selection: modifierBinding($addPointModifierRaw, default: .option)) {
                        ForEach(ShortcutModifier.allCases) { modifier in
                            Text(modifier.title).tag(modifier.rawValue)
                        }
                    }
                }

                ForEach(shortcutSections, id: \.self) { section in
                    Section(section) {
                        ForEach(actions(in: section)) { action in
                            ShortcutCaptureRow(
                                action: action,
                                shortcutText: shortcutText(for: action),
                                isRecording: recordingAction == action,
                                onRecord: { recordingAction = action },
                                onClear: { setShortcut("", for: action) },
                                onReset: { setShortcut(action.defaultShortcutText, for: action) }
                            )
                        }
                    }
                }
            }
            .overlay {
                if let recordingAction {
                    ShortcutCaptureOverlay(
                        action: recordingAction,
                        onCancel: { self.recordingAction = nil },
                        onCapture: { keyStroke in
                            setShortcut(keyStroke.shortcutText, for: recordingAction)
                            self.recordingAction = nil
                        }
                    )
                }
            }
            .navigationTitle("Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Defaults") {
                        multiSelectModifierRaw = ShortcutModifier.shift.rawValue
                        addPointModifierRaw = ShortcutModifier.option.rawValue
                        keyboardShortcutOverrides = ShortcutRegistry.defaultJSON()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func modifierBinding(_ binding: Binding<String>, default defaultModifier: ShortcutModifier) -> Binding<String> {
        Binding(
            get: {
                ShortcutModifier(rawValue: binding.wrappedValue)?.rawValue ?? defaultModifier.rawValue
            },
            set: { newValue in
                binding.wrappedValue = ShortcutModifier(rawValue: newValue)?.rawValue ?? defaultModifier.rawValue
            }
        )
    }

    private var shortcutSections: [String] {
        ["File", "View", "Edit"]
    }

    private func actions(in section: String) -> [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.section == section }
    }

    private func shortcutText(for action: ShortcutAction) -> String {
        ShortcutRegistry(json: keyboardShortcutOverrides).shortcutText(for: action)
    }

    private func setShortcut(_ shortcutText: String, for action: ShortcutAction) {
        keyboardShortcutOverrides = ShortcutRegistry.json(
            updating: keyboardShortcutOverrides,
            action: action,
            shortcutText: shortcutText
        )
    }
}

private struct ShortcutCaptureRow: View {
    let action: ShortcutAction
    let shortcutText: String
    let isRecording: Bool
    let onRecord: () -> Void
    let onClear: () -> Void
    let onReset: () -> Void

    private var visibleShortcutText: String {
        shortcutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未設定" : shortcutText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.callout.weight(.semibold))
                    Text(action.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Text(visibleShortcutText)
                    .font(.caption.monospaced())
                    .foregroundStyle(shortcutText.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            HStack(spacing: 8) {
                Button(isRecording ? "入力待ち..." : "記録") {
                    onRecord()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("消去", role: .destructive) {
                    onClear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("初期値") {
                    onReset()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !action.isOriginalLabelmeShortcut {
                    Text("追加機能")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ShortcutCaptureOverlay: View {
    let action: ShortcutAction
    let onCancel: () -> Void
    let onCapture: (KeyStroke) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                Text(action.title)
                    .font(.headline)
                Text("割り当てたいキーを押してください")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(action.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button("キャンセル", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(18)
            .frame(width: 330)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                ShortcutCaptureKeyObserver(onCapture: onCapture, onCancel: onCancel)
                    .frame(width: 0, height: 0)
            }
        }
    }

}

private struct ShortcutCaptureKeyObserver: UIViewRepresentable {
    let onCapture: (KeyStroke) -> Void
    let onCancel: () -> Void

    func makeUIView(context: Context) -> CaptureKeyView {
        let view = CaptureKeyView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        view.activate()
        return view
    }

    func updateUIView(_ uiView: CaptureKeyView, context: Context) {
        uiView.onCapture = onCapture
        uiView.onCancel = onCancel
        uiView.activate()
    }

    final class CaptureKeyView: UIView {
        var onCapture: (KeyStroke) -> Void = { _ in }
        var onCancel: () -> Void = {}

        override var canBecomeFirstResponder: Bool {
            true
        }

        func activate() {
            DispatchQueue.main.async { [weak self] in
                self?.becomeFirstResponder()
            }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            for press in presses {
                if press.key?.keyCode == .keyboardEscape {
                    onCancel()
                    return
                }
                if let keyStroke = KeyStroke.fromPress(press) {
                    onCapture(keyStroke)
                    return
                }
            }
            super.pressesBegan(presses, with: event)
        }
    }
}

private struct AppKeyboardShortcutObserver: UIViewRepresentable {
    let registry: ShortcutRegistry
    let multiSelectModifier: ShortcutModifier
    let addPointModifier: ShortcutModifier
    @Binding var isMultiSelectPressed: Bool
    @Binding var isAddPointPressed: Bool
    let onActions: ([ShortcutAction]) -> Void

    func makeUIView(context: Context) -> ShortcutKeyView {
        let view = ShortcutKeyView()
        update(view)
        view.activateIfAppropriate()
        return view
    }

    func updateUIView(_ uiView: ShortcutKeyView, context: Context) {
        update(uiView)
        uiView.activateIfAppropriate()
    }

    private func update(_ view: ShortcutKeyView) {
        view.registry = registry
        view.multiSelectModifier = multiSelectModifier
        view.addPointModifier = addPointModifier
        view.onShortcutActions = onActions
        view.onModifierChange = { newMultiSelectValue, newAddPointValue in
            if isMultiSelectPressed != newMultiSelectValue {
                isMultiSelectPressed = newMultiSelectValue
            }
            if isAddPointPressed != newAddPointValue {
                isAddPointPressed = newAddPointValue
            }
        }
    }

    final class ShortcutKeyView: UIView {
        var registry = ShortcutRegistry(json: ShortcutRegistry.defaultJSON())
        var multiSelectModifier: ShortcutModifier = .shift
        var addPointModifier: ShortcutModifier = .option
        var onShortcutActions: ([ShortcutAction]) -> Void = { _ in }
        var onModifierChange: (_ isMultiSelectPressed: Bool, _ isAddPointPressed: Bool) -> Void = { _, _ in }

        private var isMultiSelectPressed = false
        private var isAddPointPressed = false

        override var canBecomeFirstResponder: Bool {
            true
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                activateIfAppropriate()
            } else {
                resetPressedState()
            }
        }

        func activateIfAppropriate() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                guard self.window?.activeTextInputResponder == nil else { return }
                self.becomeFirstResponder()
            }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            updatePressedState(with: presses, isPressed: true)
            var handled = false
            for press in presses {
                let actions = registry.actions(for: press)
                guard !actions.isEmpty else { continue }
                onShortcutActions(actions)
                handled = true
            }
            if !handled {
                super.pressesBegan(presses, with: event)
            }
        }

        override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            updatePressedState(with: presses, isPressed: true)
            super.pressesChanged(presses, with: event)
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            updatePressedState(with: presses, isPressed: false)
            super.pressesEnded(presses, with: event)
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            updatePressedState(with: presses, isPressed: false)
            super.pressesCancelled(presses, with: event)
        }

        private func resetPressedState() {
            setPressedState(isMultiSelectPressed: false, isAddPointPressed: false)
        }

        private func updatePressedState(with presses: Set<UIPress>, isPressed: Bool) {
            var nextMultiSelectValue = isMultiSelectPressed
            var nextAddPointValue = isAddPointPressed

            for press in presses {
                if multiSelectModifier.isPhysicalModifierPress(press) {
                    nextMultiSelectValue = isPressed
                }
                if addPointModifier.isPhysicalModifierPress(press) {
                    nextAddPointValue = isPressed
                }
                if isPressed, let flags = press.key?.modifierFlags {
                    if multiSelectModifier.matches(flags) {
                        nextMultiSelectValue = true
                    }
                    if addPointModifier.matches(flags) {
                        nextAddPointValue = true
                    }
                }
            }

            setPressedState(isMultiSelectPressed: nextMultiSelectValue, isAddPointPressed: nextAddPointValue)
        }

        private func setPressedState(isMultiSelectPressed newMultiSelectValue: Bool, isAddPointPressed newAddPointValue: Bool) {
            guard isMultiSelectPressed != newMultiSelectValue || isAddPointPressed != newAddPointValue else { return }
            isMultiSelectPressed = newMultiSelectValue
            isAddPointPressed = newAddPointValue
            onModifierChange(newMultiSelectValue, newAddPointValue)
        }
    }
}

private extension UIWindow {
    var activeTextInputResponder: UIView? {
        findActiveTextInputResponder(in: self)
    }

    private func findActiveTextInputResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder, view.isTextInputResponder {
            return view
        }
        for subview in view.subviews {
            if let responder = findActiveTextInputResponder(in: subview) {
                return responder
            }
        }
        return nil
    }
}

private extension UIView {
    var isTextInputResponder: Bool {
        self is UITextField || self is UITextView
    }
}

private struct ImageListPanel: View {
    @ObservedObject var store: DatasetStore

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            List(store.filteredItems, selection: $store.selectedItem) { item in
                ImageRow(item: item, isSelected: item.id == store.selectedItem?.id)
                    .listRowInsets(EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await store.select(item) }
                    }
            }
            .listStyle(.plain)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var panelHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("File List")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    Task { await store.refreshList() }
                } label: {
                    LabelmeIconView(icon: .fileList, size: 15)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Refresh")
            }
            HStack(spacing: 5) {
                LabelmeIconView(icon: .zoomIn, size: 13)
                    .opacity(0.62)
                TextField("Search labels/files", text: $store.searchText)
                    .font(.caption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(6)
    }
}

private struct ImageRow: View {
    let item: DatasetImageItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            LabelmeIconView(icon: item.annotated ? .edit : .image, size: 14)
                .opacity(item.annotated ? 1 : 0.45)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(item.shapeCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    ForEach(item.labels.prefix(2), id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct InspectorPanel: View {
    @ObservedObject var store: DatasetStore
    @Binding var labelFocusRequest: Int
    let isMultiSelectModifierPressed: Bool
    @FocusState private var isLabelFieldFocused: Bool
    @State private var draggedShapeID: UUID?
    @State private var shapeDropTarget: ShapeDropTarget?
    @State private var labelPickerShapeID: UUID?
    @State private var labelPickerDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            labelEditor
                .padding(8)
                .frame(height: 174, alignment: .top)
                .clipped()
            Divider()
            shapeList
                .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            metadata
                .padding(8)
                .frame(height: 92, alignment: .top)
                .clipped()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .onChange(of: labelFocusRequest) {
            isLabelFieldFocused = true
        }
    }

    private var inspectorHeader: some View {
        HStack {
            Text("Labels")
                .font(.caption.weight(.semibold))
            Spacer()
            Text("\(store.annotation?.shapes.count ?? 0)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }

    private var labelEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Current Label")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("object", text: labelBinding)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isLabelFieldFocused)

            if let selected = store.selectedShape {
                Picker("Shape", selection: shapeTypeBinding(selected)) {
                    ForEach(LabelmeShapeType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 8) {
                    Button {
                        store.toggleSelectedShapeVisibility()
                    } label: {
                        LabelmeMenuLabel(title: selected.isVisible ? "Hide" : "Show", icon: .eye)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        store.deleteSelectedShape()
                    } label: {
                        LabelmeMenuLabel(title: "Delete", icon: .delete)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !store.recentLabels.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 4)], alignment: .leading, spacing: 4) {
                    ForEach(store.recentLabels, id: \.self) { label in
                        Button {
                            store.currentLabel = label
                            store.updateSelectedShapeLabel(label)
                        } label: {
                            Text(label)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var shapeList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shape List")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            if let shapes = store.annotation?.shapes, !shapes.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(shapes) { shape in
                            ShapeRow(
                                shape: shape,
                                isSelected: store.selectedShapeIDs.contains(shape.id),
                                isDropTarget: shapeDropTarget == .before(shape.id) && draggedShapeID != shape.id,
                                dragProvider: { dragProvider(for: shape) },
                                onSelectionToggle: { isSelected in
                                    store.setShapeSelected(shape, selected: isSelected)
                                },
                                onVisibilityToggle: {
                                    store.toggleShapeVisibility(id: shape.id)
                                }
                            ) {
                                if isMultiSelectModifierPressed {
                                    store.selectShape(shape, extending: true)
                                } else {
                                    store.selectShape(shape)
                                    showLabelPicker(for: shape)
                                }
                            }
                            .popover(
                                isPresented: Binding(
                                    get: { labelPickerShapeID == shape.id },
                                    set: { isPresented in
                                        if !isPresented, labelPickerShapeID == shape.id {
                                            labelPickerShapeID = nil
                                        }
                                    }
                                ),
                                arrowEdge: .trailing
                            ) {
                                ShapeLabelPickerPopover(
                                    shape: shape,
                                    draftLabel: $labelPickerDraft,
                                    labels: store.recentLabels,
                                    onChoose: { label in
                                        applyLabel(label, to: shape)
                                    },
                                    onApply: {
                                        applyLabel(labelPickerDraft, to: shape)
                                    },
                                    onCancel: {
                                        labelPickerShapeID = nil
                                    }
                                )
                            }
                            .onDrop(
                                of: [UTType.text],
                                isTargeted: dropTargetBinding(.before(shape.id))
                            ) { _ in
                                reorderDraggedShape(to: .before(shape.id))
                            }
                            .contextMenu {
                                ShapeContextMenu(store: store, shape: shape)
                            }
                        }

                        ShapeDropLine(isActive: shapeDropTarget == .end)
                            .onDrop(
                                of: [UTType.text],
                                isTargeted: dropTargetBinding(.end)
                            ) { _ in
                                reorderDraggedShape(to: .end)
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } else {
                Text("No shapes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Image")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let item = store.selectedItem {
                Text(item.relativePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if let width = item.imageWidth, let height = item.imageHeight {
                    Text("\(width) x \(height)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var labelBinding: Binding<String> {
        Binding(
            get: { store.selectedShape?.label ?? store.currentLabel },
            set: { value in
                store.currentLabel = value
                if store.selectedShape != nil {
                    store.updateSelectedShapeLabel(value)
                }
            }
        )
    }

    private func shapeTypeBinding(_ selected: LabelmeShape) -> Binding<LabelmeShapeType> {
        Binding(
            get: { store.selectedShape?.shapeType ?? selected.shapeType },
            set: { store.updateSelectedShapeType($0) }
        )
    }

    private func dragProvider(for shape: LabelmeShape) -> NSItemProvider {
        draggedShapeID = shape.id
        shapeDropTarget = nil
        store.selectShape(shape)
        return NSItemProvider(object: shape.id.uuidString as NSString)
    }

    private func showLabelPicker(for shape: LabelmeShape) {
        labelPickerShapeID = shape.id
        labelPickerDraft = shape.label
    }

    private func applyLabel(_ label: String, to shape: LabelmeShape) {
        store.updateShapeLabel(id: shape.id, label: label)
        labelPickerShapeID = nil
    }

    private func dropTargetBinding(_ target: ShapeDropTarget) -> Binding<Bool> {
        Binding(
            get: { shapeDropTarget == target },
            set: { isTargeted in
                if isTargeted, draggedShapeID != nil {
                    shapeDropTarget = target
                } else if shapeDropTarget == target {
                    shapeDropTarget = nil
                }
            }
        )
    }

    private func reorderDraggedShape(to target: ShapeDropTarget) -> Bool {
        guard let draggedShapeID else {
            shapeDropTarget = nil
            return false
        }
        switch target {
        case .before(let targetID):
            store.reorderShape(draggedID: draggedShapeID, before: targetID)
        case .end:
            store.reorderShape(draggedID: draggedShapeID, before: nil)
        }
        self.draggedShapeID = nil
        shapeDropTarget = nil
        return true
    }
}

private enum ShapeDropTarget: Equatable {
    case before(UUID)
    case end
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension CanvasTool {
    var shortcutAction: ShortcutAction {
        switch self {
        case .edit: .editShape
        case .polygon: .createPolygon
        case .freehand: .createFreehand
        case .rectangle: .createRectangle
        case .circle: .createCircle
        case .line: .createLine
        case .point: .createPoint
        case .linestrip: .createLinestrip
        }
    }
}

private struct ShapeLabelPickerPopover: View {
    let shape: LabelmeShape
    @Binding var draftLabel: String
    let labels: [String]
    let onChoose: (String) -> Void
    let onApply: () -> Void
    let onCancel: () -> Void

    private var trimmedDraft: String {
        draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleLabels: [String] {
        Array(
            ([shape.label] + labels)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .uniqued()
                .prefix(18)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.labelmeColor(for: shape.label))
                    .frame(width: 5, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ラベルを変更")
                        .font(.callout.weight(.semibold))
                    Text("\(shape.shapeType.title) - \(shape.pointSummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("label", text: $draftLabel)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.callout)

            if !visibleLabels.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(visibleLabels, id: \.self) { label in
                        Button {
                            onChoose(label)
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.labelmeColor(for: label))
                                    .frame(width: 7, height: 7)
                                Text(label)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack {
                Button("キャンセル", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("適用") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(trimmedDraft.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }
}

private struct ShapeRow: View {
    let shape: LabelmeShape
    let isSelected: Bool
    let isDropTarget: Bool
    let dragProvider: () -> NSItemProvider
    let onSelectionToggle: (Bool) -> Void
    let onVisibilityToggle: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.labelmeColor(for: shape.label))
                .frame(width: 5, height: 28)

            Button {
                onSelectionToggle(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "選択解除" : "選択")

            Button(action: onVisibilityToggle) {
                LabelmeIconView(icon: .eye, size: 13)
                    .opacity(shape.isVisible ? 0.78 : 0.22)
                    .frame(width: 22, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shape.isVisible ? "非表示" : "表示")

            VStack(alignment: .leading, spacing: 2) {
                Text(shape.label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Text("\(shape.shapeType.title) - \(shape.pointSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            LabelmeIconView(icon: .lineStrip, size: 13)
                .opacity(0.45)
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
                .onDrag(dragProvider)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .top) {
            if isDropTarget {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
            }
        }
        .onTapGesture(perform: action)
    }
}

private struct ShapeDropLine: View {
    let isActive: Bool

    var body: some View {
        Capsule()
            .fill(isActive ? Color.accentColor : Color.clear)
            .frame(height: 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
    }
}

private struct ShapeContextMenu: View {
    @ObservedObject var store: DatasetStore
    let shape: LabelmeShape

    var body: some View {
        Button {
            store.selectShape(shape)
            store.tool = .edit
        } label: {
            LabelmeMenuLabel(title: "Edit Shapes", icon: .edit)
        }

        Button {
            store.selectShape(shape, extending: true)
        } label: {
            LabelmeMenuLabel(
                title: store.selectedShapeIDs.contains(shape.id) ? "Remove from Selection" : "Add to Selection",
                icon: store.selectedShapeIDs.contains(shape.id) ? .clear : .polygon
            )
        }

        Button {
            store.selectAllShapes()
        } label: {
            LabelmeMenuLabel(title: "Select All Shapes", icon: .circlesFour)
        }

        Button {
            store.clearShapeSelection()
        } label: {
            LabelmeMenuLabel(title: "Clear Selection", icon: .clear)
        }

        Menu("Shape Type") {
            ForEach(LabelmeShapeType.allCases) { type in
                Button {
                    store.selectShape(shape)
                    store.updateSelectedShapeType(type)
                } label: {
                    LabelmeMenuLabel(title: type.title, icon: type.icon)
                }
            }
        }

        Divider()

        Button {
            store.connectSelectedPolygons()
        } label: {
            LabelmeMenuLabel(title: "Connect Polygon", icon: .connect)
        }
        .disabled(!store.canConnectSelectedPolygons)

        Button {
            store.subtractOverlappingPolygons()
        } label: {
            LabelmeMenuLabel(title: "Subtract Overlap", icon: .paintBucket)
        }
        .disabled(!store.canSubtractOverlappingPolygons)

        Divider()

        Button {
            if !store.selectedShapeIDs.contains(shape.id) {
                store.selectShape(shape)
            }
            store.duplicateSelectedShape()
        } label: {
            LabelmeMenuLabel(title: "Duplicate Shapes", icon: .copy)
        }

        Button {
            if !store.selectedShapeIDs.contains(shape.id) {
                store.selectShape(shape)
            }
            store.copySelectedShape()
        } label: {
            LabelmeMenuLabel(title: "Copy Shapes", icon: .copy)
        }

        Button {
            store.pasteShapes()
        } label: {
            LabelmeMenuLabel(title: "Paste Shapes", icon: .copy)
        }
        .disabled(!store.canPasteShapes)

        Button {
            if !store.selectedShapeIDs.contains(shape.id) {
                store.selectShape(shape)
            }
            store.toggleSelectedShapeVisibility()
        } label: {
            LabelmeMenuLabel(title: shape.isVisible ? "Hide Shape" : "Show Shape", icon: .eye)
        }

        Divider()

        Button(role: .destructive) {
            if !store.selectedShapeIDs.contains(shape.id) {
                store.selectShape(shape)
            }
            store.deleteSelectedShape()
        } label: {
            LabelmeMenuLabel(title: "Delete Shapes", icon: .delete)
        }
    }
}
