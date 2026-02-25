import Foundation

struct IPGeolocationService {
    private let url = URL(string: "https://ipinfo.io/json")!

    func fetch() async throws -> IPInfo {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(IPInfo.self, from: data)
    }
}
