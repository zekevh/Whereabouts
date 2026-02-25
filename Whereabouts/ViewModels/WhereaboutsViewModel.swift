import AppKit
import CoreLocation
import ServiceManagement

@MainActor
final class WhereaboutsViewModel: ObservableObject {
    @Published var ipInfo: IPInfo?
    @Published var isVPNActive = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var menuBarTitle: String = "Whereabouts"
    @Published var isLaunchAtLoginEnabled: Bool = false

    /// Last known real (non-VPN) coordinate, persisted across launches.
    private(set) var realCoordinate: CLLocationCoordinate2D?

    private let service = IPGeolocationService()
    private var networkMonitor: NetworkMonitor?
    private var refreshTimer: Timer?

    init() {
        loadCachedRealLocation()
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        Task { await refresh() }
        startNetworkMonitor()
        startRefreshTimer()
    }

    // MARK: - Data

    var vpnProvider: String? {
        isVPNActive ? ipInfo?.isp : nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        isVPNActive = VPNDetector.isActive()

        do {
            let info = try await service.fetch()
            ipInfo = info
            error = nil

            if !isVPNActive, let coord = info.coordinate {
                UserDefaults.standard.set(coord.latitude,  forKey: "realLat")
                UserDefaults.standard.set(coord.longitude, forKey: "realLon")
                realCoordinate = coord
            } else if realCoordinate == nil {
                loadCachedRealLocation()
            }

            menuBarTitle = "\(info.city ?? "Unknown"), \(info.country ?? "??")"

        } catch {
            self.error = error.localizedDescription
            if ipInfo == nil { menuBarTitle = "Whereabouts" }
        }
    }

    // MARK: - Actions

    func openInMaps() {
        guard let info = ipInfo, let coord = info.coordinate else { return }
        let q = (info.city ?? "Location")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Location"
        if let url = URL(string: "maps://?ll=\(coord.latitude),\(coord.longitude)&q=\(q)") {
            NSWorkspace.shared.open(url)
        }
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Private

    private func startNetworkMonitor() {
        let monitor = NetworkMonitor()
        monitor.onNetworkChange = { [weak self] in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        monitor.start()
        networkMonitor = monitor
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    private func loadCachedRealLocation() {
        let lat = UserDefaults.standard.double(forKey: "realLat")
        let lon = UserDefaults.standard.double(forKey: "realLon")
        guard lat != 0 || lon != 0 else { return }
        realCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
