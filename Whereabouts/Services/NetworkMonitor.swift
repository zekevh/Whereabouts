import Network

final class NetworkMonitor {
    var onNetworkChange: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.zvh.whereabouts.network", qos: .background)
    private var debounceTask: Task<Void, Never>?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            self?.debounceTask?.cancel()
            self?.debounceTask = Task { [weak self] in
                do {
                    // Wait for the network to stabilize before triggering a refresh.
                    try await Task.sleep(for: .seconds(1))
                    self?.onNetworkChange?()
                } catch {
                    // Task was cancelled (another path update arrived); do nothing.
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        debounceTask?.cancel()
    }
}
