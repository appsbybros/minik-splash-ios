import Foundation

enum MinikExternalDestination: String, CaseIterable, Equatable, Identifiable, Sendable {
    case privacyPolicy
    case termsOfUse
    case support

    var id: String { rawValue }
}

struct MinikReleaseInformation: Equatable, Sendable {
    static let privacyPolicyURLInfoKey = "MinikPrivacyPolicyURL"
    static let termsOfUseURLInfoKey = "MinikTermsOfUseURL"
    static let supportURLInfoKey = "MinikSupportURL"
    static let legalNoticeInfoKey = "MinikLegalNotice"

    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?
    let legalNotice: String?
    let marketingVersion: String?
    let buildNumber: String?

    init(
        privacyPolicyURL: String?,
        termsOfUseURL: String?,
        supportURL: String?,
        legalNotice: String?,
        marketingVersion: String?,
        buildNumber: String?
    ) {
        self.privacyPolicyURL = Self.validatedWebURL(privacyPolicyURL)
        self.termsOfUseURL = Self.validatedWebURL(termsOfUseURL)
        self.supportURL = Self.validatedWebURL(supportURL)
        self.legalNotice = Self.normalized(legalNotice)
        self.marketingVersion = Self.normalized(marketingVersion)
        self.buildNumber = Self.normalized(buildNumber)
    }

    static func load(bundle: Bundle = .main) -> MinikReleaseInformation {
        MinikReleaseInformation(
            privacyPolicyURL: bundle.object(forInfoDictionaryKey: privacyPolicyURLInfoKey) as? String,
            termsOfUseURL: bundle.object(forInfoDictionaryKey: termsOfUseURLInfoKey) as? String,
            supportURL: bundle.object(forInfoDictionaryKey: supportURLInfoKey) as? String,
            legalNotice: bundle.object(forInfoDictionaryKey: legalNoticeInfoKey) as? String,
            marketingVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    func url(for destination: MinikExternalDestination) -> URL? {
        switch destination {
        case .privacyPolicy: return privacyPolicyURL
        case .termsOfUse: return termsOfUseURL
        case .support: return supportURL
        }
    }

    var hasExternalDestinations: Bool {
        MinikExternalDestination.allCases.contains { url(for: $0) != nil }
    }

    var versionDescription: String {
        switch (marketingVersion, buildNumber) {
        case (.some(let version), .some(let build)):
            return String(
                format: String(localized: "Version %@ (%@)"),
                version,
                build
            )
        case (.some(let version), .none):
            return String(format: String(localized: "Version %@"), version)
        case (.none, .some(let build)):
            return String(format: String(localized: "Build %@"), build)
        case (.none, .none):
            return String(localized: "Version unavailable")
        }
    }

    private static func validatedWebURL(_ value: String?) -> URL? {
        guard let normalized = normalized(value),
              let url = URL(string: normalized),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
