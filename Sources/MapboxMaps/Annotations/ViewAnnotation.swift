import UIKit
@_implementationOnly import MapboxCommon_Private
@_implementationOnly import MapboxCoreMaps_Private

public enum ViewAnnotationManagerError: Error {
    case geometryFieldMissing
}

// TODO: Add documentation
public final class ViewAnnotationManager {

    private let containerView: SubviewInteractionOnlyView
    private let mapboxMap: MapboxMapProtocol
    private var annotationViewsById: [String: AnnotationView] = [:]
    private var annotationIdByViews: [AnnotationView: String] = [:]

    internal init(containerView: SubviewInteractionOnlyView, mapboxMap: MapboxMapProtocol) {
        self.containerView = containerView
        self.mapboxMap = mapboxMap
        let delegatingPositionsListener = DelegatingViewAnnotationPositionsListener()
        delegatingPositionsListener.delegate = self
        mapboxMap.setViewAnnotationPositionsUpdateListener(delegatingPositionsListener)
    }
    
    deinit {
        mapboxMap.setViewAnnotationPositionsUpdateListener(nil)
    }

    // MARK: - ViewAnnotationManagerInterface protocol functions

    public func addAnnotationView(withContent view: UIView, options: ViewAnnotationOptions) throws -> AnnotationView {
        guard options.geometry != nil else {
            throw ViewAnnotationManagerError.geometryFieldMissing
        }
        let annotatonView = AnnotationView(view: view, annotationManager: self)
        annotationViewsById[annotatonView.id] = annotatonView
        annotationIdByViews[annotatonView] = annotatonView.id
        containerView.addSubview(annotatonView)
        mapboxMap.addViewAnnotation(withId: annotatonView.id, options: options)
        return annotatonView
    }

    @discardableResult
    public func remove(_ annotatonView: AnnotationView) -> Bool {
        guard let id = annotationIdByViews[annotatonView], let annotatonView = annotationViewsById[id] else {
            return false
        }
        mapboxMap.removeViewAnnotation(withId: id)
        annotatonView.removeFromSuperview()
        annotationViewsById.removeValue(forKey: id)
        annotationIdByViews.removeValue(forKey: annotatonView)
        return true
    }

    @discardableResult
    public func update(_ annotatonView: AnnotationView, options: ViewAnnotationOptions) -> Bool {
        guard let id = annotationIdByViews[annotatonView] else {
            return false
        }
        mapboxMap.updateViewAnnotation(withId: id, options: options)
        return true
    }

    public func getViewAnnotation(byFeatureId identifier: String) -> AnnotationView? {
        guard let id = annotationViewsById.keys.first(where: { id in
            (try? mapboxMap.options(forViewAnnotationWithId: id).associatedFeatureId == identifier) ?? false
        }) else {
            // TODO: Error for not available annotation
            return nil
        }
        return annotationViewsById[id]
    }

    public func options(byAnnotationView view: AnnotationView) -> ViewAnnotationOptions? {
        guard let id = annotationIdByViews[view] else {
            // TODO: gracefully handle error
            return nil
        }
        return try? mapboxMap.options(forViewAnnotationWithId: id)
    }

    public func options(byFeatureId identifier: String) -> ViewAnnotationOptions? {
        return getViewAnnotation(byFeatureId: identifier).map({ view in options(byAnnotationView: view) }) ?? nil
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
            remove(annotationView)
        }
        if let wrappedView = annotationView.subviews.first, wrappedView.isHidden {
            // View is still considered for layout calculation, users should not modify the visibility of the wrapped view
            // TODO: Print warning
        }
    }

}

extension ViewAnnotationManager: DelegatingViewAnnotationPositionsListenerDelegate {

    public func onViewAnnotationPositionsUpdate(forPositions positions: [ViewAnnotationPositionDescriptor]) {
        placeAnnotations(positions: positions)
    }

}

public final class AnnotationView: SubviewInteractionOnlyView {

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
            let options = manager.options(byAnnotationView: self)
            let visible = !isHidden
            if visible != options?.visible {
                _ = manager.update(self, options: ViewAnnotationOptions(visible: visible))
            }
        }
    }
    private weak var annotationManager: ViewAnnotationManager?

    internal init(view: UIView, annotationManager: ViewAnnotationManager) {
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

}
