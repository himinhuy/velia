import Foundation

/// Legal links required on the subscription paywall (App Store Guideline 3.1.2).
/// Replace `privacyURL`/`termsURL` with your hosted pages before submission. The default Terms
/// points at Apple's standard EULA (acceptable if you don't ship a custom one).
enum Legal {
    static let privacyURL = URL(string: "https://velia.app/privacy")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportURL = URL(string: "https://velia.app/support")!
}
