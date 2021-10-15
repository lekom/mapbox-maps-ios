import UIKit
import MapboxMaps

/**
 NOTE: This view controller should be used as a scratchpad
 while you develop new features. Changes to this file
 should not be committed.
 */

final class DebugViewController: UIViewController {

    var mapView: MapView!
    var tapNumber = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        let cameraOptions = CameraOptions(center: CLLocationCoordinate2D(latitude: 40.7135, longitude: -74.0066),
                                          zoom: 15.5,
                                          bearing: -17.6,
                                          pitch: 45)
        let options = MapInitOptions(cameraOptions: cameraOptions)
        mapView = MapView(frame: view.bounds, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(getBounds))
        mapView.addGestureRecognizer(tapGesture)
    }

    @objc func getBounds() {
        tapNumber += 1
        let bounds = mapView.mapboxMap.cameraBounds
        print("bounds \(tapNumber) - \(bounds)")
        let cameraState = mapView.mapboxMap.cameraState
        let options = CameraOptions(cameraState: cameraState)
        let boundsForOptions = mapView.mapboxMap.coordinateBounds(for: options)
        print("bounds for options \(tapNumber) - \(boundsForOptions)")

        let boundsForRect = mapView.mapboxMap.coordinateBounds(for: mapView.bounds)
        print("bounds for rect \(tapNumber) - \(boundsForRect)")
        var rectFeature = featureForBounds(boundsForRect)
        rectFeature.identifier = .string("rect")
        rectFeature.properties = JSONObject(dictionaryLiteral: ("id", .string("rect")))

        var optionsFeature = featureForBounds(boundsForOptions)
        optionsFeature.identifier = .string("options")
        optionsFeature.properties = JSONObject(dictionaryLiteral: ("id", .string("options")))

        var source = GeoJSONSource()
        source.data = .featureCollection(FeatureCollection(features: [optionsFeature, rectFeature]))


        var layer = LineLayer(id
                                : "line-layer-\(tapNumber)")
        layer.source = "line-source-\(tapNumber)"
        layer.lineWidth = .constant(10)
        layer.lineColor = .expression(
            Exp(.match) {
                Exp(.get) { "id" }
                "rect"
                UIColor.purple
                "options"
                UIColor.red
                UIColor.green
            }
        )

        try! mapView.mapboxMap.style.addSource(source, id: "line-source-\(tapNumber)")
        try! mapView.mapboxMap.style.addLayer(layer)

    }

    func featureForBounds(_ bounds: CoordinateBounds) -> Feature {
        let coordinates = [bounds.northeast, bounds.southeast, bounds.southwest, bounds.northwest, bounds.northeast]
        let locationCoordinates = coordinates.map { LocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)}

        let geometry = Polygon([locationCoordinates])
        return Feature(geometry: geometry)
    }
}
