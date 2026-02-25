import SystemConfiguration

enum VPNDetector {
    /// Returns true when a traditional VPN tunnel is routing the primary traffic.
    ///
    /// Strategy: ask SCDynamicStore which interface carries the default IPv4 route.
    /// If that interface is a tunnel (utun*, ppp*, ipsec*) a VPN is active.
    ///
    /// Why not getifaddrs?  Counting utun* interfaces is unreliable — iCloud Private
    /// Relay, Bonjour, and other Apple services create utun entries without changing
    /// the primary route, causing false positives.  The SCDynamicStore approach only
    /// fires when the OS has promoted a tunnel to be the primary network path.
    static func isActive() -> Bool {
        guard
            let store = SCDynamicStoreCreate(nil, "com.zvh.whereabouts" as CFString, nil, nil),
            let ipv4  = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
            let iface = ipv4["PrimaryInterface"] as? String
        else { return false }

        return iface.hasPrefix("utun")  ||
               iface.hasPrefix("ppp")   ||
               iface.hasPrefix("ipsec")
    }
}
