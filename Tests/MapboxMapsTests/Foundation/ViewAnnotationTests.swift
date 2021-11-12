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
        let testView = UIView()
        do {
            _ = try manager.addAnnotationView(withContent: testView, options: ViewAnnotationOptions())
        } catch ViewAnnotationManagerError.insertionFailure(reason: let reason) {
            XCTAssertFalse(reason.isEmpty)
        } catch {
            XCTFail()
        }
        XCTAssertEqual(mockMapboxMap.addViewAnnotationStub.invocations.count, 0)
        XCTAssertEqual(container.subviews.count, 0)
    }
    
    func testRemove() {
        
    }
    
    func testUpdate() {
        
    }
    
    func testViewAnnotationByFeatureId() {
        
    }
    
    func testOptionsByFeatureId() {
        
    }
    
    func testOptionsByAnnotationView() {
        
    }
    
    func testPlaceAnnotations() {
        
    }
    
    func testValidateAnnotation() {
        let testView = UIView()
        let geometry = Geometry.point(Point(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        guard let annotationView = try? manager.addAnnotationView(withContent: testView, options: ViewAnnotationOptions(geometry: geometry)) else {
            XCTFail()
            return
        }

        // First check: annotation is valid, leave it in place
        manager.validateAnnotation(byAnnotationId: annotationView.id)
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 0)
        
        // Second check: annotation is manually removed from superview, remove is called
        annotationView.removeFromSuperview()
        manager.validateAnnotation(byAnnotationId: annotationView.id)
        XCTAssertEqual(mockMapboxMap.removeViewAnnotationStub.invocations.count, 1)
    }
    
    func testAnnotationViewVisibilityUpdate() {
        let testView = UIView()
        let geometry = Geometry.point(Point(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        guard let annotationView = try? manager.addAnnotationView(withContent: testView, options: ViewAnnotationOptions(geometry: geometry)) else {
            XCTFail()
            return
        }
        
        let stub = mockMapboxMap.updateViewAnnotationStub
        XCTAssertEqual(stub.invocations.count, 0)
        annotationView.isHidden = true
        XCTAssertEqual(stub.invocations.count, 1)
        XCTAssertFalse(stub.invocations.last!.parameters.options.visible!)
        annotationView.isHidden = false
        XCTAssertEqual(stub.invocations.count, 2)
        XCTAssertTrue(stub.invocations.last!.parameters.options.visible!)
    }
    
}
