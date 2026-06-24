import CoreGraphics
import Foundation
import SwiftUI

struct ServerHealth: Decodable {
    let ok: Bool
    let datasetRoot: String
    let imagesRoot: String
    let labelsRoot: String
    let imageCount: Int
    let annotatedCount: Int
    let hostHint: String?
}

struct DatasetImageListResponse: Decodable {
    let datasetRoot: String
    let imagesRoot: String
    let labelsRoot: String
    let offset: Int
    let limit: Int
    let total: Int
    let items: [DatasetImageItem]
}

struct DatasetImageItem: Decodable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let stem: String
    let relativePath: String
    let labelPath: String
    let imageUrl: String
    let annotationUrl: String
    let annotated: Bool
    let shapeCount: Int
    let labels: [String]
    let imageWidth: Int?
    let imageHeight: Int?
    let updatedAt: Double?
}

enum LabelmeIcon {
    case aiBox
    case aiPoints
    case brightnessContrast
    case circle
    case circlesFour
    case clear
    case connect
    case copy
    case delete
    case edit
    case eye
    case fileList
    case fitWindow
    case folderOpen
    case image
    case info
    case labels
    case line
    case lineStrip
    case next
    case paintBucket
    case point
    case polygon
    case previous
    case question
    case rectangle
    case redo
    case save
    case undo
    case zoomIn
    case zoomOut

    var assetName: String {
        switch self {
        case .aiBox: "labelme_ai_box"
        case .aiPoints: "labelme_ai_points"
        case .brightnessContrast: "labelme_brightness_contrast"
        case .circle: "labelme_circle"
        case .circlesFour: "labelme_circles_four"
        case .clear: "labelme_x_circle"
        case .connect: "labelme_frame_arrows_horizontal"
        case .copy: "labelme_copy"
        case .delete: "labelme_trash"
        case .edit: "labelme_note_pencil"
        case .eye: "labelme_eye"
        case .fileList: "labelme_folders"
        case .fitWindow: "labelme_frame_corners"
        case .folderOpen: "labelme_folder_open"
        case .image: "labelme_image_square"
        case .info: "labelme_info"
        case .labels: "labelme_layout_duotone"
        case .line: "labelme_line_segment"
        case .lineStrip: "labelme_line_segments"
        case .next: "labelme_arrow_fat_right"
        case .paintBucket: "labelme_paint_bucket"
        case .point: "labelme_circles_four"
        case .polygon: "labelme_polygon"
        case .previous: "labelme_arrow_fat_left"
        case .question: "labelme_question"
        case .rectangle: "labelme_rectangle"
        case .redo: "labelme_arrow_u_up_left"
        case .save: "labelme_floppy_disk"
        case .undo: "labelme_arrow_u_up_left"
        case .zoomIn: "labelme_magnifying_glass_plus"
        case .zoomOut: "labelme_magnifying_glass_minus"
        }
    }

    var isFlippedHorizontally: Bool {
        self == .redo
    }
}

struct LabelmeIconView: View {
    let icon: LabelmeIcon
    var size: CGFloat = 18

    var body: some View {
        Image(icon.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: icon.isFlippedHorizontally ? -1 : 1, y: 1)
    }
}

struct LabelmeMenuLabel: View {
    let title: String
    let icon: LabelmeIcon

    var body: some View {
        Label {
            Text(title)
        } icon: {
            LabelmeIconView(icon: icon, size: 16)
        }
    }
}

struct LabelmeAnnotation: Codable, Equatable {
    var version: String
    var flags: [String: Bool]
    var shapes: [LabelmeShape]
    var imagePath: String
    var imageData: String?
    var imageHeight: Int
    var imageWidth: Int
    var imageUrl: String?
    var extra: [String: JSONValue] = [:]

    enum CodingKeys: String, CodingKey {
        case version
        case flags
        case shapes
        case imagePath
        case imageData
        case imageHeight
        case imageWidth
        case imageUrl
    }

    init(
        version: String,
        flags: [String: Bool],
        shapes: [LabelmeShape],
        imagePath: String,
        imageData: String?,
        imageHeight: Int,
        imageWidth: Int,
        imageUrl: String?,
        extra: [String: JSONValue] = [:]
    ) {
        self.version = version
        self.flags = flags
        self.shapes = shapes
        self.imagePath = imagePath
        self.imageData = imageData
        self.imageHeight = imageHeight
        self.imageWidth = imageWidth
        self.imageUrl = imageUrl
        self.extra = extra
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "5.5.0"
        flags = try container.decodeIfPresent([String: Bool].self, forKey: .flags) ?? [:]
        shapes = try container.decodeIfPresent([LabelmeShape].self, forKey: .shapes) ?? []
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath) ?? ""
        imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight) ?? 0
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth) ?? 0
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)

        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        extra = try raw.decodeExtra(excluding: CodingKeys.reservedKeys)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(version, forKey: AnyCodingKey("version"))
        try container.encode(flags, forKey: AnyCodingKey("flags"))
        try container.encode(shapes, forKey: AnyCodingKey("shapes"))
        try container.encode(imagePath, forKey: AnyCodingKey("imagePath"))
        try container.encodeIfPresent(imageData, forKey: AnyCodingKey("imageData"))
        try container.encode(imageHeight, forKey: AnyCodingKey("imageHeight"))
        try container.encode(imageWidth, forKey: AnyCodingKey("imageWidth"))
        try container.encodeIfPresent(imageUrl, forKey: AnyCodingKey("imageUrl"))
        try container.encodeExtra(extra, excluding: CodingKeys.reservedKeys)
    }
}

struct LabelmeShape: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var label: String
    var points: [LabelmePoint]
    var groupID: Int?
    var description: String?
    var shapeType: LabelmeShapeType
    var flags: [String: Bool]
    var mask: String?
    var isVisible = true
    var extra: [String: JSONValue] = [:]

    enum CodingKeys: String, CodingKey {
        case label
        case points
        case groupID = "group_id"
        case description
        case shapeType = "shape_type"
        case flags
        case mask
    }

    init(
        id: UUID = UUID(),
        label: String,
        points: [LabelmePoint],
        groupID: Int? = nil,
        description: String? = "",
        shapeType: LabelmeShapeType = .polygon,
        flags: [String: Bool] = [:],
        mask: String? = nil,
        isVisible: Bool = true,
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id
        self.label = label
        self.points = points
        self.groupID = groupID
        self.description = description
        self.shapeType = shapeType
        self.flags = flags
        self.mask = mask
        self.isVisible = isVisible
        self.extra = extra
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        points = try container.decode([LabelmePoint].self, forKey: .points)
        groupID = try container.decodeIfPresent(Int.self, forKey: .groupID)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        shapeType = try container.decodeIfPresent(LabelmeShapeType.self, forKey: .shapeType) ?? .polygon
        flags = try container.decodeIfPresent([String: Bool].self, forKey: .flags) ?? [:]
        mask = try container.decodeIfPresent(String.self, forKey: .mask)
        id = UUID()
        isVisible = true
        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        extra = try raw.decodeExtra(excluding: CodingKeys.reservedKeys)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(label, forKey: AnyCodingKey("label"))
        try container.encode(points, forKey: AnyCodingKey("points"))
        try container.encodeIfPresent(groupID, forKey: AnyCodingKey("group_id"))
        try container.encode(description ?? "", forKey: AnyCodingKey("description"))
        try container.encode(shapeType, forKey: AnyCodingKey("shape_type"))
        try container.encode(flags, forKey: AnyCodingKey("flags"))
        try container.encodeIfPresent(mask, forKey: AnyCodingKey("mask"))
        try container.encodeExtra(extra, excluding: CodingKeys.reservedKeys)
    }
}

enum JSONValue: Codable, Equatable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct AnyCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

struct LabelmePoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum LabelmeShapeType: String, Codable, CaseIterable, Identifiable {
    case polygon
    case rectangle
    case orientedRectangle = "oriented_rectangle"
    case point
    case line
    case circle
    case linestrip
    case points
    case mask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .polygon: "Polygon"
        case .rectangle: "Rectangle"
        case .orientedRectangle: "Oriented Rectangle"
        case .point: "Point"
        case .line: "Line"
        case .circle: "Circle"
        case .linestrip: "LineStrip"
        case .points: "Points"
        case .mask: "Mask"
        }
    }

    var icon: LabelmeIcon {
        switch self {
        case .polygon: .polygon
        case .rectangle: .rectangle
        case .orientedRectangle: .rectangle
        case .point: .point
        case .line: .line
        case .circle: .circle
        case .linestrip: .lineStrip
        case .points: .aiPoints
        case .mask: .aiBox
        }
    }
}

enum CanvasTool: String, CaseIterable, Identifiable {
    case edit
    case polygon
    case rectangle
    case circle
    case line
    case point
    case linestrip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: "Edit Shapes"
        case .polygon: "Polygon"
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        case .line: "Line"
        case .point: "Point"
        case .linestrip: "LineStrip"
        }
    }

    var icon: LabelmeIcon {
        switch self {
        case .edit: .edit
        case .polygon: .polygon
        case .rectangle: .rectangle
        case .circle: .circle
        case .line: .line
        case .point: .point
        case .linestrip: .lineStrip
        }
    }

    var shapeType: LabelmeShapeType {
        switch self {
        case .edit: .polygon
        case .polygon: .polygon
        case .rectangle: .rectangle
        case .circle: .circle
        case .line: .line
        case .point: .point
        case .linestrip: .linestrip
        }
    }
}

enum CanvasCommand: String, Identifiable {
    case fit
    case zoomIn
    case zoomOut
    case cancelDraft

    var id: String { rawValue }
}

private extension LabelmeAnnotation.CodingKeys {
    static let reservedKeys: Set<String> = [
        "version",
        "flags",
        "shapes",
        "imagePath",
        "imageData",
        "imageHeight",
        "imageWidth",
        "imageUrl",
    ]
}

private extension LabelmeShape.CodingKeys {
    static let reservedKeys: Set<String> = [
        "label",
        "points",
        "group_id",
        "description",
        "shape_type",
        "flags",
        "mask",
    ]
}

private extension KeyedDecodingContainer where Key == AnyCodingKey {
    func decodeExtra(excluding reservedKeys: Set<String>) throws -> [String: JSONValue] {
        var extra: [String: JSONValue] = [:]
        for key in allKeys where !reservedKeys.contains(key.stringValue) {
            extra[key.stringValue] = try decode(JSONValue.self, forKey: key)
        }
        return extra
    }
}

private extension KeyedEncodingContainer where Key == AnyCodingKey {
    mutating func encodeExtra(_ extra: [String: JSONValue], excluding reservedKeys: Set<String>) throws {
        for (key, value) in extra where !reservedKeys.contains(key) {
            try encode(value, forKey: AnyCodingKey(key))
        }
    }
}

extension LabelmeShape {
    var pointSummary: String {
        switch shapeType {
        case .rectangle, .circle, .line:
            "\(points.count) pts"
        case .point:
            "1 pt"
        default:
            "\(points.count) pts"
        }
    }

    var bounds: CGRect {
        guard let first = points.first?.cgPoint else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point.cgPoint, size: .zero))
        }
    }

    func copyForPaste(offset: Double) -> LabelmeShape {
        LabelmeShape(
            label: label,
            points: points.map { LabelmePoint(x: $0.x + offset, y: $0.y + offset) },
            groupID: groupID,
            description: description,
            shapeType: shapeType,
            flags: flags,
            mask: mask,
            isVisible: isVisible,
            extra: extra
        )
    }
}

extension Color {
    static func labelmeColor(for label: String) -> Color {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return Color(red: 0.0, green: 1.0, blue: 0.0)
        }
        var hash: UInt32 = 2_166_136_261
        for byte in normalized.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.82, brightness: 0.96)
    }
}

enum LabelmePolygonConnector {
    enum ConnectError: LocalizedError {
        case tooFewPoints
        case degenerateStartEdge

        var errorDescription: String? {
            switch self {
            case .tooFewPoints:
                "Both polygons must have at least 3 points."
            case .degenerateStartEdge:
                "Polygon must have a non-zero edge at its start point."
            }
        }
    }

    static func connect(_ first: [LabelmePoint], _ second: [LabelmePoint]) throws -> [LabelmePoint] {
        guard first.count >= 3, second.count >= 3 else {
            throw ConnectError.tooFewPoints
        }

        let polygon1 = first.map(\.cgPoint)
        let polygon2 = second.map(\.cgPoint)
        let start1 = polygon1[0]
        let start2 = polygon2[0]
        let bridgeLength = distance(start1, start2)
        let stepPixels = min(8.0, max(2.0, bridgeLength * 0.03))

        let bridge1 = try bridgePointTowardsOtherPolygon(
            polygon: polygon1,
            otherStart: start2,
            stepPixels: stepPixels
        )
        let bridge2 = try bridgePointTowardsOtherPolygon(
            polygon: polygon2,
            otherStart: start1,
            stepPixels: stepPixels
        )

        let firstOuter = boundaryAvoidingStartEdge(
            polygon: polygon1,
            bridge: bridge1.point,
            neighborIndex: bridge1.neighborIndex,
            target: .start
        )
        let secondOuter = boundaryAvoidingStartEdge(
            polygon: polygon2,
            bridge: bridge2.point,
            neighborIndex: bridge2.neighborIndex,
            target: .bridge
        )

        let merged = removeNearDuplicatePoints(firstOuter + [start2] + secondOuter + [bridge1.point])
        guard merged.count >= 3 else {
            throw ConnectError.tooFewPoints
        }
        return merged.map(LabelmePoint.init)
    }

    private struct BridgePoint {
        let point: CGPoint
        let neighborIndex: Int
    }

    private enum BoundaryTarget {
        case start
        case bridge
    }

    private static func bridgePointTowardsOtherPolygon(
        polygon: [CGPoint],
        otherStart: CGPoint,
        stepPixels: CGFloat
    ) throws -> BridgePoint {
        let start = polygon[0]
        var targetDirection = CGPoint(x: otherStart.x - start.x, y: otherStart.y - start.y)
        let targetNorm = length(targetDirection)
        if targetNorm == 0 {
            targetDirection = CGPoint(x: 1, y: 0)
        } else {
            targetDirection = CGPoint(x: targetDirection.x / targetNorm, y: targetDirection.y / targetNorm)
        }

        var bestScore = -CGFloat.greatestFiniteMagnitude
        var best: BridgePoint?
        for neighborIndex in [polygon.count - 1, 1] {
            let neighbor = polygon[neighborIndex]
            let edge = CGPoint(x: neighbor.x - start.x, y: neighbor.y - start.y)
            let edgeNorm = length(edge)
            guard edgeNorm > 0 else { continue }
            let edgeDirection = CGPoint(x: edge.x / edgeNorm, y: edge.y / edgeNorm)
            let score = edgeDirection.x * targetDirection.x + edgeDirection.y * targetDirection.y
            let stepRatio = min(0.45, stepPixels / edgeNorm)
            let candidate = CGPoint(x: start.x + edge.x * stepRatio, y: start.y + edge.y * stepRatio)
            if score > bestScore {
                bestScore = score
                best = BridgePoint(point: candidate, neighborIndex: neighborIndex)
            }
        }

        guard let best else {
            throw ConnectError.degenerateStartEdge
        }
        return best
    }

    private static func boundaryAvoidingStartEdge(
        polygon: [CGPoint],
        bridge: CGPoint,
        neighborIndex: Int,
        target: BoundaryTarget
    ) -> [CGPoint] {
        let count = polygon.count
        if neighborIndex == 1 {
            switch target {
            case .start:
                return [bridge] + Array(polygon[1..<count]) + [polygon[0]]
            case .bridge:
                return [polygon[0]] + (1..<count).reversed().map { polygon[$0] } + [bridge]
            }
        } else {
            switch target {
            case .start:
                return [bridge] + (1..<count).reversed().map { polygon[$0] } + [polygon[0]]
            case .bridge:
                return [polygon[0]] + Array(polygon[1..<count]) + [bridge]
            }
        }
    }

    private static func removeNearDuplicatePoints(_ points: [CGPoint]) -> [CGPoint] {
        var cleaned: [CGPoint] = []
        for point in points {
            if let last = cleaned.last, distance(last, point) < 0.001 {
                continue
            }
            cleaned.append(point)
        }
        if let first = cleaned.first, let last = cleaned.last, distance(first, last) < 0.001 {
            cleaned.removeLast()
        }
        return cleaned
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func length(_ point: CGPoint) -> CGFloat {
        hypot(point.x, point.y)
    }
}
