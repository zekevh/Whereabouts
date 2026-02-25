import SwiftUI
import MapKit
import CoreLocation

struct MapView: NSViewRepresentable {
    let currentCoordinate: CLLocationCoordinate2D?
    let realCoordinate: CLLocationCoordinate2D?   // non-nil only when VPN is active
    let isVPN: Bool

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isZoomEnabled    = false
        map.isScrollEnabled  = false
        map.isRotateEnabled  = false
        map.isPitchEnabled   = false
        map.showsCompass     = false
        map.showsScale       = false
        map.showsZoomControls = false
        map.mapType = .standard
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        // Defer mutations to the next run loop turn so they don't run during
        // a SwiftUI layout pass — avoids the reentrant-layout warning and the
        // zero-size CAMetalLayer draw before the view has a frame.
        DispatchQueue.main.async {
            map.removeAnnotations(map.annotations)
            map.removeOverlays(map.overlays)

            guard let current = self.currentCoordinate else {
                let world = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    span: MKCoordinateSpan(latitudeDelta: 160, longitudeDelta: 360)
                )
                map.setRegion(world, animated: false)
                return
            }

            if self.isVPN, let real = self.realCoordinate {
                var coords = [real, current]
                let arc = MKGeodesicPolyline(coordinates: &coords, count: 2)
                map.addOverlay(arc)

                let realPin = self.makePin(coordinate: real, title: "real")
                let exitPin = self.makePin(coordinate: current, title: "exit")
                map.addAnnotations([realPin, exitPin])
                map.showAnnotations([realPin, exitPin], animated: false)
            } else {
                let pin = self.makePin(coordinate: current, title: "current")
                map.addAnnotation(pin)
                let region = MKCoordinateRegion(
                    center: current,
                    latitudinalMeters: 60_000,
                    longitudinalMeters: 60_000
                )
                map.setRegion(region, animated: false)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: -

    private func makePin(coordinate: CLLocationCoordinate2D, title: String) -> MKPointAnnotation {
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = title
        return pin
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: polyline)
            r.strokeColor = .systemBlue
            r.lineWidth   = 2
            r.lineDashPattern = [6, 4]
            return r
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "wa-pin"
            let view = (map.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation     = annotation
            view.canShowCallout = false

            switch annotation.title {
            case "exit":
                view.markerTintColor = .systemOrange
                view.glyphImage = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: nil)
            case "real":
                view.markerTintColor = .systemBlue
                view.glyphImage = NSImage(systemSymbolName: "person.fill", accessibilityDescription: nil)
            default:
                view.markerTintColor = .systemBlue
                view.glyphImage = nil
            }
            return view
        }
    }
}
