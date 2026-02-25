import Foundation
import CoreLocation

struct IPInfo: Codable {
    let ip: String
    let city: String?
    let region: String?
    let country: String?   // 2-letter code, e.g. "US"
    let loc: String?       // "lat,lon", e.g. "37.3861,-122.0839"
    let org: String?       // "AS15169 Google LLC"
    let timezone: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let loc else { return nil }
        let parts = loc.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// ISP name with the leading AS number stripped.
    var isp: String? {
        guard let org else { return nil }
        return org.replacingOccurrences(of: #"^AS\d+\s+"#, with: "", options: .regularExpression)
    }

    /// Full country name resolved via system locale.
    var countryName: String? {
        guard let country else { return nil }
        return Locale.current.localizedString(forRegionCode: country) ?? country
    }
}
