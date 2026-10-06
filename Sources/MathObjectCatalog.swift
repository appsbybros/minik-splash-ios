import Foundation

enum MathObjectCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case animals
    case everyday
    case food
    case fruits
    case nature
    case school
    case scienceSpace = "science-space"
    case toys
    case treasures
    case treats
}

struct MathObjectManifestRecord: Codable, Hashable, Sendable {
    let id: String
    let assetName: String
    let category: String
    let accessibilityLabel: String
}

private struct MathObjectManifestFile: Codable {
    let version: Int
    let objects: [MathObjectManifestRecord]
    let zeroStates: [MathObjectManifestRecord]
    let groupingSupport: [MathObjectManifestRecord]
}

enum MathObjectCatalogError: Error, Equatable {
    case unsupportedVersion(Int)
    case duplicateID(String)
    case emptyObjects
    case emptyZeroStates
    case emptyGroupingSupport
    case unknownObjectCategory(String)
}

struct MathObjectCatalog: Sendable {
    let objects: [MathObjectManifestRecord]
    let zeroStates: [MathObjectManifestRecord]
    let groupingSupport: [MathObjectManifestRecord]

    static let production: MathObjectCatalog? = {
        guard let url = Bundle.main.url(forResource: "MathObjectManifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }()

    static func decode(_ data: Data) throws -> MathObjectCatalog {
        let manifest = try JSONDecoder().decode(MathObjectManifestFile.self, from: data)
        guard manifest.version == 1 else {
            throw MathObjectCatalogError.unsupportedVersion(manifest.version)
        }
        guard !manifest.objects.isEmpty else { throw MathObjectCatalogError.emptyObjects }
        guard !manifest.zeroStates.isEmpty else { throw MathObjectCatalogError.emptyZeroStates }
        guard !manifest.groupingSupport.isEmpty else { throw MathObjectCatalogError.emptyGroupingSupport }
        for record in manifest.objects where MathObjectCategory(rawValue: record.category) == nil {
            throw MathObjectCatalogError.unknownObjectCategory(record.category)
        }
        var ids = Set<String>()
        for record in manifest.objects + manifest.zeroStates + manifest.groupingSupport {
            guard ids.insert(record.id).inserted else {
                throw MathObjectCatalogError.duplicateID(record.id)
            }
        }
        return MathObjectCatalog(
            objects: manifest.objects,
            zeroStates: manifest.zeroStates,
            groupingSupport: manifest.groupingSupport
        )
    }

    var objectCategories: Set<MathObjectCategory> {
        Set(objects.compactMap { MathObjectCategory(rawValue: $0.category) })
    }

    var themes: [MathObjectTheme] {
        objects.enumerated().compactMap { index, record in
            let empty = zeroStates[index % zeroStates.count]
            return MathObjectTheme(
                id: MathObjectThemeID(rawValue: record.id),
                objects: [asset(for: record)],
                emptyStateAsset: asset(for: empty)
            )
        }
    }

    func theme(forStableKey key: String) -> MathObjectTheme? {
        let availableThemes = themes
        guard !availableThemes.isEmpty else { return nil }
        return availableThemes[Int(stableHash(key) % UInt64(availableThemes.count))]
    }

    func groupingAsset(forGroupCount groupCount: Int) -> MathObjectAsset? {
        let preferredID = groupCount == 2 ? "math_two_compartment_tray" : "math_grouping_tray"
        guard let record = groupingSupport.first(where: { $0.id == preferredID })
                ?? groupingSupport.first else { return nil }
        return asset(for: record)
    }

    func groupingAsset(named id: String) -> MathObjectAsset? {
        groupingSupport.first(where: { $0.id == id }).map { asset(for: $0) }
    }

    private func asset(for record: MathObjectManifestRecord) -> MathObjectAsset {
        MathObjectAsset(
            assetName: record.assetName,
            accessibilityLabel: record.accessibilityLabel
        )
    }

    private func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

struct MathObjectThemeSelector: Sendable {
    let themes: [MathObjectTheme]
    private(set) var previousThemeID: MathObjectThemeID?

    init(themes: [MathObjectTheme], previousThemeID: MathObjectThemeID? = nil) {
        self.themes = themes
        self.previousThemeID = previousThemeID
    }

    mutating func next<Generator: RandomNumberGenerator>(
        using generator: inout Generator
    ) -> MathObjectTheme? {
        let candidates = themes.count > 1
            ? themes.filter { $0.id != previousThemeID }
            : themes
        guard !candidates.isEmpty else { return nil }
        let selected = candidates[Int.random(in: candidates.indices, using: &generator)]
        previousThemeID = selected.id
        return selected
    }
}
