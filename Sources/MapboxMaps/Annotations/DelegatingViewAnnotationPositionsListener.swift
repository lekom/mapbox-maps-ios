import MapboxCoreMaps
@_implementationOnly import MapboxCoreMaps_Private

internal protocol DelegatingViewAnnotationPositionsListenerDelegate: AnyObject {
    func onViewAnnotationPositionsUpdate(forPositions positions: [ViewAnnotationPositionDescriptor])
}

internal final class DelegatingViewAnnotationPositionsListener: ViewAnnotationPositionsListener {
    internal weak var delegate: DelegatingViewAnnotationPositionsListenerDelegate?
    
    internal func onViewAnnotationPositionsUpdate(forPositions positions: [ViewAnnotationPositionDescriptor]) {
        delegate?.onViewAnnotationPositionsUpdate(forPositions: positions)
    }
}
