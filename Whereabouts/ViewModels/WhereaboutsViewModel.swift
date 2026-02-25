import AppKit
import ServiceManagement

@MainActor
final class WhereaboutsViewModel: ObservableObject {
    @Published var ipInfo: IPInfo?
    @Published var isVPNActive = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var menuBarTitle: String = "Whereabouts"
    @Published var isLaunchAtLoginEnabled: Bool = false

    private let service = IPGeolocationService()
    private var networkMonitor: NetworkMonitor?
    private var refreshTimer: Timer?

    init() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        Task { await refresh() }
        startNetworkMonitor()
        startRefreshTimer()
    }

    // MARK: - Data

    var vpnProvider: String? {
        guard isVPNActive else { return nil }
        // Prefer the running-app name (e.g. "Mullvad VPN") over the exit-node ISP,
        // since hosting providers like Datacamp obscure the actual VPN brand.
        return VPNDetector.providerName() ?? ipInfo?.isp
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        isVPNActive = VPNDetector.isActive()

        do {
            let info = try await service.fetch()
            ipInfo = info
            error = nil
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
}
