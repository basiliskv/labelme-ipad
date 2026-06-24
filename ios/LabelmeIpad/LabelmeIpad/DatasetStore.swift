import Foundation
import SwiftUI
import UIKit

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

struct ConfiguredKeyboardShortcut: Equatable {
    var key: String
    var modifier: ShortcutModifier

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(ShortcutKeyChoices.normalized(key, default: "z")))
    }

    var eventModifiers: EventModifiers {
        modifier.eventModifiers
    }

    var displayTitle: String {
        "\(modifier.title)+\(ShortcutKeyChoices.normalized(key, default: "z").uppercased())"
    }
}

enum ShortcutKeyChoices {
    static let letters = "abcdefghijklmnopqrstuvwxyz".map { String($0) }

    static func normalized(_ value: String, default defaultValue: String) -> String {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard letters.contains(lowercased) else { return defaultValue }
        return lowercased
    }
}

enum ImageAdjustmentDefaults {
    static let range: ClosedRange<Double> = 0...3
    static let neutral = 1.0
}

@MainActor
final class DatasetStore: ObservableObject {
    @AppStorage("serverBaseURL") var serverBaseURL = "http://127.0.0.1:8765"

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
    @Published var isSaving = false
    @Published var isDirty = false
    @Published var showsLabels = true
    @Published var fillsShapes = true
    @Published var imageBrightness = ImageAdjustmentDefaults.neutral
    @Published var imageContrast = ImageAdjustmentDefaults.neutral
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
    private let maxHistoryDepth = 120
    private var client: LabelmeAPI? {
        try? LabelmeAPI(baseURLString: serverBaseURL)
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

    var hasImageAdjustment: Bool {
        !ImageAdjustmentState(brightness: imageBrightness, contrast: imageContrast).isNeutral
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
        isLoading = true
        defer { isLoading = false }
        do {
            health = try await client.health()
            let response = try await client.images(query: "")
            items = response.items
            statusMessage = "\(response.total) images / \(health?.annotatedCount ?? 0) annotated"
            if selectedItem == nil, let first = items.first {
                await select(first)
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Disconnected"
        }
    }

    func refreshList() async {
        guard let client else { return }
        do {
            let response = try await client.images(query: searchText)
            items = response.items
            statusMessage = "\(response.total) images"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ item: DatasetImageItem) async {
        if isDirty {
            await save()
        }
        guard let client else { return }
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
            async let loadedAnnotation = client.annotation(for: item)
            async let loadedImage = client.loadImage(for: item)
            let (annotation, image) = try await (loadedAnnotation, loadedImage)
            self.annotation = annotation
            self.lastSavedAnnotation = annotation
            self.image = image
            currentLabel = annotation.shapes.first?.label ?? currentLabel
            isDirty = false
            resetUndoHistory()
            statusMessage = item.relativePath
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard let client, let selectedItem, let annotation else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await client.save(annotation, for: selectedItem)
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

    func updateSelectedShapeType(_ shapeType: LabelmeShapeType) {
        guard var shape = selectedShape else { return }
        shape.shapeType = shapeType
        replaceShape(shape)
    }

    func toggleSelectedShapeVisibility() {
        let ids = selectedIDsForAction()
        guard !ids.isEmpty else { return }
        annotation?.shapes = annotation?.shapes.map { shape in
            guard ids.contains(shape.id) else { return shape }
            var updated = shape
            updated.isVisible.toggle()
            return updated
        } ?? []
    }

    func toggleAllShapesVisibility(_ visible: Bool?) {
        guard annotation != nil else { return }
        annotation?.shapes = annotation?.shapes.map { shape in
            var next = shape
            next.isVisible = visible ?? !shape.isVisible
            return next
        } ?? []
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
