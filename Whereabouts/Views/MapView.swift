import SwiftUI
import MapKit
import CoreLocation

struct MapView: NSViewRepresentable {
    let coordinate: CLLocationCoordinate2D?
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
        DispatchQueue.main.async {
            map.removeAnnotations(map.annotations)
            map.removeOverlays(map.overlays)

            guard let coord = self.coordinate else {
                let world = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    span: MKCoordinateSpan(latitudeDelta: 160, longitudeDelta: 360)
                )
                map.setRegion(world, animated: false)
                return
            }

            let pin = self.makePin(coordinate: coord)
            map.addAnnotation(pin)
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 60_000,
                longitudinalMeters: 60_000
            )
            map.setRegion(region, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makePin(coordinate: CLLocationCoordinate2D) -> MKPointAnnotation {
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = isVPN ? "exit" : "current"
        return pin
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "wa-pin"
            let view = (map.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation     = annotation
            view.canShowCallout = false

            if annotation.title == "exit" {
                view.markerTintColor = .systemOrange
                view.glyphImage = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: nil)
            } else {
                view.markerTintColor = .systemBlue
                view.glyphImage = nil
            }
            return view
        }
    }
}
