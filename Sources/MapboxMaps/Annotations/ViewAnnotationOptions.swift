import Foundation
import UIKit

public struct ViewAnnotationOptions: Hashable {
    public var geometry: Geometry? {
        didSet {
            mbxGeometry = geometry.map({ MapboxCommon.Geometry.init($0) }) ?? nil
        }
    }
    public var width: CGFloat?
    public var height: CGFloat?
    public var associatedFeatureId: String?
    public var allowOverlap: Bool?
    public var visible: Bool?
    public var anchor: ViewAnnotationAnchor?
    public var offsetX: CGFloat?
    public var offsetY: CGFloat?
    public var selected: Bool?

    // Used for hashing and constructing objc value
    fileprivate var mbxGeometry: MapboxCommon.Geometry?

    //TODO: Add documentation
    public init(geometry: Geometry? = nil,
                width: CGFloat? = nil,
                height: CGFloat? = nil,
                associatedFeatureId: String? = nil,
                allowOverlap: Bool? = nil,
                visible: Bool? = nil,
                anchor: ViewAnnotationAnchor? = nil,
                offsetX: CGFloat? = nil,
                offsetY: CGFloat? = nil,
                selected: Bool? = nil) {
        self.geometry = geometry
        self.width = width
        self.height = height
        self.associatedFeatureId = associatedFeatureId
        self.allowOverlap = allowOverlap
        self.visible = visible
        self.anchor = anchor
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.selected = selected
        self.mbxGeometry = geometry.map({ MapboxCommon.Geometry.init($0) }) ?? nil
    }

    internal init(_ objcValue: MapboxCoreMaps.ViewAnnotationOptions) {
        self.init(
            geometry: objcValue.__geometry.map({ Geometry($0) }) ?? nil,
            width: objcValue.__width?.CGFloat,
            height: objcValue.__height?.CGFloat,
            associatedFeatureId: objcValue.__associatedFeatureId,
            allowOverlap: objcValue.__allowOverlap?.boolValue,
            visible: objcValue.__visible?.boolValue,
            anchor: objcValue.__anchor.map({ ViewAnnotationAnchor(rawValue: $0.intValue) }) ?? nil,
            offsetX: objcValue.__offsetX?.CGFloat,
            offsetY: objcValue.__offsetY?.CGFloat,
            selected: objcValue.__selected?.boolValue
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mbxGeometry)
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(associatedFeatureId)
        hasher.combine(allowOverlap)
        hasher.combine(visible)
        hasher.combine(anchor)
        hasher.combine(offsetX)
        hasher.combine(offsetY)
        hasher.combine(selected)
    }
}

extension MapboxCoreMaps.ViewAnnotationOptions {
    public convenience init(_ swiftValue: ViewAnnotationOptions) {
        self.init(__geometry: swiftValue.mbxGeometry,
                  associatedFeatureId: swiftValue.associatedFeatureId,
                  width: swiftValue.width as NSNumber?,
                  height: swiftValue.height as NSNumber?,
                  allowOverlap: swiftValue.allowOverlap as NSNumber?,
                  visible: swiftValue.visible as NSNumber?,
                  anchor: swiftValue.anchor?.rawValue as NSNumber?,
                  offsetX: swiftValue.offsetX as NSNumber?,
                  offsetY: swiftValue.offsetY as NSNumber?,
                  selected: swiftValue.selected as NSNumber?)
    }
}
