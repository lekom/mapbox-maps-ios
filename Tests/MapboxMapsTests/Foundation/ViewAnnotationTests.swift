import XCTest
@testable import MapboxMaps

final class ViewAnnotationTests: XCTestCase {

    var container: SubviewInteractionOnlyView!
    var mockMapboxMap: MockMapboxMap!
    var manager: ViewAnnotationManager!

    override func setUp() {
        super.setUp()
        container = SubviewInteractionOnlyView()
        mockMapboxMap = MockMapboxMap()
        manager = ViewAnnotationManager(containerView: container, mapboxMap: mockMapboxMap)
    }
    
    override func tearDown() {
        container = nil
        mockMapboxMap = nil
        manager = nil
        super.tearDown()
    }
    
    func testAddAnnotationView() {
        let testView = UIView()
        let geometry = Geometry.point(Point(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        let annotationView = try? manager.addAnnotationView(withContent: testView, options: ViewAnnotationOptions(geometry: geometry))
        XCTAssertEqual(mockMapboxMap.addViewAnnotationStub.invocations.count, 1)
        XCTAssertEqual(annotationView?.superview, container)
        XCTAssertEqual(annotationView?.subviews.first, testView)
        XCTAssertEqual(container.subviews.count, 1)
    }
    
    func testAddAnnotationViewMissingGeometry() {
        XCTAssertThrowsError(try manager.addAnnotationView(withContent: UIView(), options: ViewAnnotationOptions()))
        XCTAssertEqual(mockMapboxMap.addViewAnnotationStub.invocations.count, 0)
        XCTAssertEqual(container.subviews.count, 0)
    }
    
    func testRemove() {
        let annotationView = addTestAnnotationView()
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 0)
        XCTAssertEqual(container.subviews.count, 1)
        XCTAssertNoThrow(try manager.remove(annotationView))
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 1)
        XCTAssertEqual(container.subviews.count, 0)
        
        // Trying to remove the same view the second time should throw
        XCTAssertThrowsError(try manager.remove(annotationView))
    }
    
    func testUpdate() {
        let annotationView = addTestAnnotationView()
        XCTAssertEqual(mockMapboxMap.updateViewAnnotationStub.invocations.count, 0)
        let options = ViewAnnotationOptions(width: 10.0, allowOverlap: false, anchor: .bottomRight)
        XCTAssertNoThrow(try manager.update(annotationView, options: options))
        XCTAssertEqual(mockMapboxMap.updateViewAnnotationStub.invocations.count, 1)
        XCTAssertEqual(mockMapboxMap.updateViewAnnotationStub.invocations.first?.parameters.options, options)
        
        // Trying to update the view after removal should throw
        XCTAssertNoThrow(try manager.remove(annotationView))
        XCTAssertThrowsError(try manager.update(annotationView, options: options))
    }
    
    func testViewAnnotationByFeatureId() {
        let testIdOne = "testIdOne"
        let testIdTwo = "testIdTwo"
        let geometry = Geometry.point(Point(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        let options = ViewAnnotationOptions(geometry: geometry, associatedFeatureId: testIdOne)
        let annotationView = try? manager.addAnnotationView(withContent: UIView(), options: options)
        mockMapboxMap.optionsForViewAnnotationWithIdStub.defaultReturnValue = options
        
        XCTAssertEqual(annotationView, manager.viewAnnotation(byFeatureId: testIdOne))
        XCTAssertNil(manager.viewAnnotation(byFeatureId: testIdTwo))
        XCTAssertNil(manager.viewAnnotation(byFeatureId: ""))
    }
    
    func testOptionsByFeatureId() {
        // TODO: implement test case
    }
    
    func testOptionsByAnnotationView() {
        // TODO: implement test case
    }
    
    func testPlaceAnnotations() {
        // TODO: implement test case
    }
    
    func testValidateAnnotation() {
        let annotationView = addTestAnnotationView()

        // First check: annotation is valid, leave it in place
        manager.validateAnnotation(byAnnotationId: annotationView.id)
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 0)
        
        // Second check: annotation is manually removed from superview, remove is called
        annotationView.removeFromSuperview()
        manager.validateAnnotation(byAnnotationId: annotationView.id)
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 1)
    }
    
    func testAnnotationViewVisibilityUpdate() {
        let annotationView = addTestAnnotationView()
        
        let stub = mockMapboxMap.updateViewAnnotationStub
        XCTAssertEqual(stub.invocations.count, 0)
        annotationView.isHidden = true
        XCTAssertEqual(stub.invocations.count, 1)
        XCTAssertFalse(stub.invocations.last!.parameters.options.visible!)
        annotationView.isHidden = false
        XCTAssertEqual(stub.invocations.count, 2)
        XCTAssertTrue(stub.invocations.last!.parameters.options.visible!)
    }
    
    func addTestAnnotationView() -> AnnotationView {
        let geometry = Geometry.point(Point(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        let annotationView = try! manager.addAnnotationView(withContent: UIView(), options: ViewAnnotationOptions(geometry: geometry))
        return annotationView
    }
    
}
