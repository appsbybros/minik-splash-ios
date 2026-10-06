import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
#if canImport(UIKit)
import UIKit
#endif

enum LanguageVocabularyLoadError: Error, Equatable, Sendable {
    case missingRuntimeResource(name: String, fileExtension: String)
    case malformedArrayName(String)
    case missingXMLKey(arrayName: String)
    case blankXMLKey(arrayName: String)
    case duplicateXMLKey(String)
    case invalidXMLKey(String)
    case invalidCategoryIdentifier(String)
    case missingXMLEnglish(key: String)
    case missingXMLHebrew(key: String)
    case missingManifestStableKeyColumn
    case invalidManifestHeader
    case invalidManifestRow(String)
    case blankManifestStableKey(String)
    case invalidManifestStableKey(String)
    case duplicateManifestStableKey(String)
    case unknownManifestStableKey(String)
    case blankManifestAssetKey(String)
    case invalidManifestAssetKey(String)
    case duplicateManifestAssetKey(String)
    case invalidManifestLevel(String)
    case invalidManifestCategory(String)
    case invalidManifestAssetStatus(String)
    case invalidManifestImageAction(String)
    case manifestEnglishMismatch(String)
    case manifestHebrewMismatch(String)
    case manifestLevelMismatch(String)
    case manifestCategoryMismatch(String)
    case invalidManifestActionStatusCombination(String)
    case xmlParseFailure(String)
}

enum LanguageVocabularyContentKind: String, Hashable, Sendable {
    case word
    case phrase
    case sentence
}

enum LanguageVocabularyImageAssetStatus: String, Hashable, Sendable {
    case existingIOS = "existing_ios"
    case missingIOS = "missing_ios"
    case existingAndroid = "existing_android"
    case missingAndroid = "missing_android"
    case trustedExternal = "trusted_external"
}

enum LanguageVocabularyImageAction: String, Hashable, Sendable {
    case reuseIOS = "reuse_ios"
    case migrateAndroid = "migrate_android"
    case trustedAcquire = "trusted_acquire"
    case createNew = "create_new"
}

enum LanguageVocabularyLevel: String, CaseIterable, Hashable, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"

    var curriculumStageID: CurriculumStageID {
        switch self {
        case .a:
            return LanguageCurriculumStageIDs.wordsLevelA
        case .b:
            return LanguageCurriculumStageIDs.wordsLevelB
        case .c:
            return LanguageCurriculumStageIDs.wordsLevelC
        case .d:
            return LanguageCurriculumStageIDs.wordsLevelD
        case .e:
            return LanguageCurriculumStageIDs.wordsLevelE
        }
    }

    init?(curriculumStageID: CurriculumStageID) {
        switch curriculumStageID {
        case LanguageCurriculumStageIDs.wordsLevelA:
            self = .a
        case LanguageCurriculumStageIDs.wordsLevelB:
            self = .b
        case LanguageCurriculumStageIDs.wordsLevelC:
            self = .c
        case LanguageCurriculumStageIDs.wordsLevelD:
            self = .d
        case LanguageCurriculumStageIDs.wordsLevelE:
            self = .e
        default:
            return nil
        }
    }

    var previous: LanguageVocabularyLevel? {
        switch self {
        case .a: return nil
        case .b: return .a
        case .c: return .b
        case .d: return .c
        case .e: return .d
        }
    }

    var next: LanguageVocabularyLevel? {
        switch self {
        case .a: return .b
        case .b: return .c
        case .c: return .d
        case .d: return .e
        case .e: return nil
        }
    }
}

struct LanguageVocabularyImageManifestEntry: Hashable, Sendable {
    let stableKey: String
    let assetReference: AssetReference
    let source: String
    let englishText: String
    let hebrewText: String
    let level: LanguageVocabularyLevel
    let categoryID: LanguageWordCategoryID
    let iosAssetStatus: LanguageVocabularyImageAssetStatus
    let androidAssetStatus: LanguageVocabularyImageAssetStatus
    let imageAction: LanguageVocabularyImageAction
    let isReadyInCurrentIOS: Bool
}

struct LanguageVocabularyCatalogData: Sendable {
    let categoriesByLevel: [LanguageVocabularyLevel: [LanguageWordCategory]]
    let itemsByStableKey: [String: LanguageWordCatalogItem]
    let imageManifestEntries: [LanguageVocabularyImageManifestEntry]
    let availableImageAssetReferences: Set<AssetReference>

    func categories(for level: LanguageVocabularyLevel) -> [LanguageWordCategory] {
        categoriesByLevel[level] ?? []
    }

    func items(for level: LanguageVocabularyLevel) -> [LanguageWordCatalogItem] {
        categories(for: level).flatMap(\.items)
    }

    func item(stableKey: String) -> LanguageWordCatalogItem? {
        itemsByStableKey[stableKey]
    }

    var allItems: [LanguageWordCatalogItem] {
        LanguageVocabularyLevel.allCases.flatMap { items(for: $0) }
    }
}

enum LanguageVocabularyCatalogLoader {
    static func loadApprovedCatalog() throws -> LanguageVocabularyCatalogData {
        let xmlData = try resourceData(
            named: "words-normalized",
            fileExtension: "xml"
        )
        let manifestData = try resourceData(
            named: "vocabulary-image-manifest",
            fileExtension: "tsv"
        )
        return try load(
            xmlData: xmlData,
            manifestData: manifestData,
            availableAssetReferences: nil
        )
    }

    static func load(
        xmlData: Data,
        manifestData: Data,
        availableAssetReferences: Set<AssetReference>? = nil
    ) throws -> LanguageVocabularyCatalogData {
        let xmlEntries = try parseNormalizedXML(xmlData)
        let xmlEntriesByKey = try xmlEntriesByKey(xmlEntries)
        let parsedManifestEntries = try parseImageManifest(
            manifestData,
            validStableKeys: Set(xmlEntriesByKey.keys)
        )
        try validateManifestMetadata(
            parsedManifestEntries,
            against: xmlEntriesByKey
        )
        let resolvedAvailableAssets = availableAssetReferences
            ?? Self.availableAssetReferences(from: parsedManifestEntries)
        let manifestEntries = finalizeManifestEntries(
            parsedManifestEntries,
            availableAssetReferences: resolvedAvailableAssets
        )
        let manifestByStableKey = try manifestEntriesByStableKey(manifestEntries)
        let categoriesByLevel = buildCategories(
            from: xmlEntries,
            manifestByStableKey: manifestByStableKey
        )
        let itemsByStableKey = Dictionary(
            uniqueKeysWithValues: categoriesByLevel.values
                .flatMap { $0 }
                .flatMap(\.items)
                .map { ($0.stableKey, $0) }
        )

        return LanguageVocabularyCatalogData(
            categoriesByLevel: categoriesByLevel,
            itemsByStableKey: itemsByStableKey,
            imageManifestEntries: manifestEntries,
            availableImageAssetReferences: Set(
                manifestEntries
                    .filter(\.isReadyInCurrentIOS)
                    .map(\.assetReference)
            )
        )
    }

    static func parseArrayName(
        _ name: String
    ) throws -> (categoryID: LanguageWordCategoryID, level: LanguageVocabularyLevel) {
        guard let separatorIndex = name.lastIndex(of: "_"),
              separatorIndex != name.startIndex,
              separatorIndex < name.index(before: name.endIndex) else {
            throw LanguageVocabularyLoadError.malformedArrayName(name)
        }

        let category = String(name[..<separatorIndex])
        let levelSuffix = String(name[name.index(after: separatorIndex)...]).uppercased()
        guard !category.isEmpty,
              let level = LanguageVocabularyLevel(rawValue: levelSuffix) else {
            throw LanguageVocabularyLoadError.malformedArrayName(name)
        }
        guard isValidIdentifier(category) else {
            throw LanguageVocabularyLoadError.invalidCategoryIdentifier(category)
        }

        return (LanguageWordCategoryID(rawValue: category), level)
    }

    private static func resourceData(
        named name: String,
        fileExtension: String
    ) throws -> Data {
        guard let url = resourceURL(named: name, fileExtension: fileExtension) else {
            throw LanguageVocabularyLoadError.missingRuntimeResource(
                name: name,
                fileExtension: fileExtension
            )
        }
        return try Data(contentsOf: url)
    }

    private static func resourceURL(
        named name: String,
        fileExtension: String
    ) -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let directURL = bundle.url(forResource: name, withExtension: fileExtension) {
                return directURL
            }
            if let vocabularyURL = bundle.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "Vocabulary"
            ) {
                return vocabularyURL
            }
        }
        return nil
    }

    private static func xmlEntriesByKey(
        _ xmlEntries: [NormalizedXMLEntry]
    ) throws -> [String: NormalizedXMLEntry] {
        var results: [String: NormalizedXMLEntry] = [:]
        for entry in xmlEntries {
            if results[entry.stableKey] != nil {
                throw LanguageVocabularyLoadError.duplicateXMLKey(entry.stableKey)
            }
            results[entry.stableKey] = entry
        }
        return results
    }

    private static func manifestEntriesByStableKey(
        _ manifestEntries: [LanguageVocabularyImageManifestEntry]
    ) throws -> [String: LanguageVocabularyImageManifestEntry] {
        var results: [String: LanguageVocabularyImageManifestEntry] = [:]
        for entry in manifestEntries {
            if results[entry.stableKey] != nil {
                throw LanguageVocabularyLoadError.duplicateManifestStableKey(entry.stableKey)
            }
            results[entry.stableKey] = entry
        }
        return results
    }

    private static func buildCategories(
        from xmlEntries: [NormalizedXMLEntry],
        manifestByStableKey: [String: LanguageVocabularyImageManifestEntry]
    ) -> [LanguageVocabularyLevel: [LanguageWordCategory]] {
        var itemsByLevelAndCategory: [LanguageVocabularyLevel: [LanguageWordCategoryID: [LanguageWordCatalogItem]]] = [:]
        var orderedCategoryIDsByLevel: [LanguageVocabularyLevel: [LanguageWordCategoryID]] = [:]

        for entry in xmlEntries {
            let item = LanguageWordCatalogItem(
                id: ContentItemID(rawValue: "language.words.\(entry.stableKey)"),
                stableKey: entry.stableKey,
                androidWordID: entry.isFromLegacyAndroidSource ? entry.stableKey : nil,
                englishText: entry.englishText,
                hebrewText: entry.hebrewText,
                imageManifestEntry: manifestByStableKey[entry.stableKey],
                baseLevel: entry.level,
                categoryID: entry.categoryID,
                hebrewSpeechText: legacyHebrewSpeechText(stableKey: entry.stableKey),
                contentKind: entry.contentKind
            )

            if itemsByLevelAndCategory[entry.level]?[entry.categoryID] == nil {
                orderedCategoryIDsByLevel[entry.level, default: []].append(entry.categoryID)
            }
            itemsByLevelAndCategory[entry.level, default: [:]][entry.categoryID, default: []].append(item)
        }

        var result: [LanguageVocabularyLevel: [LanguageWordCategory]] = [:]
        for level in LanguageVocabularyLevel.allCases {
            let categoryOrder = orderedCategoryIDsByLevel[level] ?? []
            let itemsByCategory = itemsByLevelAndCategory[level] ?? [:]
            result[level] = categoryOrder.compactMap { categoryID in
                guard let items = itemsByCategory[categoryID], !items.isEmpty else {
                    return nil
                }
                return LanguageWordCategory(
                    id: categoryID,
                    sourceName: categoryID.rawValue.uppercased(),
                    items: items
                )
            }
        }
        return result
    }

    private static func parseImageManifest(
        _ data: Data,
        validStableKeys: Set<String>
    ) throws -> [ParsedImageManifestEntry] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw LanguageVocabularyLoadError.invalidManifestHeader
        }
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            throw LanguageVocabularyLoadError.invalidManifestHeader
        }

        let columns = headerLine.components(separatedBy: "\t")
        guard columns.contains("stableKey") else {
            throw LanguageVocabularyLoadError.missingManifestStableKeyColumn
        }

        let requiredColumns = [
            "stableKey",
            "assetKey",
            "source",
            "english",
            "hebrew",
            "proposedBaseLevel",
            "proposedCategory",
            "iosAssetStatus",
            "androidAssetStatus",
            "imageAction"
        ]
        guard requiredColumns.allSatisfy(columns.contains) else {
            throw LanguageVocabularyLoadError.invalidManifestHeader
        }

        var indexByColumn: [String: Int] = [:]
        for (index, column) in columns.enumerated() {
            guard indexByColumn[column] == nil else {
                throw LanguageVocabularyLoadError.invalidManifestHeader
            }
            indexByColumn[column] = index
        }
        var entries: [ParsedImageManifestEntry] = []
        var seenStableKeys: Set<String> = []
        var seenAssetKeys: Set<String> = []

        for line in lines.dropFirst() {
            let minimumFieldCount = requiredColumns.compactMap { indexByColumn[$0] }.max().map { $0 + 1 } ?? 0
            let rawFields = line.components(separatedBy: "\t")
            guard rawFields.count >= minimumFieldCount,
                  rawFields.count <= columns.count else {
                throw LanguageVocabularyLoadError.invalidManifestRow(line)
            }
            let fields = rawFields + Array(repeating: "", count: columns.count - rawFields.count)

            let stableKey = fields[indexByColumn["stableKey"]!].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stableKey.isEmpty else {
                throw LanguageVocabularyLoadError.blankManifestStableKey(line)
            }
            guard isValidIdentifier(stableKey) else {
                throw LanguageVocabularyLoadError.invalidManifestStableKey(stableKey)
            }
            guard seenStableKeys.insert(stableKey).inserted else {
                throw LanguageVocabularyLoadError.duplicateManifestStableKey(stableKey)
            }
            guard validStableKeys.contains(stableKey) else {
                throw LanguageVocabularyLoadError.unknownManifestStableKey(stableKey)
            }

            let assetKey = fields[indexByColumn["assetKey"]!].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !assetKey.isEmpty else {
                throw LanguageVocabularyLoadError.blankManifestAssetKey(line)
            }
            guard isValidIdentifier(assetKey) else {
                throw LanguageVocabularyLoadError.invalidManifestAssetKey(assetKey)
            }
            guard seenAssetKeys.insert(assetKey).inserted else {
                throw LanguageVocabularyLoadError.duplicateManifestAssetKey(assetKey)
            }

            let levelString = fields[indexByColumn["proposedBaseLevel"]!]
            guard let level = LanguageVocabularyLevel(rawValue: levelString) else {
                throw LanguageVocabularyLoadError.invalidManifestLevel(levelString)
            }

            let iosAssetStatusString = fields[indexByColumn["iosAssetStatus"]!]
            guard let iosAssetStatus = LanguageVocabularyImageAssetStatus(rawValue: iosAssetStatusString) else {
                throw LanguageVocabularyLoadError.invalidManifestAssetStatus(iosAssetStatusString)
            }

            let androidAssetStatusString = fields[indexByColumn["androidAssetStatus"]!]
            guard let androidAssetStatus = LanguageVocabularyImageAssetStatus(
                rawValue: androidAssetStatusString
            ) else {
                throw LanguageVocabularyLoadError.invalidManifestAssetStatus(androidAssetStatusString)
            }

            let imageActionString = fields[indexByColumn["imageAction"]!]
            guard let imageAction = LanguageVocabularyImageAction(rawValue: imageActionString) else {
                throw LanguageVocabularyLoadError.invalidManifestImageAction(imageActionString)
            }

            let categoryString = fields[indexByColumn["proposedCategory"]!]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidIdentifier(categoryString) else {
                throw LanguageVocabularyLoadError.invalidManifestCategory(categoryString)
            }

            let entry = ParsedImageManifestEntry(
                stableKey: stableKey,
                assetReference: AssetReference(rawValue: assetKey),
                source: fields[indexByColumn["source"]!],
                englishText: fields[indexByColumn["english"]!],
                hebrewText: fields[indexByColumn["hebrew"]!],
                level: level,
                categoryID: LanguageWordCategoryID(rawValue: categoryString),
                iosAssetStatus: iosAssetStatus,
                androidAssetStatus: androidAssetStatus,
                imageAction: imageAction
            )
            try validateManifestActionStatus(entry, line: line)
            entries.append(entry)
        }

        return entries
    }

    private static func validateManifestMetadata(
        _ parsedManifestEntries: [ParsedImageManifestEntry],
        against xmlEntriesByKey: [String: NormalizedXMLEntry]
    ) throws {
        for entry in parsedManifestEntries {
            guard let xmlEntry = xmlEntriesByKey[entry.stableKey] else {
                throw LanguageVocabularyLoadError.unknownManifestStableKey(entry.stableKey)
            }
            guard entry.englishText == xmlEntry.englishText else {
                throw LanguageVocabularyLoadError.manifestEnglishMismatch(entry.stableKey)
            }
            guard entry.hebrewText == xmlEntry.hebrewText else {
                throw LanguageVocabularyLoadError.manifestHebrewMismatch(entry.stableKey)
            }
            guard entry.level == xmlEntry.level else {
                throw LanguageVocabularyLoadError.manifestLevelMismatch(entry.stableKey)
            }
            guard entry.categoryID == xmlEntry.categoryID else {
                throw LanguageVocabularyLoadError.manifestCategoryMismatch(entry.stableKey)
            }
        }
    }

    private static func finalizeManifestEntries(
        _ parsedEntries: [ParsedImageManifestEntry],
        availableAssetReferences: Set<AssetReference>
    ) -> [LanguageVocabularyImageManifestEntry] {
        parsedEntries.map { entry in
            LanguageVocabularyImageManifestEntry(
                stableKey: entry.stableKey,
                assetReference: entry.assetReference,
                source: entry.source,
                englishText: entry.englishText,
                hebrewText: entry.hebrewText,
                level: entry.level,
                categoryID: entry.categoryID,
                iosAssetStatus: entry.iosAssetStatus,
                androidAssetStatus: entry.androidAssetStatus,
                imageAction: entry.imageAction,
                isReadyInCurrentIOS: entry.imageAction == .reuseIOS
                    && entry.iosAssetStatus == .existingIOS
                    && availableAssetReferences.contains(entry.assetReference)
            )
        }
    }

    private static func parseNormalizedXML(
        _ data: Data
    ) throws -> [NormalizedXMLEntry] {
        let delegate = NormalizedVocabularyXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            if let error = delegate.error {
                throw error
            }
            throw LanguageVocabularyLoadError.xmlParseFailure(
                parser.parserError?.localizedDescription ?? "Unknown XML parser failure."
            )
        }

        if let error = delegate.error {
            throw error
        }
        return delegate.entries
    }

    private static func availableAssetReferences(
        from parsedManifestEntries: [ParsedImageManifestEntry]
    ) -> Set<AssetReference> {
        let candidateAssetReferences = Set(parsedManifestEntries.map(\.assetReference))

        #if canImport(UIKit)
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles + Bundle.allFrameworks
        return Set(candidateAssetReferences.filter { assetReference in
            bundles.contains { bundle in
                UIImage(named: assetReference.rawValue, in: bundle, compatibleWith: nil) != nil
            }
        })
        #else
        return candidateAssetReferences
        #endif
    }

    private static func legacyHebrewSpeechText(
        stableKey: String
    ) -> String? {
        stableKey == "fruits_kiwi" ? "Kiwi" : nil
    }

    private static func validateManifestActionStatus(
        _ entry: ParsedImageManifestEntry,
        line: String
    ) throws {
        switch entry.imageAction {
        case .reuseIOS:
            guard entry.iosAssetStatus == .existingIOS else {
                throw LanguageVocabularyLoadError.invalidManifestActionStatusCombination(line)
            }
        case .migrateAndroid:
            guard entry.iosAssetStatus == .missingIOS,
                  entry.androidAssetStatus == .existingAndroid else {
                throw LanguageVocabularyLoadError.invalidManifestActionStatusCombination(line)
            }
        case .trustedAcquire:
            guard entry.iosAssetStatus == .missingIOS,
                  entry.androidAssetStatus == .trustedExternal else {
                throw LanguageVocabularyLoadError.invalidManifestActionStatusCombination(line)
            }
        case .createNew:
            guard entry.iosAssetStatus == .missingIOS,
                  entry.androidAssetStatus == .missingAndroid else {
                throw LanguageVocabularyLoadError.invalidManifestActionStatusCombination(line)
            }
        }
    }

    private static func isValidIdentifier(
        _ value: String
    ) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x61 ... 0x7A, 0x30 ... 0x39, 0x5F:
                return true
            default:
                return false
            }
        }
    }
}

private extension LanguageVocabularyCatalogLoader {
    struct ParsedImageManifestEntry: Hashable, Sendable {
        let stableKey: String
        let assetReference: AssetReference
        let source: String
        let englishText: String
        let hebrewText: String
        let level: LanguageVocabularyLevel
        let categoryID: LanguageWordCategoryID
        let iosAssetStatus: LanguageVocabularyImageAssetStatus
        let androidAssetStatus: LanguageVocabularyImageAssetStatus
        let imageAction: LanguageVocabularyImageAction
    }

    struct NormalizedXMLEntry: Hashable, Sendable {
        let stableKey: String
        let categoryID: LanguageWordCategoryID
        let level: LanguageVocabularyLevel
        let englishText: String
        let hebrewText: String
        let contentKind: LanguageVocabularyContentKind
        let isFromLegacyAndroidSource: Bool
        let ordinalWithinArray: Int
    }

    final class NormalizedVocabularyXMLParserDelegate: NSObject, XMLParserDelegate {
        private(set) var entries: [NormalizedXMLEntry] = []
        private(set) var error: LanguageVocabularyLoadError?

        private var currentArrayName: String?
        private var currentCategoryID: LanguageWordCategoryID?
        private var currentLevel: LanguageVocabularyLevel?
        private var ordinalWithinArray = 0

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard error == nil else {
                parser.abortParsing()
                return
            }

            switch elementName {
            case "string-array":
                guard let name = attributeDict["name"] else {
                    error = .malformedArrayName("")
                    parser.abortParsing()
                    return
                }

                do {
                    let parsedName = try LanguageVocabularyCatalogLoader.parseArrayName(name)
                    currentArrayName = name
                    currentCategoryID = parsedName.categoryID
                    currentLevel = parsedName.level
                    ordinalWithinArray = 0
                } catch let loadError as LanguageVocabularyLoadError {
                    error = loadError
                    parser.abortParsing()
                } catch {
                    self.error = .xmlParseFailure(error.localizedDescription)
                    parser.abortParsing()
                }

            case "word", "sentence":
                guard let currentArrayName,
                      let currentCategoryID,
                      let currentLevel else {
                    return
                }

                guard let rawStableKey = attributeDict["key"] else {
                    error = .missingXMLKey(arrayName: currentArrayName)
                    parser.abortParsing()
                    return
                }
                let stableKey = rawStableKey
                guard !stableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    error = .blankXMLKey(arrayName: currentArrayName)
                    parser.abortParsing()
                    return
                }
                guard LanguageVocabularyCatalogLoader.isValidIdentifier(stableKey) else {
                    error = .invalidXMLKey(stableKey)
                    parser.abortParsing()
                    return
                }

                guard let englishText = attributeDict["en"]?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                !englishText.isEmpty else {
                    error = .missingXMLEnglish(key: stableKey)
                    parser.abortParsing()
                    return
                }

                guard let hebrewText = attributeDict["he"]?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                !hebrewText.isEmpty else {
                    error = .missingXMLHebrew(key: stableKey)
                    parser.abortParsing()
                    return
                }

                ordinalWithinArray += 1
                entries.append(
                    NormalizedXMLEntry(
                        stableKey: stableKey,
                        categoryID: currentCategoryID,
                        level: currentLevel,
                        englishText: englishText,
                        hebrewText: hebrewText,
                        contentKind: inferredContentKind(
                            categoryID: currentCategoryID,
                            englishText: englishText
                        ),
                        isFromLegacyAndroidSource: isLegacyAndroidSource(attributeDict),
                        ordinalWithinArray: ordinalWithinArray
                    )
                )

            default:
                break
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            guard elementName == "string-array" else {
                return
            }

            currentArrayName = nil
            currentCategoryID = nil
            currentLevel = nil
            ordinalWithinArray = 0
        }

        private func inferredContentKind(
            categoryID: LanguageWordCategoryID,
            englishText: String
        ) -> LanguageVocabularyContentKind {
            if categoryID.rawValue == "sentences" {
                return .sentence
            }
            return englishText.contains(" ") ? .phrase : .word
        }

        private func isLegacyAndroidSource(
            _ attributes: [String: String]
        ) -> Bool {
            attributes.keys.contains { !["key", "en", "he"].contains($0) }
        }
    }

    final class BundleMarker: NSObject {}
}
