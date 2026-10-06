import XCTest
@testable import MinikMultiPingPong

// iOS-only: MPKotlinRandom must replay `kotlin.random.Random(seed)` (XorWow) exactly, so seeded house players, table
// simulations and knockout draws make the same choices as Android. Reference values were printed by kotlin-stdlib 2.1.0
// (`Random(42)`, `Random(-7)`, `Random(123456789012L)`, `List.shuffled(random)`, `List.random(random)`).
final class KotlinRandomParityTests: XCTestCase {
    private struct Reference {
        var ints: [Int32]
        var until10: [Int]
        var until8: [Int]
        var doubles: [Double]
        var ranged: [Double]
        var bools: [Bool]
        var longs: [Int64]
        var shuffled: [Int]
        var element: Int
    }

    private func check(_ random: MPKotlinRandom, _ expected: Reference, _ label: String) {
        var r = random
        var ints: [Int32] = []
        for _ in 0..<5 { ints.append(r.nextInt()) }
        XCTAssertEqual(expected.ints, ints, label)
        var until10: [Int] = []
        for _ in 0..<5 { until10.append(r.nextIndex(10)) }
        XCTAssertEqual(expected.until10, until10, label)
        var until8: [Int] = []
        for _ in 0..<5 { until8.append(Int(r.nextInt(until: 8))) }
        XCTAssertEqual(expected.until8, until8, label)
        var doubles: [Double] = []
        for _ in 0..<3 { doubles.append(r.nextDouble()) }
        XCTAssertEqual(expected.doubles, doubles, label)
        var ranged: [Double] = []
        for _ in 0..<3 { ranged.append(r.nextDouble(-1.5, 1.5)) }
        XCTAssertEqual(expected.ranged, ranged, label)
        var bools: [Bool] = []
        for _ in 0..<5 { bools.append(r.nextBoolean()) }
        XCTAssertEqual(expected.bools, bools, label)
        var longs: [Int64] = []
        for _ in 0..<2 { longs.append(r.nextLong()) }
        XCTAssertEqual(expected.longs, longs, label)
        let shuffled = r.shuffled(Array(0..<10))
        XCTAssertEqual(expected.shuffled, shuffled, label)
        let element = r.element(Array(0..<10))
        XCTAssertEqual(expected.element, element, label)
    }

    func testIntSeedFortyTwoMatchesKotlin() {
        check(MPKotlinRandom(intSeed: 42), Reference(
            ints: [972016666, 1740578880, -408207414, -112774692, 1162768683],
            until10: [2, 1, 0, 9, 7],
            until8: [4, 5, 2, 5, 1],
            doubles: [0.9427830814283763, 0.1134207410437057, 0.1915288662224609],
            ranged: [-0.057267540506247494, -0.6444650724930343, -0.04778420995603483],
            bools: [true, false, false, false, false],
            longs: [-829198351873176399, 8270882580948136240],
            shuffled: [5, 6, 3, 9, 1, 0, 8, 2, 4, 7],
            element: 3), "Random(42)")
    }

    func testNegativeIntSeedMatchesKotlin() {
        check(MPKotlinRandom(intSeed: -7), Reference(
            ints: [493578350, -2123338769, -1218139981, -1791905413, -702750341],
            until10: [2, 0, 2, 2, 7],
            until8: [2, 3, 7, 4, 0],
            doubles: [0.6678116717184747, 0.9217776909132867, 0.6916452333769824],
            ranged: [1.4507590145353761, -0.24455280739717744, 0.5362980387251337],
            bools: [false, true, true, false, true],
            longs: [-2758192099669446895, 1382317232649334822],
            shuffled: [8, 7, 1, 4, 3, 0, 9, 6, 5, 2],
            element: 8), "Random(-7)")
    }

    func testLongSeedMatchesKotlin() {
        check(MPKotlinRandom(seed: 123456789012), Reference(
            ints: [1514313960, -2057386076, 1929340550, -963029355, 153644130],
            until10: [8, 3, 3, 2, 7],
            until8: [2, 3, 0, 4, 6],
            doubles: [0.8832516096727285, 0.7222040253725456, 0.389425753396616],
            ranged: [-0.9110162641397579, 1.422462088979008, 0.6067620351109202],
            bools: [true, true, true, false, false],
            longs: [3543078721520634241, 640372441196553475],
            shuffled: [3, 0, 5, 7, 2, 6, 4, 1, 8, 9],
            element: 5), "Random(123456789012L)")
    }

    func testIntSeedEqualsTheSignExtendedLongSeed() {
        var a = MPKotlinRandom(intSeed: -7)
        var b = MPKotlinRandom(seed: -7)
        for _ in 0..<20 {
            let x = a.nextInt()
            let y = b.nextInt()
            XCTAssertEqual(x, y)
        }
    }

    func testFloorModAndStringFoldMatchKotlin() {
        XCTAssertEqual(3, crossMod(-1, 4))
        XCTAssertEqual(0, crossMod(8, 4))
        XCTAssertEqual(Int64(2), crossMod(Int64(-7), Int64(3)))
        // "ab".fold(7L) { acc, c -> acc * 31 + c.code } = (7 * 31 + 97) * 31 + 98
        XCTAssertEqual(Int64((7 * 31 + 97) * 31 + 98), crossFold("ab", 7))
    }
}
