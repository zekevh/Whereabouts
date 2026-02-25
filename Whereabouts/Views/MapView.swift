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
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        guard let current = currentCoordinate else {
            // No data yet — show a world overview.
            let world = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 160, longitudeDelta: 360)
            )
            map.setRegion(world, animated: false)
            return
        }

        if isVPN, let real = realCoordinate {
            // Draw a geodesic arc from the real location to the VPN exit node.
            var coords = [real, current]
            let arc = MKGeodesicPolyline(coordinates: &coords, count: 2)
            map.addOverlay(arc)

            let realPin = makePin(coordinate: real, title: "real")
            let exitPin = makePin(coordinate: current, title: "exit")
            map.addAnnotations([realPin, exitPin])
            map.showAnnotations([realPin, exitPin], animated: false)
        } else {
            // Simple pin at current location.
            let pin = makePin(coordinate: current, title: "current")
            map.addAnnotation(pin)
            let region = MKCoordinateRegion(
                center: current,
                latitudinalMeters: 60_000,
                longitudinalMeters: 60_000
            )
            map.setRegion(region, animated: false)
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
