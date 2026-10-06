import Foundation

// Android cross/CrossGeometry.kt (MinikCrossPong 828c6fc). World frame: origin = table centre, +x right, +y DOWN (screen),
// height up; 1.0 = arm width W. MPPoint stays the classic point type; the cross table only adds vector algebra around it.
extension MPPoint {
    static func + (a: MPPoint, b: MPPoint) -> MPPoint { MPPoint(a.x + b.x, a.y + b.y) }
    static func - (a: MPPoint, b: MPPoint) -> MPPoint { MPPoint(a.x - b.x, a.y - b.y) }
    static func * (a: MPPoint, k: Double) -> MPPoint { MPPoint(a.x * k, a.y * k) }
    static prefix func - (a: MPPoint) -> MPPoint { MPPoint(-a.x, -a.y) }
    func dot(_ o: MPPoint) -> Double { x * o.x + y * o.y }
    func cross(_ o: MPPoint) -> Double { x * o.y - y * o.x }
    var length: Double { hypot(x, y) }
    var finite: Bool { x.isFinite && y.isFinite }
}

/// Kotlin `Int.mod(n)` / `Math.floorMod`: never negative for a positive divisor.
func crossMod(_ value: Int, _ divisor: Int) -> Int {
    guard divisor != 0 else { return 0 }
    let r = value % divisor
    return r < 0 ? r + divisor : r
}
func crossMod(_ value: Int64, _ divisor: Int64) -> Int64 {
    guard divisor != 0 else { return 0 }
    let r = value % divisor
    return r < 0 ? r + divisor : r
}
/// Kotlin `String.fold(seed) { acc, c -> acc * 31 + c.code }` with Long overflow (UTF-16 code units).
func crossFold(_ text: String, _ seed: Int64) -> Int64 { text.utf16.reduce(seed) { ($0 &* 31) &+ Int64($1) } }

/// The rest of Kotlin `kotlin.random.Random` on top of `MPKotlinRandom` (XorWow), so seeded house players, simulations
/// and draws make the same choices as Android for the same seed.
extension MPKotlinRandom {
    /// Kotlin `Random(seed: Int)` equals `Random(seed.toLong())`: both sign-extend the high word.
    init(intSeed: Int32) { self.init(seed: Int64(intSeed)) }
    /// Kotlin `XorWowRandom.nextBits` (`takeUpperBits`).
    mutating func nextBits(_ bitCount: Int) -> Int32 {
        let raw = nextInt()
        guard bitCount > 0 else { return 0 }
        return Int32(bitPattern: UInt32(bitPattern: raw) >> UInt32(32 - bitCount))
    }
    /// Kotlin `Random.nextDouble()`: 53 random bits in [0, 1).
    mutating func nextDouble() -> Double {
        let high = Int64(nextBits(26)), low = Int64(nextBits(27))
        return Double((high << 27) + low) / Double(Int64(1) << 53)
    }
    /// Kotlin `Random.nextDouble(from, until)`.
    mutating func nextDouble(_ from: Double, _ until: Double) -> Double {
        let r = from + nextDouble() * (until - from)
        return r >= until ? until.nextDown : r
    }
    /// Kotlin `Random.nextBoolean()`.
    mutating func nextBoolean() -> Bool { nextBits(1) != 0 }
    /// Kotlin `Random.nextLong()`: two ints, high word first.
    mutating func nextLong() -> Int64 {
        let high = Int64(nextInt()), low = Int64(nextInt())
        return (high << 32) &+ low
    }
    /// Kotlin `Random.nextInt(until)` as a Swift Int.
    mutating func nextIndex(_ until: Int) -> Int {
        guard until > 0 else { return 0 }
        return Int(nextInt(until: Int32(until)))
    }
    /// Kotlin `List.random(random)`.
    mutating func element<T>(_ list: [T]) -> T { list[nextIndex(list.count)] }
}

/// Seat-local coordinates: lateral `u` toward the seat's right hand, depth `v` from the centre along its arm.
struct CrossLocal: Equatable {
    var u: Double
    var v: Double
    init(_ u: Double, _ v: Double) { self.u = u; self.v = v }
}

/// Drawable outline primitives in world units; the renderer unions them into one table.
enum CrossTableShape {
    /// Corners inner-left, inner-right, outer-right, outer-left as seen by `seat`.
    case arm(seat: Int, corners: [MPPoint])
    case hub(radius: Double)
}

/// Radial net between adjacent seats `left` and `right` (= left+1), from the centre post to `end`.
struct CrossNetSegment {
    let left: Int
    let right: Int
    let end: MPPoint
}

/// A fraction range of a straight path (Kotlin `ClosedFloatingPointRange<Double>` without its precondition).
struct CrossSpan: Equatable {
    var start: Double
    var end: Double
}

/// Seats, arms, nets, territories and zones of the 2/3/4-player table. Collision, bounce ownership, input zones and drawing
/// all come from this one type. Two players face each other across one straight net (the classic table, which the app
/// itself never draws: every two-player fixture plays the classic game).
struct CrossGeometry {
    static let width = 1.0
    static let half = width / 2
    /// Arm reach, centre → arm end, for both table sizes.
    static let reach = 1.10
    static let hubThree = 0.72
    static let post = 0.035
    static let strikeNear = reach - 0.42
    static let strikeFar = reach + 0.16
    static let strikeHalf = half + 0.14
    static let serveNear = 0.55
    static let serveFar = reach - 0.12
    static let serveHalf = half - 0.08
    static let homeDepth = reach + 0.06
    private static let edge = 1e-9

    let players: Int
    let sector: Double
    /// 3 players: a broad round centre that fills the notches between the arms. 4 players: a plain plus.
    let hub: Double
    let netLength: Double
    let nets: [CrossNetSegment]
    private let dirs: [MPPoint]
    private let rights: [MPPoint]

    init(_ players: Int) {
        // Android requires 2...4; a stray value from a corrupt record is clamped instead of crashing.
        let n = min(4, max(2, players))
        self.players = n
        sector = 2 * Double.pi / Double(n)
        hub = n == 3 ? CrossGeometry.hubThree : 0
        netLength = max(hub, CrossGeometry.half / sin(Double.pi / Double(n)))
        let step = sector
        dirs = (0..<n).map { CrossGeometry.clean(MPPoint(sin(Double($0) * step), cos(Double($0) * step))) }
        rights = (0..<n).map { CrossGeometry.clean(MPPoint(cos(Double($0) * step), -sin(Double($0) * step))) }
        let length = netLength
        nets = (0..<n).map { i -> CrossNetSegment in
            let a = Double(i) * step + step / 2
            return CrossNetSegment(left: i, right: (i + 1) % n, end: CrossGeometry.clean(MPPoint(sin(a), cos(a)) * length))
        }
    }
    var seats: Range<Int> { 0..<players }
    func wrap(_ seat: Int) -> Int { crossMod(seat, players) }
    func angle(_ seat: Int) -> Double { Double(wrap(seat)) * sector }
    /// Outward direction of a seat's arm (seat 0 = (0,1) = bottom).
    func dir(_ seat: Int) -> MPPoint { dirs[wrap(seat)] }
    /// The seat's right hand (seat 0 = +x).
    func right(_ seat: Int) -> MPPoint { rights[wrap(seat)] }
    func toLocal(_ seat: Int, _ p: MPPoint) -> CrossLocal { CrossLocal(p.dot(right(seat)), p.dot(dir(seat))) }
    func fromLocal(_ seat: Int, _ u: Double, _ v: Double) -> MPPoint { right(seat) * u + dir(seat) * v }
    func fromLocal(_ seat: Int, _ local: CrossLocal) -> MPPoint { fromLocal(seat, local.u, local.v) }
    /// Seat view (= rotate(p, -θ)): that seat at the bottom, its right hand at screen right. The map is linear, so
    /// velocities use it exactly like points.
    func toView(_ seat: Int, _ p: MPPoint) -> MPPoint {
        let local = toLocal(seat, p)
        return MPPoint(local.u, local.v)
    }
    func fromView(_ seat: Int, _ p: MPPoint) -> MPPoint { fromLocal(seat, p.x, p.y) }
    func inArm(_ seat: Int, _ p: MPPoint) -> Bool {
        let l = toLocal(seat, p), e = CrossGeometry.edge
        return abs(l.u) <= CrossGeometry.half + e && l.v >= -e && l.v <= CrossGeometry.reach + e
    }
    func onTable(_ p: MPPoint) -> Bool { p.length <= hub + CrossGeometry.edge || seats.contains { inArm($0, p) } }
    /// Angular territory sector of `p`, on or off the table (the exact centre counts as seat 0).
    func sectorOf(_ p: MPPoint) -> Int {
        var a = atan2(p.x, p.y)
        if a < 0 { a += 2 * Double.pi }
        let raw = floor((a + sector / 2) / sector)
        guard raw.isFinite else { return 0 }
        return crossMod(Int(raw), players)
    }
    /// Valid receiving area: every table point has exactly one owner and the nets lie on the borders.
    func owner(_ p: MPPoint) -> Int? { onTable(p) ? sectorOf(p) : nil }
    /// Where `seat` may contact the ball.
    func inStrikeZone(_ seat: Int, _ p: MPPoint) -> Bool {
        let l = toLocal(seat, p)
        return l.v >= CrossGeometry.strikeNear && l.v <= CrossGeometry.strikeFar && abs(l.u) <= CrossGeometry.strikeHalf
    }
    /// Where a serve by `seat` must make its first (own-side) bounce.
    func inServeZone(_ seat: Int, _ p: MPPoint) -> Bool {
        let l = toLocal(seat, p)
        return l.v >= CrossGeometry.serveNear && l.v <= CrossGeometry.serveFar && abs(l.u) <= CrossGeometry.serveHalf
    }
    /// Resting racket point of a house or remote player.
    func home(_ seat: Int) -> MPPoint { fromLocal(seat, 0, CrossGeometry.homeDepth) }
    func armCorners(_ seat: Int) -> [MPPoint] {
        let h = CrossGeometry.half, r = CrossGeometry.reach
        return [fromLocal(seat, -h, 0), fromLocal(seat, h, 0), fromLocal(seat, h, r), fromLocal(seat, -h, r)]
    }
    func outline() -> [CrossTableShape] {
        var shapes = seats.map { CrossTableShape.arm(seat: $0, corners: armCorners($0)) }
        if hub > 0 { shapes.append(.hub(radius: hub)) }
        return shapes
    }
    /// Fraction ranges of the straight path `from`→`to` that meet the net: a wall crossing (a single point), a run along a
    /// wall line, or the passage through the centre post's column. Heights decide contact.
    func netSpans(_ from: MPPoint, _ to: MPPoint) -> [CrossSpan] {
        let d = to - from
        var spans: [CrossSpan] = []
        for net in nets {
            let e = net.end
            let denominator = d.cross(e)
            if abs(denominator) > 1e-15 {
                let f = -from.cross(e) / denominator
                let s = -from.cross(d) / denominator
                if f >= 0 && f <= 1 && s >= 0 && s <= 1 { spans.append(CrossSpan(start: f, end: f)) }
            } else if abs(from.cross(e)) <= 1e-9 * e.length {
                // Travelling exactly along the net line: the overlap with the wall.
                let square = e.dot(e)
                let start = from.dot(e) / square
                let change = d.dot(e) / square
                if abs(change) < 1e-15 {
                    if start >= 0 && start <= 1 { spans.append(CrossSpan(start: 0, end: 1)) }
                } else {
                    let a = -start / change, b = (1 - start) / change
                    let lo = max(0, min(a, b)), hi = min(1, max(a, b))
                    if lo <= hi { spans.append(CrossSpan(start: lo, end: hi)) }
                }
            }
        }
        let post = CrossGeometry.post
        let a = d.dot(d), b = 2 * from.dot(d), c = from.dot(from) - post * post
        if a < 1e-18 {
            if c <= 0 { spans.append(CrossSpan(start: 0, end: 1)) }
        } else {
            let discriminant = b * b - 4 * a * c
            if discriminant >= 0 {
                let root = sqrt(discriminant)
                let lo = max(0, (-b - root) / (2 * a)), hi = min(1, (-b + root) / (2 * a))
                if lo <= hi { spans.append(CrossSpan(start: lo, end: hi)) }
            }
        }
        return spans
    }
    /// rotate(dir(θ), α) = dir(θ+α); also maps right(θ) to right(θ+α).
    static func rotate(_ p: MPPoint, _ a: Double) -> MPPoint { MPPoint(p.x * cos(a) + p.y * sin(a), -p.x * sin(a) + p.y * cos(a)) }
    private static func clean(_ p: MPPoint) -> MPPoint { MPPoint(abs(p.x) < 1e-12 ? 0 : p.x, abs(p.y) < 1e-12 ? 0 : p.y) }
}
