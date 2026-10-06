import XCTest
@testable import MinikSplash

/// The iOS port reproduces Kotlin's Random, Java String.hashCode and Java HashMap order exactly
/// (golden values captured from the Android classes).
final class KotlinCompatTests: XCTestCase {
    func testKotlinRandomMatchesAndroid() {
        let rows = AndroidGolden.rows(AndroidGolden.random)
        XCTAssertEqual(rows.count, 6)
        for row in rows {
            let parts = row.components(separatedBy: " | ")
            XCTAssertEqual(parts.count, 5, row)
            guard parts.count == 5, let seed = Int64(parts[0].replacingOccurrences(of: "RANDOM ", with: "")) else { continue }
            let r = KotlinRandom(seed: seed)
            let ints = parts[1].split(separator: " ").compactMap { Int32($0) }
            XCTAssertEqual(ints.count, 5)
            for expected in ints { XCTAssertEqual(r.nextRawInt(), expected, row) }
            let doubles = parts[2].split(separator: " ").compactMap { Double($0) }
            XCTAssertEqual(doubles.count, 3)
            for expected in doubles { XCTAssertEqual(r.nextDouble(), expected, row) }
            let tail = parts[3].split(separator: " ").compactMap { Int($0) }
            XCTAssertEqual(tail, [r.nextInt(10), r.nextInt(16), r.nextInt(1, 9), r.nextInt(0, 7), r.nextInt(201)], row)
            let shuffled = parts[4].trimmingCharacters(in: CharacterSet(charactersIn: "[]")).components(separatedBy: ", ").compactMap { Int($0) }
            XCTAssertEqual(Array(0...5).kotlinShuffled(r), shuffled, row)
        }
    }

    func testJavaHashCodeMatchesAndroid() {
        let rows = AndroidGolden.rows(AndroidGolden.hashes)
        XCTAssertEqual(rows.count, 8)
        for row in rows {
            let parts = row.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false).map { String($0) }
            guard parts.count == 3, let expected = Int32(parts[1]) else {
                XCTFail(row)
                continue
            }
            XCTAssertEqual(parts[2].javaHashCode, expected, row)
        }
    }

    func testJavaHashMapOrderMatchesAndroid() {
        for row in AndroidGolden.rows(AndroidGolden.maps) {
            let body = row.replacingOccurrences(of: "MAP ", with: "")
            let sides = body.components(separatedBy: " => ")
            XCTAssertEqual(sides.count, 2)
            guard sides.count == 2 else { continue }
            let keys = sides[0].components(separatedBy: ",")
            XCTAssertEqual(JavaOrder.hashMapOrder(keys), sides[1].components(separatedBy: ","), row)
        }
    }

    func testStableSortKeepsOriginalOrderForTies() {
        let values = [(1, "a"), (0, "b"), (1, "c"), (0, "d")]
        let sorted = values.stableSorted { $0.0 < $1.0 }.map { $0.1 }
        XCTAssertEqual(sorted, ["b", "d", "a", "c"])
    }

    func testKotlinNumberConversionsNeverTrap() {
        XCTAssertEqual(KotlinNumber.int(.nan), 0)
        XCTAssertEqual(KotlinNumber.int(1e12), Int(Int32.max))
        XCTAssertEqual(KotlinNumber.int(-3.9), -3)
        XCTAssertEqual(KotlinNumber.long(.infinity), Int64.max)
    }
}
