import Foundation

enum MPNames {
    static let icons = ["🐱", "🦊", "🐼", "🐸", "🐯", "🐧"]
    static func candidate(_ index: Int, hebrew: Bool, suffix: Int = 0, character: String = "") -> String {
        let i = abs(index % 100), extra = suffix > 0 ? String(suffix) : ""
        if let player = MPRoster.find(character) {
            let en = ["Best", "Happy", "Human", "Summer", "Winter", "Green", "Blue", "Sunny", "Super", "Brave"]
            let he = ["בכתר", "בכיף", "בקצב", "בקיץ", "בחורף", "בירוק", "בכחול", "בשמש", "בזהב", "בנצנוץ"]
            let word = character == "moshiko" && i % 10 == 3 ? "Beach" : character == "moshiko" && i % 10 == 4 ? "Snowy" : en[i % 10]
            return (hebrew ? player.hebrew + " " + he[i % 10] : word + player.english.replacingOccurrences(of: " ", with: "")) + extra
        }
        let adjectives = ["Green", "Blue", "Pink", "Sunny", "Happy", "Brave", "Sweet", "Lucky", "Playful", "Gentle"]
        let animals = ["Frog", "Panda", "Bunny", "Fox", "Koala", "Otter", "Tiger", "Bear", "Duck", "Owl"]
        let nouns = ["צפרדע", "פנדה", "ארנב", "שועל", "קואלה", "לוטרה", "נמר", "דובון", "ברווז", "ינשוף"]
        let masculine = ["ירוק", "כחול", "ורוד", "זוהר", "שמח", "אמיץ", "מתוק", "זריז", "חייכן", "חמוד"]
        let feminine = ["ירוקה", "כחולה", "ורודה", "זוהרת", "שמחה", "אמיצה", "מתוקה", "זריזה", "חייכנית", "חמודה"]
        return (hebrew ? nouns[i % 10] + " " + ([0, 1, 4, 5].contains(i % 10) ? feminine : masculine)[i / 10] : adjectives[i / 10] + animals[i % 10]) + extra
    }
}
final class MPPreferences {
    let defaults: UserDefaults
    private let prefix = "modern.pong.v2."
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load<T: Decodable>(_ key: String, _ type: T.Type) -> T? { defaults.data(forKey: prefix + key).flatMap { try? JSONDecoder().decode(type, from: $0) } }
    func save<T: Encodable>(_ key: String, _ value: T) { defaults.set(try? JSONEncoder().encode(value), forKey: prefix + key) }
    var identity: MPIdentity? { get { load("identity", MPIdentity.self) } set { save("identity", newValue) } }
    /// Beginner / Standard / Pro. Beginner is the default without a saved choice (Android `controlDifficulty`, default 4);
    /// an earlier saved Standard/Pro choice keeps its meaning.
    var control: MPLevel {
        get {
            if let value = defaults.object(forKey: prefix + "control") as? Int { return MPLevel.control(value) }
            if defaults.object(forKey: prefix + "pro") != nil { return defaults.bool(forKey: prefix + "pro") ? .superHard : .easy }
            return .beginner
        }
        set { defaults.set(MPLevel.control(newValue.rawValue).rawValue, forKey: prefix + "control") }
    }
    var target: Int { get { let value = defaults.integer(forKey: prefix + "target"); return value == 0 ? 7 : value } set { defaults.set(newValue, forKey: prefix + "target") } }
    var skipGuide: Bool { get { defaults.bool(forKey: prefix + "skipGuide") } set { defaults.set(newValue, forKey: prefix + "skipGuide") } }
    var rooms: [MPSession] { get { load("rooms", [MPSession].self) ?? [] } set { save("rooms", newValue) } }
    /// Android PlayActivity `knockoutFormat`: the last chosen tournament format (Multi Ping Pong defaults to a knockout).
    var knockoutFormat: Bool {
        get { defaults.object(forKey: prefix + "knockoutFormat") == nil ? true : defaults.bool(forKey: prefix + "knockoutFormat") }
        set { defaults.set(newValue, forKey: prefix + "knockoutFormat") }
    }
    // Android PlayActivity (828c6fc) form choices: players per table per room kind (2, 3 or 4; default 4), the game type per
    // room kind, players going through from each knockout table (1 or 2; default 2) and the knockout size (default 8).
    func tableSize(_ kind: MPSessionKind) -> Int {
        let value = defaults.integer(forKey: prefix + "tableSize." + kind.rawValue)
        return (2...4).contains(value) ? value : 4
    }
    func setTableSize(_ kind: MPSessionKind, _ value: Int) { defaults.set(min(4, max(2, value)), forKey: prefix + "tableSize." + kind.rawValue) }
    func gameMode(_ kind: MPSessionKind) -> MPGameMode {
        MPGameMode(rawValue: defaults.string(forKey: prefix + "gameMode." + kind.rawValue) ?? "") ?? .winnerTakesAll
    }
    func setGameMode(_ kind: MPSessionKind, _ value: MPGameMode) { defaults.set(value.rawValue, forKey: prefix + "gameMode." + kind.rawValue) }
    var advance: Int {
        get { let value = defaults.integer(forKey: prefix + "advance"); return value == 1 ? 1 : 2 }
        set { defaults.set(min(2, max(1, newValue)), forKey: prefix + "advance") }
    }
    var knockoutPlayers: Int {
        get { let value = defaults.integer(forKey: prefix + "knockoutPlayers"); return (2...MPKnockout.maxPlayers).contains(value) ? value : 8 }
        set { defaults.set(min(MPKnockout.maxPlayers, max(2, newValue)), forKey: prefix + "knockoutPlayers") }
    }
    // Android CrossActivity `cross_local`: players at the local table (3/4, default 4), points to win (3/5/7, default 5), the
    // three house players, full screen (default on) and whether the cross guide was seen.
    var crossPlayers: Int {
        get { let value = defaults.integer(forKey: prefix + "cross.players"); return value == 3 ? 3 : 4 }
        set { defaults.set(newValue == 3 ? 3 : 4, forKey: prefix + "cross.players") }
    }
    var crossTarget: Int {
        get { let value = defaults.integer(forKey: prefix + "cross.target"); return [3, 5, 7].contains(value) ? value : 5 }
        set { defaults.set([3, 5, 7].contains(newValue) ? newValue : 5, forKey: prefix + "cross.target") }
    }
    var crossOpponents: [String] {
        get {
            let saved = (defaults.string(forKey: prefix + "cross.opponents") ?? "kyra,mia,minik").split(separator: ",").map(String.init)
            var result: [String] = []
            for id in saved where MPRoster.find(id) != nil && !result.contains(id) { result.append(id) }
            for player in MPRoster.all where !result.contains(player.id) { result.append(player.id) }
            return result
        }
        set { defaults.set(newValue.joined(separator: ","), forKey: prefix + "cross.opponents") }
    }
    var crossFullScreen: Bool {
        get { defaults.object(forKey: prefix + "cross.fullScreen") == nil ? true : defaults.bool(forKey: prefix + "cross.fullScreen") }
        set { defaults.set(newValue, forKey: prefix + "cross.fullScreen") }
    }
    var crossGuideSeen: Bool { get { defaults.bool(forKey: prefix + "cross.guideSeen") } set { defaults.set(newValue, forKey: prefix + "cross.guideSeen") } }
    func sequence(_ id: String) -> Int64 {
        let key = prefix + "sequence." + id, next = Int64(defaults.integer(forKey: key)) + 1
        defaults.set(next, forKey: key); return next
    }
    // Android RoomBook (2026-10): routine "news" notices (inactivity warnings, other players' results,
    // deletions) are retired and not resurfaced; failures use the screen's own error handling.
    // A completed room is never kept in "Your games / tournaments" history.
    private func flags(_ name: String) -> [String] { load(name, [String].self) ?? [] }
    private func flag(_ name: String, _ id: String) {
        var all = flags(name); guard !all.contains(id) else { return }
        all.append(id); save(name, Array(all.suffix(512)))
    }
    /// Android `RoomBook.completionKnown`.
    func completionKnown(_ s: MPSession) -> Bool { flags("completed").contains(s.id) }
    /// Android `RoomBook.remember`: an open room is listed; a completed one is marked and removed from the list.
    func remember(_ s: MPSession) {
        if s.complete { flag("completed", s.id); removed(s); return }
        guard !completionKnown(s) else { return }
        rooms = rooms.filter { $0.id != s.id } + [s]
    }
    /// Android `RoomBook.dismissResult`: "Done" (or Back) on a completed room.
    func dismissResult(_ s: MPSession) { flag("completed", s.id); removed(s) }
    /// Android `RoomBook.firstCelebration`: a completed room celebrates a win once.
    func firstCelebration(_ s: MPSession) -> Bool {
        if flags("celebrated").contains(s.id) { return false }
        flag("celebrated", s.id); return true
    }
    /// Android `RoomBook.forget` / `closed` / `deleted`: no notice is queued.
    func removed(_ s: MPSession) { rooms = rooms.filter { $0.id != s.id } }
}
