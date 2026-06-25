import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct LabelmeCanvasView: View {
    let image: UIImage
    @Binding var annotation: LabelmeAnnotation
    @Binding var selectedShapeID: UUID?
    @Binding var selectedShapeIDs: Set<UUID>
    @Binding var tool: CanvasTool
    @Binding var currentLabel: String
    @Binding var command: CanvasCommand?
    @Binding var showsLabels: Bool
    @Binding var fillsShapes: Bool
    var imageBrightness: Double
    var imageContrast: Double
    var isMultiSelectModifierPressed: Bool
    var isAddPointModifierPressed: Bool
    @Binding var canUndoLastPoint: Bool
    var onEditingBegan: () -> Void
    var onEditingEnded: () -> Void
    var onChange: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var magnificationStartZoom: CGFloat?
    @State private var pan: CGSize = .zero
    @State private var draftPoints: [CGPoint] = []
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var activeDrag: DragTarget?
    @State private var lastDragImagePoint: CGPoint?
    @State private var lastDragScreenPoint: CGPoint?
    @State private var selectedVertex: (shapeID: UUID, vertexIndex: Int)?
    @State private var adjustedImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                canvas(proxy: proxy)
                    .gesture(canvasGesture(size: proxy.size))
                    .simultaneousGesture(zoomGesture())

                if !draftPoints.isEmpty {
                    draftBar
                        .padding(.bottom, 14)
                }

                zoomReadout
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
            }
            .background(Color(red: 0.17, green: 0.18, blue: 0.19))
            .onChange(of: tool) {
                cancelDraft()
            }
            .onChange(of: draftPoints.count) { _, newValue in
                canUndoLastPoint = newValue > 0
            }
            .onChange(of: imageAdjustmentKey) {
                refreshAdjustedImage()
            }
            .onChange(of: command) { _, newValue in
                guard let newValue else { return }
                switch newValue {
                case .fit:
                    fit()
                case .fitWidth:
                    fitWidth(viewSize: proxy.size)
                case .zoomToOriginal:
                    zoomToOriginal(viewSize: proxy.size)
                case .zoomIn:
                    zoomIn()
                case .zoomOut:
                    zoomOut()
                case .cancelDraft:
                    cancelDraft()
                case .undoLastPoint:
                    undoLastPoint()
                case .removeSelectedPoint:
                    removeSelectedPoint()
                }
                command = nil
            }
            .onAppear {
                refreshAdjustedImage()
                canUndoLastPoint = !draftPoints.isEmpty
            }
        }
    }

    private func fit() {
        zoom = 1
        pan = .zero
    }

    private func fitWidth(viewSize: CGSize) {
        let baseScale = CanvasTransform(viewSize: viewSize, imageSize: imageSize, zoom: 1, pan: .zero).baseScale
        guard baseScale > 0, imageSize.width > 0 else { return }
        zoom = min(max((viewSize.width / imageSize.width) / baseScale, 0.2), 8)
        pan = .zero
    }

    private func zoomToOriginal(viewSize: CGSize) {
        let baseScale = CanvasTransform(viewSize: viewSize, imageSize: imageSize, zoom: 1, pan: .zero).baseScale
        guard baseScale > 0 else { return }
        zoom = min(max(1 / baseScale, 0.2), 8)
    }

    private func zoomIn() {
        zoom = min(zoom * 1.2, 8)
    }

    private func zoomOut() {
        zoom = max(zoom / 1.2, 0.2)
    }

    private var draftBar: some View {
        HStack(spacing: 10) {
            Text("\(tool.title): \(draftPoints.count) pts")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white)
            Button {
                _ = draftPoints.popLast()
            } label: {
                LabelmeMenuLabel(title: "Undo last point", icon: .undo)
            }
            .disabled(draftPoints.isEmpty)
            Button {
                finishDraft()
            } label: {
                LabelmeMenuLabel(title: "Finish", icon: .fitWindow)
            }
            .disabled(!canFinishDraft)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var zoomReadout: some View {
        Text("\(Int(zoom * 100))%")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func canvas(proxy: GeometryProxy) -> some View {
        Canvas { context, size in
            let transform = CanvasTransform(viewSize: size, imageSize: imageSize, zoom: zoom, pan: pan)
            drawBackground(in: &context, size: size)
            context.draw(Image(uiImage: adjustedImage ?? image), in: transform.imageRect)

            for shape in annotation.shapes where shape.isVisible {
                let selected = selectedShapeIDs.contains(shape.id) || shape.id == selectedShapeID
                draw(shape: shape, selected: selected, transform: transform, context: &context)
            }

            drawDraft(transform: transform, context: &context)
        }
        .clipped()
        .contentShape(Rectangle())
    }

    private var imageAdjustmentKey: String {
        let brightness = Int((imageBrightness * 100).rounded())
        let contrast = Int((imageContrast * 100).rounded())
        return "\(annotation.imagePath)|\(brightness)|\(contrast)"
    }

    private func refreshAdjustedImage() {
        adjustedImage = ImageAdjustmentRenderer.adjustedImage(
            from: image,
            brightness: imageBrightness,
            contrast: imageContrast
        )
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize) {
        let tile: CGFloat = 22
        var path = Path()
        var y: CGFloat = 0
        var row = 0
        while y < size.height {
            var x: CGFloat = 0
            var column = 0
            while x < size.width {
                if (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: x, y: y, width: tile, height: tile))
                }
                x += tile
                column += 1
            }
            y += tile
            row += 1
        }
        context.fill(path, with: .color(Color.white.opacity(0.035)))
    }

    private func draw(shape: LabelmeShape, selected: Bool, transform: CanvasTransform, context: inout GraphicsContext) {
        let palette = ShapePalette(label: shape.label, selected: selected)
        let path = renderPath(for: shape, transform: transform)

        if fillsShapes, shape.shapeType.fillsInterior {
            context.fill(path, with: .color(palette.fill))
        }
        context.stroke(path, with: .color(palette.stroke), lineWidth: selected ? 3 : 2)

        drawVertices(shape: shape, selected: selected, palette: palette, transform: transform, context: &context)

        if showsLabels {
            drawLabel(shape: shape, palette: palette, transform: transform, context: &context)
        }
    }

    private func drawVertices(
        shape: LabelmeShape,
        selected: Bool,
        palette: ShapePalette,
        transform: CanvasTransform,
        context: inout GraphicsContext
    ) {
        for point in shape.points {
            let screen = transform.screenPoint(point.cgPoint)
            let size: CGFloat = selected ? 9 : 6
            let rect = CGRect(x: screen.x - size / 2, y: screen.y - size / 2, width: size, height: size)
            var vertex = Path()
            if selected {
                vertex.addRect(rect)
            } else {
                vertex.addEllipse(in: rect)
            }
            context.fill(vertex, with: .color(selected ? .white : palette.stroke))
            context.stroke(vertex, with: .color(palette.stroke), lineWidth: 1)
        }
    }

    private func drawLabel(
        shape: LabelmeShape,
        palette: ShapePalette,
        transform: CanvasTransform,
        context: inout GraphicsContext
    ) {
        guard !shape.label.isEmpty, let first = shape.points.first else { return }
        let minPoint = shape.points.dropFirst().reduce(first.cgPoint) { partial, point in
            CGPoint(x: min(partial.x, point.x), y: min(partial.y, point.y))
        }
        let screen = transform.screenPoint(minPoint)
        context.draw(
            Text(shape.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.stroke),
            at: CGPoint(x: screen.x, y: screen.y - 10),
            anchor: .bottomLeading
        )
    }

    private func drawDraft(transform: CanvasTransform, context: inout GraphicsContext) {
        let points = draftPoints + [dragEnd].compactMap { $0 }
        guard !points.isEmpty else { return }

        let shape = LabelmeShape(
            label: currentLabel,
            points: points.map(LabelmePoint.init),
            shapeType: tool.shapeType
        )
        let path = renderPath(for: shape, transform: transform, forceOpen: tool == .polygon || tool == .linestrip)
        context.stroke(path, with: .color(.yellow), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        for point in points {
            let screen = transform.screenPoint(point)
            var vertex = Path()
            vertex.addEllipse(in: CGRect(x: screen.x - 4, y: screen.y - 4, width: 8, height: 8))
            context.fill(vertex, with: .color(.yellow))
        }
    }

    private func renderPath(for shape: LabelmeShape, transform: CanvasTransform, forceOpen: Bool = false) -> Path {
        var path = Path()
        let points = shape.points.map { transform.screenPoint($0.cgPoint) }
        guard let first = points.first else { return path }

        switch shape.shapeType {
        case .rectangle:
            guard points.count >= 2 else { return path }
            path.addRect(CGRect.fromCorners(points[0], points[1]))
        case .circle:
            guard points.count >= 2 else {
                path.addEllipse(in: CGRect(x: first.x - 3, y: first.y - 3, width: 6, height: 6))
                return path
            }
            let radius = hypot(points[1].x - points[0].x, points[1].y - points[0].y)
            path.addEllipse(in: CGRect(x: points[0].x - radius, y: points[0].y - radius, width: radius * 2, height: radius * 2))
        case .point, .points:
            for point in points {
                path.addEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
            }
        case .line, .linestrip:
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        case .polygon, .orientedRectangle, .mask:
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            if !forceOpen, points.count > 2 {
                path.closeSubpath()
            }
        }
        return path
    }

    private func canvasGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                handleDragChanged(value, size: size)
            }
            .onEnded { value in
                handleDragEnded(value, size: size)
            }
    }

    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let base = magnificationStartZoom ?? zoom
                if magnificationStartZoom == nil {
                    magnificationStartZoom = zoom
                }
                zoom = min(max(value * base, 0.2), 8)
            }
            .onEnded { _ in
                magnificationStartZoom = nil
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value, size: CGSize) {
        let transform = CanvasTransform(viewSize: size, imageSize: imageSize, zoom: zoom, pan: pan)
        let imagePoint = transform.imagePoint(value.location)

        switch tool {
        case .edit:
            if activeDrag == nil {
                let target = dragTarget(at: imagePoint, transform: transform)
                activeDrag = target
                if target.usesUndoGrouping {
                    onEditingBegan()
                }
                lastDragImagePoint = imagePoint
                lastDragScreenPoint = value.location
            }
            guard let activeDrag, let last = lastDragImagePoint else { return }
            let delta = CGPoint(x: imagePoint.x - last.x, y: imagePoint.y - last.y)
            switch activeDrag {
            case .vertex(let shapeID, let vertexIndex):
                updateVertex(shapeID: shapeID, vertexIndex: vertexIndex, to: imagePoint)
            case .shape(let shapeID):
                moveShape(shapeID: shapeID, by: delta)
            case .selectionToggle:
                break
            case .pan:
                if let lastDragScreenPoint {
                    pan.width += value.location.x - lastDragScreenPoint.x
                    pan.height += value.location.y - lastDragScreenPoint.y
                }
                self.activeDrag = .pan
            }
            lastDragImagePoint = imagePoint
            lastDragScreenPoint = value.location
        case .rectangle, .circle, .line:
            if dragStart == nil {
                dragStart = imagePoint
            }
            dragEnd = imagePoint
        case .polygon, .linestrip, .point:
            dragEnd = imagePoint
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, size: CGSize) {
        let transform = CanvasTransform(viewSize: size, imageSize: imageSize, zoom: zoom, pan: pan)
        let imagePoint = transform.imagePoint(value.location)
        let didDrag = abs(value.translation.width) > 4 || abs(value.translation.height) > 4

        switch tool {
        case .edit:
            if !didDrag {
                handleEditTap(at: imagePoint, transform: transform)
            }
        case .point:
            commit(points: [imagePoint], shapeType: .point)
        case .polygon:
            if shouldClosePolygon(with: imagePoint, transform: transform) {
                finishDraft()
            } else {
                draftPoints.append(clamped(imagePoint))
            }
        case .linestrip:
            draftPoints.append(clamped(imagePoint))
        case .rectangle:
            if let start = dragStart {
                commit(points: [start, imagePoint], shapeType: .rectangle)
            }
        case .circle:
            if let start = dragStart {
                commit(points: [start, imagePoint], shapeType: .circle)
            }
        case .line:
            if let start = dragStart {
                commit(points: [start, imagePoint], shapeType: .line)
            }
        }

        let finishedDrag = activeDrag
        activeDrag = nil
        lastDragImagePoint = nil
        lastDragScreenPoint = nil
        dragStart = nil
        dragEnd = nil
        if finishedDrag?.usesUndoGrouping == true {
            onEditingEnded()
        }
    }

    private func handleEditTap(at point: CGPoint, transform: CanvasTransform) {
        if isAddPointModifierPressed,
           let edge = nearestEditableEdge(at: point, transform: transform) {
            insertPoint(shapeID: edge.shapeID, after: edge.index, at: edge.point)
            return
        }

        if let vertex = nearestVertex(at: point, transform: transform) {
            selectedVertex = vertex
            selectedShapeID = vertex.shapeID
            selectedShapeIDs = [vertex.shapeID]
            return
        }

        if let selectedShapeID,
           let edge = nearestEdge(shapeID: selectedShapeID, at: point, transform: transform) {
            insertPoint(shapeID: selectedShapeID, after: edge.index, at: edge.point)
            return
        }
        if let hit = hitShapeID(at: point, transform: transform) {
            selectedShapeID = hit
            selectedVertex = nil
            if isMultiSelectModifierPressed {
                if selectedShapeIDs.contains(hit) {
                    selectedShapeIDs.remove(hit)
                    if selectedShapeID == hit {
                        selectedShapeID = selectedShapeIDs.first
                    }
                } else {
                    selectedShapeIDs.insert(hit)
                    selectedShapeID = hit
                }
            } else {
                selectedShapeIDs = [hit]
            }
        } else {
            if !isMultiSelectModifierPressed {
                selectedShapeID = nil
                selectedVertex = nil
                selectedShapeIDs.removeAll()
            }
        }
    }

    private func dragTarget(at point: CGPoint, transform: CanvasTransform) -> DragTarget {
        if isMultiSelectModifierPressed, hitShapeID(at: point, transform: transform) != nil {
            return .selectionToggle
        }

        if let vertex = nearestVertex(at: point, transform: transform) {
            selectedShapeID = vertex.shapeID
            selectedVertex = vertex
            if !selectedShapeIDs.contains(vertex.shapeID) {
                selectedShapeIDs = [vertex.shapeID]
            }
            return .vertex(shapeID: vertex.shapeID, vertexIndex: vertex.vertexIndex)
        }
        if let shapeID = hitShapeID(at: point, transform: transform) {
            selectedShapeID = shapeID
            selectedVertex = nil
            if !selectedShapeIDs.contains(shapeID) {
                selectedShapeIDs = [shapeID]
            }
            return .shape(shapeID: shapeID)
        }
        return .pan
    }

    private var canFinishDraft: Bool {
        switch tool {
        case .polygon:
            draftPoints.count >= 3
        case .linestrip:
            draftPoints.count >= 2
        default:
            false
        }
    }

    private func finishDraft() {
        guard canFinishDraft else { return }
        commit(points: draftPoints, shapeType: tool.shapeType)
        draftPoints.removeAll()
        dragEnd = nil
    }

    private func cancelDraft() {
        draftPoints.removeAll()
        dragStart = nil
        dragEnd = nil
        activeDrag = nil
        canUndoLastPoint = false
    }

    private func commit(points: [CGPoint], shapeType: LabelmeShapeType) {
        let cleanPoints = points.map { clamped($0) }
        guard !cleanPoints.isEmpty else { return }
        let shape = LabelmeShape(
            label: currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "object" : currentLabel,
            points: cleanPoints.map(LabelmePoint.init),
            shapeType: shapeType
        )
        annotation.shapes.append(shape)
        selectedShapeID = shape.id
        selectedVertex = nil
        selectedShapeIDs = [shape.id]
        onChange()
    }

    private func updateVertex(shapeID: UUID, vertexIndex: Int, to point: CGPoint) {
        guard let index = annotation.shapes.firstIndex(where: { $0.id == shapeID }),
              annotation.shapes[index].points.indices.contains(vertexIndex)
        else { return }
        annotation.shapes[index].points[vertexIndex] = LabelmePoint(clamped(point))
        selectedVertex = (shapeID, vertexIndex)
        onChange()
    }

    private func moveShape(shapeID: UUID, by delta: CGPoint) {
        let ids = selectedShapeIDs.contains(shapeID) ? selectedShapeIDs : [shapeID]
        annotation.shapes = annotation.shapes.map { shape in
            guard ids.contains(shape.id) else { return shape }
            var updated = shape
            updated.points = updated.points.map {
                LabelmePoint(x: $0.x + delta.x, y: $0.y + delta.y)
            }
            return updated
        }
        onChange()
    }

    private func insertPoint(shapeID: UUID, after vertexIndex: Int, at point: CGPoint) {
        guard let index = annotation.shapes.firstIndex(where: { $0.id == shapeID }) else { return }
        let shapeType = annotation.shapes[index].shapeType
        guard shapeType == .polygon || shapeType == .linestrip else { return }
        let insertionIndex = min(vertexIndex + 1, annotation.shapes[index].points.count)
        annotation.shapes[index].points.insert(LabelmePoint(clamped(point)), at: insertionIndex)
        selectedShapeID = shapeID
        selectedShapeIDs = [shapeID]
        selectedVertex = (shapeID, insertionIndex)
        onChange()
    }

    private func undoLastPoint() {
        guard !draftPoints.isEmpty else { return }
        draftPoints.removeLast()
        dragEnd = nil
        canUndoLastPoint = !draftPoints.isEmpty
    }

    private func removeSelectedPoint() {
        guard let selectedVertex,
              let index = annotation.shapes.firstIndex(where: { $0.id == selectedVertex.shapeID }),
              annotation.shapes[index].points.indices.contains(selectedVertex.vertexIndex)
        else { return }
        let shapeType = annotation.shapes[index].shapeType
        if shapeType == .polygon, annotation.shapes[index].points.count <= 3 { return }
        if shapeType == .linestrip, annotation.shapes[index].points.count <= 2 { return }
        guard shapeType == .polygon || shapeType == .linestrip else { return }
        annotation.shapes[index].points.remove(at: selectedVertex.vertexIndex)
        self.selectedVertex = nil
        onChange()
    }

    private func shouldClosePolygon(with point: CGPoint, transform: CanvasTransform) -> Bool {
        guard tool == .polygon, draftPoints.count >= 3, let first = draftPoints.first else { return false }
        let distance = hypot(
            transform.screenPoint(first).x - transform.screenPoint(point).x,
            transform.screenPoint(first).y - transform.screenPoint(point).y
        )
        return distance < 18
    }

    private func nearestVertex(at point: CGPoint, transform: CanvasTransform) -> (shapeID: UUID, vertexIndex: Int)? {
        let threshold = max(7 / transform.scale, 1.5)
        var best: (UUID, Int, CGFloat)?
        for shape in annotation.shapes.reversed() where shape.isVisible {
            for (index, vertex) in shape.points.enumerated() {
                let distance = hypot(vertex.cgPoint.x - point.x, vertex.cgPoint.y - point.y)
                guard distance < threshold else { continue }
                if best == nil || distance < best!.2 {
                    best = (shape.id, index, distance)
                }
            }
        }
        guard let best else { return nil }
        return (best.0, best.1)
    }

    private func nearestEdge(shapeID: UUID, at point: CGPoint, transform: CanvasTransform) -> (index: Int, point: CGPoint)? {
        guard let shape = annotation.shapes.first(where: { $0.id == shapeID }),
              shape.shapeType == .polygon || shape.shapeType == .linestrip,
              shape.points.count >= 2
        else { return nil }
        let threshold = max(8 / transform.scale, 2)
        var best: (Int, CGPoint, CGFloat)?
        let points = shape.points.map(\.cgPoint)
        let limit = shape.shapeType == .polygon ? points.count : points.count - 1
        for index in 0..<limit {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let projection = closestPoint(onSegmentFrom: start, to: end, point: point)
            let distance = hypot(projection.x - point.x, projection.y - point.y)
            guard distance < threshold else { continue }
            if best == nil || distance < best!.2 {
                best = (index, projection, distance)
            }
        }
        guard let best else { return nil }
        return (best.0, best.1)
    }

    private func nearestEditableEdge(at point: CGPoint, transform: CanvasTransform) -> (shapeID: UUID, index: Int, point: CGPoint)? {
        for shape in annotation.shapes.reversed() where shape.isVisible && (shape.shapeType == .polygon || shape.shapeType == .linestrip) {
            guard let edge = nearestEdge(shapeID: shape.id, at: point, transform: transform) else { continue }
            return (shape.id, edge.index, edge.point)
        }
        return nil
    }

    private func hitShapeID(at point: CGPoint, transform: CanvasTransform) -> UUID? {
        let threshold = max(7 / transform.scale, 2)
        for shape in annotation.shapes.reversed() where shape.isVisible {
            if shapeContains(shape, point: point, threshold: threshold) {
                return shape.id
            }
        }
        return nil
    }

    private func shapeContains(_ shape: LabelmeShape, point: CGPoint, threshold: CGFloat) -> Bool {
        let points = shape.points.map(\.cgPoint)
        guard let first = points.first else { return false }
        switch shape.shapeType {
        case .rectangle:
            guard points.count >= 2 else { return false }
            return CGRect.fromCorners(points[0], points[1]).insetBy(dx: -threshold, dy: -threshold).contains(point)
        case .circle:
            guard points.count >= 2 else { return false }
            let radius = hypot(points[1].x - first.x, points[1].y - first.y)
            return abs(hypot(point.x - first.x, point.y - first.y) - radius) <= threshold
                || hypot(point.x - first.x, point.y - first.y) < radius
        case .point, .points:
            return points.contains { hypot($0.x - point.x, $0.y - point.y) < threshold }
        case .line, .linestrip:
            return nearestDistanceToPolyline(points: points, point: point, closed: false) < threshold
        case .polygon, .orientedRectangle, .mask:
            return pointInPolygon(point, polygon: points)
                || nearestDistanceToPolyline(points: points, point: point, closed: true) < threshold
        }
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), imageSize.width),
            y: min(max(point.y, 0), imageSize.height)
        )
    }

    private var imageSize: CGSize {
        CGSize(width: max(annotation.imageWidth, 1), height: max(annotation.imageHeight, 1))
    }
}

private enum DragTarget: Equatable {
    case vertex(shapeID: UUID, vertexIndex: Int)
    case shape(shapeID: UUID)
    case selectionToggle
    case pan

    var usesUndoGrouping: Bool {
        switch self {
        case .vertex, .shape:
            true
        case .selectionToggle, .pan:
            false
        }
    }
}

private enum ImageAdjustmentRenderer {
    private static let context = CIContext()

    static func adjustedImage(from image: UIImage, brightness: Double, contrast: Double) -> UIImage? {
        let brightness = clamped(brightness)
        let contrast = clamped(contrast)
        guard needsAdjustment(brightness: brightness, contrast: contrast),
              let cgImage = image.cgImage
        else { return nil }

        var output = CIImage(cgImage: cgImage)
        let extent = output.extent

        if abs(brightness - ImageAdjustmentDefaults.neutral) >= 0.005 {
            let filter = CIFilter.colorMatrix()
            filter.inputImage = output
            let factor = CGFloat(brightness)
            filter.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
            filter.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
            filter.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
            filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            guard let filtered = filter.outputImage else { return nil }
            output = filtered
        }

        if abs(contrast - ImageAdjustmentDefaults.neutral) >= 0.005 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.saturation = 1
            filter.brightness = 0
            filter.contrast = Float(contrast)
            guard let filtered = filter.outputImage else { return nil }
            output = filtered
        }

        guard let adjusted = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: adjusted, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func needsAdjustment(brightness: Double, contrast: Double) -> Bool {
        abs(brightness - ImageAdjustmentDefaults.neutral) >= 0.005
            || abs(contrast - ImageAdjustmentDefaults.neutral) >= 0.005
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, ImageAdjustmentDefaults.range.lowerBound), ImageAdjustmentDefaults.range.upperBound)
    }
}

private struct CanvasTransform {
    let viewSize: CGSize
    let imageSize: CGSize
    let zoom: CGFloat
    let pan: CGSize

    var baseScale: CGFloat {
        min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    }

    var scale: CGFloat {
        baseScale * zoom
    }

    var imageRect: CGRect {
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (viewSize.width - displaySize.width) / 2 + pan.width,
            y: (viewSize.height - displaySize.height) / 2 + pan.height,
            width: displaySize.width,
            height: displaySize.height
        )
    }

    func screenPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x * scale, y: imageRect.minY + point.y * scale)
    }

    func imagePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - imageRect.minX) / scale, y: (point.y - imageRect.minY) / scale)
    }
}

private struct ShapePalette {
    let stroke: Color
    let fill: Color

    init(label: String, selected: Bool) {
        let base = Color.labelmeColor(for: label)
        if selected {
            stroke = .white
            fill = base.opacity(0.34)
        } else {
            stroke = base
            fill = base.opacity(0.20)
        }
    }
}

private extension LabelmeShapeType {
    var fillsInterior: Bool {
        switch self {
        case .line, .linestrip, .point, .points:
            false
        default:
            true
        }
    }
}

private extension CGRect {
    static func fromCorners(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }
}

private func closestPoint(onSegmentFrom a: CGPoint, to b: CGPoint, point: CGPoint) -> CGPoint {
    let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
    let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
    let lengthSquared = ab.x * ab.x + ab.y * ab.y
    guard lengthSquared > 0 else { return a }
    let t = min(max((ap.x * ab.x + ap.y * ab.y) / lengthSquared, 0), 1)
    return CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
}

private func nearestDistanceToPolyline(points: [CGPoint], point: CGPoint, closed: Bool) -> CGFloat {
    guard points.count >= 2 else { return .greatestFiniteMagnitude }
    let limit = closed ? points.count : points.count - 1
    var best = CGFloat.greatestFiniteMagnitude
    for index in 0..<limit {
        let projection = closestPoint(onSegmentFrom: points[index], to: points[(index + 1) % points.count], point: point)
        best = min(best, hypot(projection.x - point.x, projection.y - point.y))
    }
    return best
}

private func pointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
    guard polygon.count >= 3 else { return false }
    var inside = false
    var j = polygon.count - 1
    for i in polygon.indices {
        let pi = polygon[i]
        let pj = polygon[j]
        if ((pi.y > point.y) != (pj.y > point.y))
            && (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
            inside.toggle()
        }
        j = i
    }
    return inside
}
