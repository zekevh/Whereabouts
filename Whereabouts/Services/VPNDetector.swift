import SystemConfiguration
import Darwin    // socket, connect, getsockname, getifaddrs
import AppKit    // NSWorkspace.runningApplications

enum VPNDetector {
    /// Returns true when a VPN tunnel is actively routing traffic.
    ///
    /// Strategy: open a UDP socket and "connect" it to a well-known external
    /// address (8.8.8.8:53). No packets are sent — this is purely a kernel
    /// routing table query. `getsockname` then reveals which local address the
    /// kernel would assign, which tells us which interface carries the default
    /// route. If that interface is a tunnel (utun, ppp, ipsec) a VPN is active.
    ///
    /// Why this beats the alternatives:
    /// - SCDynamicStore PrimaryInterface is NOT updated by Network Extension
    ///   VPNs (Mullvad, WireGuard app, etc.) — misses modern VPN apps.
    /// - Counting utun interfaces via getifaddrs is unreliable — Mullvad and
    ///   iCloud Private Relay both create utun entries when idle (false positives).
    /// - The routing-socket approach always reflects the real default route,
    ///   regardless of whether the VPN uses kernel routing or Network Extension.
    static func isActive() -> Bool {
        guard let iface = defaultRouteInterface() else { return false }
        return iface.hasPrefix("utun")  ||
               iface.hasPrefix("ppp")   ||
               iface.hasPrefix("ipsec")
    }

    /// Returns the human-readable VPN provider name.
    /// Tries: running VPN app name → SCDynamicStore service name.
    static func providerName() -> String? {
        runningVPNAppName() ?? vpnServiceNameFromDynamicStore()
    }

    // MARK: - Routing-socket default-route detection

    private static func defaultRouteInterface() -> String? {
        // UDP connect to 8.8.8.8 — no packets sent, just a routing table lookup.
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var dst = sockaddr_in()
        dst.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        dst.sin_family = sa_family_t(AF_INET)
        dst.sin_port   = UInt16(53).bigEndian
        dst.sin_addr.s_addr = inet_addr("8.8.8.8")

        let connected = withUnsafePointer(to: dst) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return nil }

        // Ask the kernel which local address it assigned.
        var local = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(sock, $0, &len)
            }
        }
        guard named == 0 else { return nil }

        // Map that local address back to an interface name.
        var ifap: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifap) == 0, let head = ifap else { return nil }
        defer { freeifaddrs(head) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = head
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }
            guard let addrPtr = ifa.pointee.ifa_addr,
                  addrPtr.pointee.sa_family == sa_family_t(AF_INET),
                  let namePtr = ifa.pointee.ifa_name
            else { continue }

            let ifAddr = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                $0.pointee.sin_addr.s_addr
            }
            if ifAddr == local.sin_addr.s_addr {
                return String(cString: namePtr)
            }
        }
        return nil
    }

    // MARK: - Provider name — running VPN app

    private static func runningVPNAppName() -> String? {
        let known: [String: String] = [
            "net.mullvad.vpn":                    "Mullvad VPN",
            "com.mullvad.vpn":                    "Mullvad VPN",
            "com.nordvpn.macos":                  "NordVPN",
            "com.nordvpn.macos.NordVPN":          "NordVPN",
            "com.expressvpn.ExpressVPN":          "ExpressVPN",
            "ch.protonvpn.mac":                   "ProtonVPN",
            "ch.protonvpn.macos.ProtonVPN":       "ProtonVPN",
            "com.wireguard.macos":                "WireGuard",
            "io.tailscale.ipn.macos":             "Tailscale",
            "com.cloudflare.1dot1dot1dot1.macos": "Cloudflare WARP",
            "com.privateinternetaccess.vpn":      "PIA VPN",
            "com.privateinternetaccess.macos":    "PIA VPN",
            "com.surfshark.vpnclient.mac":        "Surfshark VPN",
            "com.ipvanish.IPVanish-VPN":          "IPVanish",
        ]
        for app in NSWorkspace.shared.runningApplications {
            if let bid = app.bundleIdentifier, let name = known[bid] {
                return name
            }
        }
        return nil
    }

    // MARK: - Provider name — SCDynamicStore service name (traditional VPNs)

    private static func vpnServiceNameFromDynamicStore() -> String? {
        guard
            let store     = SCDynamicStoreCreate(nil, "io.zvh.whereabouts" as CFString, nil, nil),
            let ipv4      = SCDynamicStoreCopyValue(
                                store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
            let serviceID = ipv4["PrimaryService"] as? String
        else { return nil }

        let key = "Setup:/Network/Service/\(serviceID)" as CFString
        guard let svc  = SCDynamicStoreCopyValue(store, key) as? [String: Any],
              let name = svc["UserDefinedName"] as? String
        else { return nil }

        return name
    }
}
