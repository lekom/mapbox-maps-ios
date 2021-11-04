import UIKit
@_implementationOnly import MapboxCommon_Private
@_implementationOnly import MapboxCoreMaps_Private

public protocol ViewAnnotationManager: AnyObject {
    // TODO: Add documentation
    func addViewAnnotation(_ view: UIView, _ options: ViewAnnotationOptions) throws -> AnnotationView
    func removeViewAnnotation(_ annotatonView: AnnotationView) -> Bool
    func updateViewAnnotation(_ annotatonView: AnnotationView, _ options: ViewAnnotationOptions) -> Bool
    func getViewAnnotation(byFeatureId identifier: String) -> AnnotationView?
    func getViewAnnotationOptions(byFeatureId identifier: String) -> ViewAnnotationOptions?
    func getViewAnnotationOptions(byAnnotationView view: AnnotationView) -> ViewAnnotationOptions?
}

public enum ViewAnnotationManagerError: Error {
    case geometryFieldMissing
}

internal class ViewAnnotationManagerImpl: ViewAnnotationManager {

    private let mapboxMap: MapboxMapProtocol
    private let viewAnnotationWrapper = UIView(frame: .zero)
    private var annotationViewsById: [String: AnnotationView] = [:]
    private var annotationIdByViews: [AnnotationView: String] = [:]

    internal init(view: UIView, mapboxMap: MapboxMapProtocol) {
        view.insertSubview(viewAnnotationWrapper, at: 1)
        viewAnnotationWrapper.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            viewAnnotationWrapper.topAnchor.constraint(equalTo: view.topAnchor),
            viewAnnotationWrapper.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            viewAnnotationWrapper.leftAnchor.constraint(equalTo: view.leftAnchor),
            viewAnnotationWrapper.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])

        self.mapboxMap = mapboxMap
        mapboxMap.setViewAnnotationPositionsUpdateListenerFor(listener: self)
    }

    // MARK: - ViewAnnotationManagerInterface protocol functions

    public func addViewAnnotation(_ view: UIView, _ options: ViewAnnotationOptions) throws -> AnnotationView {
        guard options.geometry != nil else {
            throw ViewAnnotationManagerError.geometryFieldMissing
        }
        let annotatonView = AnnotationView(view: view, annotationManager: self)
        annotationViewsById[annotatonView.id] = annotatonView
        annotationIdByViews[annotatonView] = annotatonView.id
        viewAnnotationWrapper.addSubview(annotatonView)
        mapboxMap.addViewAnnotation(forId: annotatonView.id, options: options)
        return annotatonView
    }

    public func removeViewAnnotation(_ annotatonView: AnnotationView) -> Bool {
        guard let id = annotationIdByViews[annotatonView], let annotatonView = annotationViewsById[id] else {
            return false
        }
        mapboxMap.removeViewAnnotation(forId: id)
        annotatonView.removeFromSuperview()
        annotationViewsById.removeValue(forKey: id)
        annotationIdByViews.removeValue(forKey: annotatonView)
        return true
    }

    public func updateViewAnnotation(_ annotatonView: AnnotationView, _ options: ViewAnnotationOptions) -> Bool {
        guard let id = annotationIdByViews[annotatonView] else {
            return false
        }
        mapboxMap.updateViewAnnotation(forId: id, options: options)
        return true
    }

    public func getViewAnnotation(byFeatureId identifier: String) -> AnnotationView? {
        guard let id = annotationViewsById.keys.first(where: { id in
            (try? mapboxMap.getViewAnnotationOptions(forId: id).associatedFeatureId == identifier) ?? false
        }) else {
            // TODO: Error for not available annotation
            return nil
        }
        return annotationViewsById[id]
    }

    public func getViewAnnotationOptions(byAnnotationView view: AnnotationView) -> ViewAnnotationOptions? {
        guard let id = annotationIdByViews[view] else {
            // TODO: gracefully handle error
            return nil
        }
        return try? mapboxMap.getViewAnnotationOptions(forId: id)
    }

    func getViewAnnotationOptions(byFeatureId identifier: String) -> ViewAnnotationOptions? {
        return getViewAnnotation(byFeatureId: identifier).map({ view in getViewAnnotationOptions(byAnnotationView: view) }) ?? nil
    }

    // MARK: - Internal functions

    // Iterate through and update all view annotations
    // First update the position of the views based on the placement info from GL-Native
    // Then hide the views which are off screen
    internal func placeAnnotations(positions: [ViewAnnotationPositionDescriptor]) {
        var visibleAnnotationIds: Set<String> = []

        for position in positions {
            validateAnnotation(byAnnotationId: position.identifier)
            guard let annotationView = annotationViewsById[position.identifier] else {
                fatalError()
            }
            // TODO: Check if position depends on the device's pixel ratio. (In a previous commit this was divided by two for some reason.)
            annotationView.frame = CGRect(
                origin: position.leftTopCoordinate.point,
                size: CGSize(width: CGFloat(position.width), height: CGFloat(position.height))
            )

            annotationView.setVisibilityWithoutUpdate(isHidden: false)
            visibleAnnotationIds.insert(position.identifier)
        }

        let annotationsToHide = Set<String>(annotationViewsById.keys).subtracting(visibleAnnotationIds)
        for id in annotationsToHide {
            validateAnnotation(byAnnotationId: id)
            if let annotationView = annotationViewsById[id] {
                annotationView.setVisibilityWithoutUpdate(isHidden: true)
            }
        }
    }

    internal func validateAnnotation(byAnnotationId id: String) {
        guard let annotationView = annotationViewsById[id] else { return }
        // If the user explicitly removed the ViewAnnotation or it's warpped view
        // then we need to remove it from our layout calculation
        if annotationView.subviews.isEmpty || annotationView.superview == nil {
            _ = removeViewAnnotation(annotationView)
        }
        if let wrappedView = annotationView.subviews.first, wrappedView.isHidden {
            // View is still considered for layout calculation, users should not modify the visibility of the wrapped view
            // TODO: Print warning
        }
    }

}

extension ViewAnnotationManagerImpl: ViewAnnotationPositionsListener {

    public func onViewAnnotationPositionsUpdate(forPositions positions: [ViewAnnotationPositionDescriptor]) {
        placeAnnotations(positions: positions)
    }

}

public final class AnnotationView: UIView {

    private static var currentId = 0
    internal let id: String = {
        let id = String(currentId)
        currentId += 1
        return id
    }()
    internal let wrappedView: UIView
    internal var ignoreUserEvents: Bool = false

    // In case the user changes the visibility of the AnnotationView, we should update the options to remove it from the layout calculation
    public override var isHidden: Bool {
        didSet {
            guard !ignoreUserEvents else { return }
            guard let manager = annotationManager else { return }
            let options = manager.getViewAnnotationOptions(byAnnotationView: self)
            let visible = !isHidden
            if visible != options?.visible {
                _ = manager.updateViewAnnotation(self, ViewAnnotationOptions(visible: visible))
            }
        }
    }
    private weak var annotationManager: ViewAnnotationManagerImpl?

    internal init(view: UIView, annotationManager: ViewAnnotationManagerImpl) {
        wrappedView = view
        self.annotationManager = annotationManager
        super.init(frame: .zero)

        addSubview(wrappedView)
        wrappedView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            wrappedView.topAnchor.constraint(equalTo: topAnchor),
            wrappedView.bottomAnchor.constraint(equalTo: bottomAnchor),
            wrappedView.leftAnchor.constraint(equalTo: leftAnchor),
            wrappedView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }

    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func setVisibilityWithoutUpdate(isHidden: Bool) {
        ignoreUserEvents = true
        self.isHidden = isHidden
        ignoreUserEvents = false
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return wrappedView.point(inside: point, with: event)
    }

}
