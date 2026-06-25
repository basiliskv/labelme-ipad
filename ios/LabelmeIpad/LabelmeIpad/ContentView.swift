import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = DatasetStore()
    @AppStorage("multiSelectModifier") private var multiSelectModifierRaw = ShortcutModifier.shift.rawValue
    @AppStorage("addPointModifier") private var addPointModifierRaw = ShortcutModifier.option.rawValue
    @AppStorage("keyboardShortcutOverrides") private var keyboardShortcutOverrides = ShortcutRegistry.defaultJSON()
    @State private var serverDraft = ""
    @State private var canvasCommand: CanvasCommand?
    @State private var showsFileList = true
    @State private var showsInspector = true
    @State private var showsShortcutSettings = false
    @State private var localDatasetPickerMode: LocalDatasetPickerMode?
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
                        onShowShortcutSettings: { showsShortcutSettings = true }
                    )
                    Divider()
                    editorSurface
                }

                if showsInspector {
                    Divider()

                    InspectorPanel(store: store, labelFocusRequest: $labelFocusRequest)
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
                onAction: handleShortcut
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .task {
            serverDraft = store.serverBaseURL
            await store.connect()
        }
        .alert("Error", isPresented: Binding(get: { store.errorMessage != nil }, set: { _ in store.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $showsShortcutSettings) {
            ShortcutSettingsView(
                multiSelectModifierRaw: $multiSelectModifierRaw,
                addPointModifierRaw: $addPointModifierRaw,
                keyboardShortcutOverrides: $keyboardShortcutOverrides
            )
            .presentationDetents([.medium, .large])
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

            TextField("http://192.168.1.10:8765", text: $serverDraft)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption.monospaced())
                .frame(maxWidth: 300)

            Button {
                Task { await store.openAppDocumentsDataset() }
            } label: {
                Label {
                    Text("Docs")
                } icon: {
                    LabelmeIconView(icon: .fileList, size: 15)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                localDatasetPickerMode = .openZip
            } label: {
                Label {
                    Text("Zip")
                } icon: {
                    LabelmeIconView(icon: .copy, size: 15)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                localDatasetPickerMode = .openFolder
            } label: {
                Label {
                    Text("Files")
                } icon: {
                    LabelmeIconView(icon: .folderOpen, size: 15)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                openServer()
            } label: {
                Label {
                    Text("Open")
                } icon: {
                    LabelmeIconView(icon: .folderOpen, size: 15)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(store.statusMessage)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

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

    private func handleShortcut(_ action: ShortcutAction) {
        switch action {
        case .close:
            store.closeCurrentFile()
        case .open:
            openServer()
        case .openDir:
            localDatasetPickerMode = .openFolder
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
        case .deleteShape:
            store.deleteSelectedShape()
        case .duplicateShape:
            store.duplicateSelectedShape()
        case .copyShape:
            store.copySelectedShape()
        case .pasteShape:
            store.pasteShapes()
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
        case .redo:
            store.redo()
        }
    }

    private func openServer() {
        store.serverBaseURL = serverDraft
        Task { await store.connect() }
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
                imageBrightness: store.imageBrightness,
                imageContrast: store.imageContrast,
                isMultiSelectModifierPressed: isMultiSelectModifierPressed,
                isAddPointModifierPressed: isAddPointModifierPressed,
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

private struct LabelmeToolbar: View {
    @ObservedObject var store: DatasetStore
    @Binding var canvasCommand: CanvasCommand?
    @Binding var showsFileList: Bool
    @Binding var showsInspector: Bool
    @State private var showsBrightnessContrast = false
    let onShowShortcutSettings: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ToolButton(title: "File List", icon: .fileList, isSelected: showsFileList) {
                    showsFileList.toggle()
                }

                ToolButton(title: "Labels", icon: .labels, isSelected: showsInspector) {
                    showsInspector.toggle()
                }

                ToolButton(title: "Keys", icon: .info, isSelected: false) {
                    onShowShortcutSettings()
                }

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
                            TextField(action.title, text: shortcutBinding(for: action), prompt: Text(action.placeholderShortcutText))
                                .font(.caption.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
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

    private func shortcutBinding(for action: ShortcutAction) -> Binding<String> {
        Binding(
            get: {
                ShortcutRegistry(json: keyboardShortcutOverrides).shortcutText(for: action)
            },
            set: { newValue in
                keyboardShortcutOverrides = ShortcutRegistry.json(
                    updating: keyboardShortcutOverrides,
                    action: action,
                    shortcutText: newValue
                )
            }
        )
    }
}

private struct AppKeyboardShortcutObserver: UIViewRepresentable {
    let registry: ShortcutRegistry
    let multiSelectModifier: ShortcutModifier
    let addPointModifier: ShortcutModifier
    @Binding var isMultiSelectPressed: Bool
    @Binding var isAddPointPressed: Bool
    let onAction: (ShortcutAction) -> Void

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
        view.onShortcutAction = onAction
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
        var onShortcutAction: (ShortcutAction) -> Void = { _ in }
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
                guard let action = registry.action(for: press) else { continue }
                onShortcutAction(action)
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
    @FocusState private var isLabelFieldFocused: Bool
    @State private var draggedShapeID: UUID?
    @State private var shapeDropTarget: ShapeDropTarget?

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    labelEditor
                    shapeList
                    metadata
                }
                .padding(8)
            }
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

            if let shapes = store.annotation?.shapes, !shapes.isEmpty {
                VStack(spacing: 4) {
                    ForEach(shapes) { shape in
                        ShapeRow(
                            shape: shape,
                            isSelected: store.selectedShapeIDs.contains(shape.id),
                            isDropTarget: shapeDropTarget == .before(shape.id) && draggedShapeID != shape.id,
                            dragProvider: { dragProvider(for: shape) }
                        ) {
                            store.selectShape(shape)
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
            } else {
                Text("No shapes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ShapeRow: View {
    let shape: LabelmeShape
    let isSelected: Bool
    let isDropTarget: Bool
    let dragProvider: () -> NSItemProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.labelmeColor(for: shape.label))
                    .frame(width: 5, height: 28)

                LabelmeIconView(icon: .eye, size: 13)
                    .opacity(shape.isVisible ? 0.72 : 0.22)
                    .frame(width: 14)

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
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .top) {
                if isDropTarget {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(height: 3)
                        .padding(.horizontal, 4)
                }
            }
        }
        .buttonStyle(.plain)
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
