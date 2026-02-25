import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var vm: WhereaboutsViewModel

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            // No Divider here — the map's natural edge separates it from the data.
            infoSection
            Divider()
            bottomBar
        }
        .frame(width: 320)
        // Keyboard shortcuts active while the panel is open.
        .background(shortcutButtons)
    }

    // MARK: - Map

    private var mapSection: some View {
        MapView(
            currentCoordinate: vm.ipInfo?.coordinate,
            realCoordinate: vm.isVPNActive ? vm.realCoordinate : nil,
            isVPN: vm.isVPNActive
        )
        .frame(height: 160)
    }

    // MARK: - Info

    private var infoSection: some View {
        Group {
            if vm.isLoading && vm.ipInfo == nil {
                loadingView
            } else if let error = vm.error, vm.ipInfo == nil {
                errorView(error)
            } else {
                dataRows
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var dataRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ip = vm.ipInfo?.ip {
                InfoRow(label: "IP", value: ip, monospaced: true)
            }
            let city    = vm.ipInfo?.city        ?? "—"
            let country = vm.ipInfo?.countryName ?? vm.ipInfo?.country ?? "—"
            InfoRow(label: "Location", value: "\(city), \(country)")
            if let isp = vm.ipInfo?.isp {
                InfoRow(label: "ISP", value: isp)
            }
            if let provider = vm.vpnProvider {
                InfoRow(label: "VPN", value: provider, accent: true)
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.75)
            Text("Fetching location…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.refresh() } }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button(action: vm.openInMaps) {
                Label("Open in Maps", systemImage: "map").font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.ipInfo?.coordinate == nil)

            Spacer()

            Toggle(isOn: Binding(
                get: { vm.isLaunchAtLoginEnabled },
                set: { _ in vm.toggleLaunchAtLogin() }
            )) {
                Text("Launch at login").font(.callout)
            }
            .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Keyboard shortcuts
    //
    // Hidden zero-size buttons register keyboard shortcuts for the panel window
    // even though they are invisible in the layout.

    private var shortcutButtons: some View {
        ZStack {
            Button("Quit")    { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .hidden()
            Button("Refresh") { Task { await vm.refresh() } }
                .keyboardShortcut("r")
                .hidden()
        }
    }
}

// MARK: - InfoRow

private struct InfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    var accent: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(accent ? Color.orange : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }
}
