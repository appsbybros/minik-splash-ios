import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageResult: Codable {
    let name: String
    let sourceDimensions: Dimensions?
    let heicDimensions: Dimensions?
    let webPBytes: Int?
    let heicBytes: Int?
    let heicToWebPRatio: Double?
    let sourceHasAlpha: Bool?
    let heicHasAlpha: Bool?
    let heicDecodeSucceeded: Bool
    let errors: [String]
}

struct Dimensions: Codable {
    let width: Int
    let height: Int
}

struct AggregateResult: Codable {
    let webPTotalBytes: Int
    let heicTotalBytes: Int
    let heicToWebPRatio: Double?
    let percentageSizeDifference: Double?
    let successfulImages: Int
    let failedImages: Int
}

struct BenchmarkReport: Codable {
    let encoderTypeIdentifier: String
    let requestedLossyQuality: Double
    let results: [ImageResult]
    let aggregate: AggregateResult
}

private let resourceNames = [
    "apple", "lemon", "plum", "peach", "grapes",
    "mango", "banana", "orange", "lime", "kiwi"
]
private let requestedQuality = 0.90
private let fileManager = FileManager.default

private func hasAlpha(_ image: CGImage) -> Bool {
    switch image.alphaInfo {
    case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
        return true
    case .none, .noneSkipFirst, .noneSkipLast:
        return false
    @unknown default:
        return false
    }
}

private func byteSize(at url: URL) throws -> Int {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? NSNumber else {
        throw NSError(
            domain: "ImageFormatBenchmark",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "File size unavailable for \(url.path)."]
        )
    }
    return size.intValue
}

private func benchmarkImage(
    named name: String,
    fixtureDirectory: URL,
    heicDirectory: URL
) -> ImageResult {
    let sourceURL = fixtureDirectory.appendingPathComponent("\(name).webp")
    let outputURL = heicDirectory.appendingPathComponent("\(name).heic")
    var errors: [String] = []
    var sourceDimensions: Dimensions?
    var outputDimensions: Dimensions?
    var sourceBytes: Int?
    var outputBytes: Int?
    var sourceAlpha: Bool?
    var outputAlpha: Bool?
    var decodedOutput = false

    func result() -> ImageResult {
        let sizeRatio: Double?
        if let sourceBytes, let outputBytes, sourceBytes > 0 {
            sizeRatio = Double(outputBytes) / Double(sourceBytes)
        } else {
            sizeRatio = nil
        }
        return ImageResult(
            name: name,
            sourceDimensions: sourceDimensions,
            heicDimensions: outputDimensions,
            webPBytes: sourceBytes,
            heicBytes: outputBytes,
            heicToWebPRatio: sizeRatio,
            sourceHasAlpha: sourceAlpha,
            heicHasAlpha: outputAlpha,
            heicDecodeSucceeded: decodedOutput,
            errors: errors
        )
    }

    do {
        sourceBytes = try byteSize(at: sourceURL)
    } catch {
        errors.append("Source byte-size lookup failed: \(error.localizedDescription)")
    }

    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
        errors.append("ImageIO could not create a CGImageSource for the WebP fixture.")
        return result()
    }
    guard let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        let type = CGImageSourceGetType(source).map { $0 as String } ?? "unknown"
        errors.append("ImageIO could not decode the WebP fixture. Reported type: \(type).")
        return result()
    }

    sourceDimensions = Dimensions(width: sourceImage.width, height: sourceImage.height)
    sourceAlpha = hasAlpha(sourceImage)

    let destinationTypes = CGImageDestinationCopyTypeIdentifiers() as NSArray
    guard destinationTypes.contains(UTType.heic.identifier) else {
        errors.append(
            "ImageIO does not advertise a HEIC encoder (\(UTType.heic.identifier)) "
                + "on this macOS runner."
        )
        return result()
    }
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.heic.identifier as CFString,
        1,
        nil
    ) else {
        errors.append("CGImageDestination could not create the HEIC output destination.")
        return result()
    }

    let properties = [
        kCGImageDestinationLossyCompressionQuality: requestedQuality
    ] as CFDictionary
    CGImageDestinationAddImage(destination, sourceImage, properties)
    guard CGImageDestinationFinalize(destination) else {
        errors.append("CGImageDestinationFinalize failed while encoding HEIC.")
        return result()
    }

    do {
        outputBytes = try byteSize(at: outputURL)
    } catch {
        errors.append("HEIC byte-size lookup failed: \(error.localizedDescription)")
    }

    guard let outputSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil) else {
        errors.append("ImageIO could not reopen the generated HEIC.")
        return result()
    }
    guard let outputImage = CGImageSourceCreateImageAtIndex(outputSource, 0, nil) else {
        let type = CGImageSourceGetType(outputSource).map { $0 as String } ?? "unknown"
        errors.append("ImageIO could not decode the generated HEIC. Reported type: \(type).")
        return result()
    }

    decodedOutput = true
    outputDimensions = Dimensions(width: outputImage.width, height: outputImage.height)
    outputAlpha = hasAlpha(outputImage)

    if sourceDimensions?.width != outputDimensions?.width
        || sourceDimensions?.height != outputDimensions?.height {
        errors.append("Generated HEIC dimensions do not match the source WebP dimensions.")
    }
    if sourceAlpha == true && outputAlpha != true {
        errors.append(
            "Apple-native HEIC encoding did not preserve alpha reported by the decoded WebP."
        )
    }

    return result()
}

private func display(_ value: Int?) -> String {
    value.map(String.init) ?? "N/A"
}

private func display(_ dimensions: Dimensions?) -> String {
    guard let dimensions else { return "N/A" }
    return "\(dimensions.width)×\(dimensions.height)"
}

private func display(_ value: Bool?) -> String {
    guard let value else { return "N/A" }
    return value ? "Yes" : "No"
}

private func displayRatio(_ value: Double?) -> String {
    guard let value else { return "N/A" }
    return String(format: "%.3f", value)
}

private func makeSummary(_ report: BenchmarkReport) -> String {
    var lines = [
        "# Apple-native WebP → HEIC benchmark",
        "",
        "Encoder type: `\(report.encoderTypeIdentifier)`  ",
        "Requested lossy quality: `\(String(format: "%.2f", report.requestedLossyQuality))`",
        "",
        "| Name | Dimensions | WebP bytes | HEIC bytes | HEIC/WebP | Source alpha | HEIC alpha | HEIC decodes | HEIC dimensions | Errors |",
        "|---|---:|---:|---:|---:|---|---|---|---:|---|"
    ]

    for image in report.results {
        let errorText = image.errors.isEmpty
            ? "None"
            : image.errors.joined(separator: "; ").replacingOccurrences(of: "|", with: "\\|")
        lines.append(
            "| \(image.name)"
                + " | \(display(image.sourceDimensions))"
                + " | \(display(image.webPBytes))"
                + " | \(display(image.heicBytes))"
                + " | \(displayRatio(image.heicToWebPRatio))"
                + " | \(display(image.sourceHasAlpha))"
                + " | \(display(image.heicHasAlpha))"
                + " | \(image.heicDecodeSucceeded ? "Yes" : "No")"
                + " | \(display(image.heicDimensions))"
                + " | \(errorText) |"
        )
    }

    let aggregate = report.aggregate
    lines += [
        "",
        "## Aggregate",
        "",
        "- WebP total bytes: \(aggregate.webPTotalBytes)",
        "- HEIC total bytes: \(aggregate.heicTotalBytes)",
        "- Aggregate HEIC/WebP ratio: \(displayRatio(aggregate.heicToWebPRatio))",
        "- Percentage size difference: \(aggregate.percentageSizeDifference.map { String(format: "%.2f%%", $0) } ?? "N/A")",
        "- Successful images: \(aggregate.successfulImages)",
        "- Failed images: \(aggregate.failedImages)",
        ""
    ]
    return lines.joined(separator: "\n")
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: image_format_benchmark.swift <output-directory>\n", stderr)
    exit(2)
}

let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let fixtureDirectory = repositoryRoot
    .appendingPathComponent("BenchmarkFixtures/LanguageImages", isDirectory: true)
let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments[1],
    relativeTo: repositoryRoot
).standardizedFileURL
let heicDirectory = outputDirectory.appendingPathComponent("heic", isDirectory: true)

do {
    try fileManager.createDirectory(at: heicDirectory, withIntermediateDirectories: true)
} catch {
    fputs("Could not create benchmark output directory: \(error.localizedDescription)\n", stderr)
    exit(2)
}

let results = resourceNames.map {
    benchmarkImage(named: $0, fixtureDirectory: fixtureDirectory, heicDirectory: heicDirectory)
}
let webPTotal = results.compactMap(\.webPBytes).reduce(0, +)
let heicTotal = results.compactMap(\.heicBytes).reduce(0, +)
let failedCount = results.filter { !$0.errors.isEmpty }.count
let aggregateIsComplete = failedCount == 0 && results.count == resourceNames.count
let aggregateRatio = aggregateIsComplete && webPTotal > 0
    ? Double(heicTotal) / Double(webPTotal)
    : nil
let percentageDifference = aggregateRatio.map { ($0 - 1.0) * 100.0 }
let report = BenchmarkReport(
    encoderTypeIdentifier: UTType.heic.identifier,
    requestedLossyQuality: requestedQuality,
    results: results,
    aggregate: AggregateResult(
        webPTotalBytes: webPTotal,
        heicTotalBytes: heicTotal,
        heicToWebPRatio: aggregateRatio,
        percentageSizeDifference: percentageDifference,
        successfulImages: results.count - failedCount,
        failedImages: failedCount
    )
)

do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(
        to: outputDirectory.appendingPathComponent("report.json"),
        options: .atomic
    )
    let summary = makeSummary(report)
    try summary.write(
        to: outputDirectory.appendingPathComponent("summary.md"),
        atomically: true,
        encoding: .utf8
    )
    print(summary)
} catch {
    fputs("Could not write benchmark reports: \(error.localizedDescription)\n", stderr)
    exit(2)
}

if failedCount > 0 {
    exit(1)
}
