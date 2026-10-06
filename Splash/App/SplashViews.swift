import SwiftUI
import UIKit

/// SwiftUI versions of the Android SplashActivity pages (LinearLayout columns in a ScrollView
/// over the lagoon art). Sizes are Android sp/dp as points.
private func tr(_ en: String, _ he: String) -> String { return AppText.t(en, he) }

@MainActor
struct SplashLabel: View {
    let text: String
    var size: CGFloat = 18
    var color: UInt32 = 0xffffffff

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(SplashPalette.color(color))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }
}

@MainActor
struct SplashButton: View {
    let title: String
    var color: UInt32 = 0xffb4f6e7
    var height: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SplashPalette.color(0xff0b2b42))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(RoundedRectangle(cornerRadius: 18).fill(SplashPalette.color(color)))
                .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
    }
}

/// Android `page(title)`: dark blue, the lagoon at 43% opacity, a scrolling padded column.
@MainActor
struct SplashPage<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            SplashPalette.color(0xff0b2941)
            GeometryReader { geo in
                if let lagoon = ArtStore.shared.lagoon {
                    Image(uiImage: lagoon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.43)
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    SplashLabel(text: title, size: 28)
                    content
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, AppText.rtl ? .rightToLeft : .leftToRight)
    }
}

/// Android Spinner with the "▾" marker at the end.
@MainActor
struct SplashDropdown: View {
    let title: String
    let items: [String]
    let selected: Int
    let change: (Int) -> Void

    var body: some View {
        let rtl = AppText.rtl
        VStack(spacing: 0) {
            SplashLabel(text: title, size: 17, color: 0xffb4f6e7)
            Menu {
                ForEach(Array(items.enumerated()), id: \.offset) { pair in
                    Button(pair.element) { change(pair.offset) }
                }
            } label: {
                ZStack(alignment: .trailing) {
                    Text(selected >= 0 && selected < items.count ? items[selected] : "")
                        .font(.system(size: 17))
                        .foregroundColor(SplashPalette.color(0xff10263c))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.leading, rtl ? 34 : 10)
                        .padding(.trailing, rtl ? 10 : 34)
                    Text("▾")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(SplashPalette.color(0xff10263c))
                        .frame(width: 36)
                }
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 18).fill(SplashPalette.color(0xffcaeaff)))
            }
            .padding(.bottom, 12)
        }
    }
}

struct SplashRootView: View {
    @StateObject private var controller = SplashController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SplashPalette.color(SplashPalette.sky).ignoresSafeArea()
            content
            ToastOverlay(controller: controller)
        }
        .preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onChange(of: scenePhase, initial: true) { _, phase in
            controller.scenePhaseChanged(active: phase == .active)
        }
        .alert(tr("Battle paused", "הקרב מושהה"), isPresented: $controller.pausePresented) {
            Button(tr("Continue", "להמשיך")) { controller.continueFromPause() }
            Button(tr("Return to menu", "חזרה לתפריט")) { controller.returnFromPause() }
        }
        .alert(tr("For a grown-up", "למבוגר אחראי"), isPresented: gateBinding) {
            TextField("", text: $controller.gateAnswer)
                .keyboardType(.numberPad)
            if let model = controller.gate {
                Button(tr("Continue", "המשך")) { controller.confirmGate(model) }
            }
            Button(tr("Cancel", "ביטול"), role: .cancel) { controller.cancelGate() }
        } message: {
            if let model = controller.gate {
                Text("\(model.a) × \(model.b) = ?")
            }
        }
    }

    @MainActor private var gateBinding: Binding<Bool> {
        Binding(get: { controller.gate != nil }, set: { shown in
            if !shown { controller.gate = nil }
        })
    }

    @MainActor @ViewBuilder private var content: some View {
        switch controller.screen {
        case .game:
            if let arena = controller.gameView {
                ArenaHost(arena: arena)
                    .id(ObjectIdentifier(arena))
                    .defersSystemGestures(on: .all)
            }
        case .home: HomePage(controller: controller)
        case .settings: SettingsPage(controller: controller)
        case .parentZone: ParentZonePage(controller: controller)
        case .progress: ProgressPage(controller: controller)
        case .online: OnlinePage(controller: controller)
        case .lobby: LobbyPage(controller: controller)
        case .results: ResultsPage(controller: controller)
        }
    }
}

@MainActor
struct ArenaHost: UIViewRepresentable {
    let arena: SplashArenaView

    func makeUIView(context: Context) -> SplashArenaView { return arena }
    func updateUIView(_ uiView: SplashArenaView, context: Context) {}
}

@MainActor
struct ToastOverlay: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        VStack {
            Spacer()
            if let toast = controller.toast {
                Text(toast.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(white: 0.2).opacity(0.92)))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 64)
                    .transition(.opacity)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: toast.long ? 3_500_000_000 : 2_000_000_000)
                        await MainActor.run {
                            if controller.toast?.id == toast.id { controller.toast = nil }
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: controller.toast)
    }
}

// MARK: Home

@MainActor
struct HomePage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        SplashPage("MINIK SPLASH") {
            if let logo = ArtStore.shared.logo {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 132)
                    .frame(maxWidth: .infinity)
            }
            SplashLabel(text: tr("Think. Move. Make a splash.", "חושבים. זזים. מתיזים."), size: 18, color: 0xff9cfff1)
            if controller.hasSavedBattle {
                SplashButton(title: tr("Continue your battle", "להמשיך בקרב")) { controller.continueBattle() }
            }
            if controller.hasSavedCup {
                SplashButton(title: tr("Continue your cup", "להמשיך בגביע")) { controller.continueCup() }
            }
            SplashButton(title: tr("Play", "לשחק")) { controller.startGame(false) }
            SplashButton(title: tr("Learn with Minik", "ללמוד עם מיניק")) { controller.startGame(true) }
            SplashButton(title: tr("Local cup · 3 battles", "גביע מקומי · 3 קרבות"), color: 0xffafdbff) { controller.startLocalCup() }
            SplashButton(title: tr("Play with friends", "לשחק עם חברים"), color: 0xffafdbff) { controller.openOnline() }
            SplashLabel(text: Characters.get(controller.selected).name(controller.hebrew), size: 17)
            HStack(spacing: 0) {
                SplashButton(title: "‹", color: 0xffdac8ff, height: 50) { controller.nextCharacter(-1) }
                    .frame(width: 54)
                Group {
                    if let portrait = ArtStore.shared.portrait(controller.selected) {
                        Image(uiImage: portrait)
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel(Characters.get(controller.selected).name(controller.hebrew))
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                SplashButton(title: "›", color: 0xffdac8ff, height: 50) { controller.nextCharacter(1) }
                    .frame(width: 54)
            }
            SplashButton(title: tr("Settings", "הגדרות"), color: 0xffd1c4ff) { controller.openSettings() }
            SplashButton(title: tr("Parent zone", "אזור הורים"), color: 0xfffce8ac) {
                let owner = controller
                owner.requestParentGate { [weak owner] in owner?.openParentZone() }
            }
            SplashLabel(text: tr("Questions and answers were created with AI. AI can make mistakes.", "השאלות והתשובות נוצרו בעזרת בינה מלאכותית, שעלולה לטעות."), size: 14)
        }
    }
}

// MARK: Settings

@MainActor
struct SettingsPage: View {
    @ObservedObject var controller: SplashController

    private func title(_ t: Topic) -> String {
        switch t {
        case .math: return tr("Math", "חשבון")
        case .english: return tr("English", "אנגלית")
        case .world, .mixed: return tr("World knowledge", "ידע כללי")
        }
    }

    var body: some View {
        let s = controller.settings
        SplashPage(tr("Settings", "הגדרות")) {
            SplashLabel(text: tr("Choose what feels right. Your choices are saved.", "בחרו מה מתאים לכם. הבחירות נשמרות."), size: 16)
            SplashDropdown(title: tr("Walking", "הליכה"),
                           items: [tr("Easy · tap a balloon to walk and collect", "קלה · געו בבלון להליכה ולאיסוף"),
                                   tr("Standard · move, then tap to collect", "רגילה · התקרבו ואז געו לאיסוף")],
                           selected: s.walk.ordinal) { controller.setWalk($0) }
            SplashDropdown(title: tr("Throwing", "זריקה"),
                           items: [tr("Easy · tap an opponent to throw", "קלה · געו ביריב כדי לזרוק"),
                                   tr("Standard · aim and tap the arc", "רגילה · כוונו וגעו בקשת")],
                           selected: s.throwing.ordinal) { controller.setThrowing($0) }
            SplashDropdown(title: tr("Battle format", "סוג הקרב"),
                           items: [tr("Everyone for themselves", "כולם מול כולם"), "2 × 2", "3 × 3"],
                           selected: controller.format) { controller.setFormat($0) }
            SplashDropdown(title: tr("Players in a solo battle", "שחקנים בקרב אישי"),
                           items: (2...6).map { String($0) },
                           selected: controller.count - 2) { controller.setCount($0 + 2) }
            SplashDropdown(title: tr("Arena", "זירה"),
                           items: [tr("Beach", "חוף"), tr("Park", "פארק"), tr("Andromeda · low gravity", "אנדרומדה · כבידה נמוכה")],
                           selected: s.arena.ordinal) { controller.setArena($0) }
            SplashLabel(text: tr("Andromeda: higher jumps, floating steps and rising throws.", "באנדרומדה: קפיצות גבוהות, צעדים מרחפים וזריקות גבוהות יותר."), size: 14)
            SplashDropdown(title: tr("Court", "מגרש"),
                           items: [tr("With court", "עם מגרש"), tr("Open space · no walls", "מרחב פתוח · ללא קירות")],
                           selected: s.court ? 0 : 1) { controller.setCourt($0) }
            SplashDropdown(title: tr("Answer balloons", "בלוני תשובות"),
                           items: [tr("One place", "במקום אחד"), tr("All over", "בכל הזירה")],
                           selected: s.balloons.ordinal) { controller.setBalloons($0) }
            SplashButton(title: tr("Back", "חזרה")) { controller.home() }
            // Subjects are intentionally the last setting: expandable, with tap/drag transfer lists.
            SplashButton(title: tr("Subjects ▾", "נושאים ▾"), color: 0xffe2d4ff) { controller.subjectsExpanded.toggle() }
            if controller.subjectsExpanded {
                SplashLabel(text: tr("Tap a subject or drag it between lists. Keep at least one.", "געו בנושא או גררו בין הרשימות. יש להשאיר לפחות נושא אחד."), size: 14)
                HStack(alignment: .top, spacing: 0) {
                    subjectList(chosen: false)
                    subjectList(chosen: true)
                }
            }
        }
    }

    private func subjectList(chosen: Bool) -> some View {
        let topics = Topic.allCases.filter { $0 != .mixed && controller.settings.subjects.contains($0) == chosen }
        return VStack(spacing: 0) {
            SplashLabel(text: chosen ? tr("Chosen subjects", "נושאים שנבחרו") : tr("Available subjects", "נושאים זמינים"), size: 15)
            ForEach(topics, id: \.self) { t in
                SplashButton(title: title(t), color: chosen ? 0xffb4f6e7 : 0xffd6e8ff) { controller.tapSubject(t, chosen: chosen) }
                    .draggable(t.rawValue)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18).fill(SplashPalette.color(chosen ? 0xff214f60 : 0xff233e59)))
        .dropDestination(for: String.self) { items, _ in
            for raw in items {
                if let topic = Topic(rawValue: raw) { controller.dropSubject(topic, intoChosen: chosen) }
            }
            return true
        }
        .padding(.horizontal, 3)
    }
}

// MARK: Parent zone and progress

@MainActor
struct ParentZonePage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        SplashPage(tr("Parent zone", "אזור הורים")) {
            SplashLabel(text: tr("Learning and purchases, in one place.", "למידה ורכישות, במקום אחד."), size: 17)
            SplashButton(title: tr("My learning progress", "התקדמות בלמידה")) { controller.openProgress() }
            // "Ads & purchases" (remove ads, restore, codes) is not offered on iOS yet.
            SplashButton(title: tr("Back", "חזרה")) { controller.home() }
        }
    }
}

@MainActor
struct ProgressPage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        let profile = controller.learningProfile()
        let names = controller.hebrew
            ? ["חיבור", "חיסור", "כפל", "חילוק", "סדר פעולות", "שברים", "אנגלית", "ידע כללי"]
            : ["Addition", "Subtraction", "Multiplication", "Division", "Order of operations", "Fractions", "English", "World"]
        SplashPage(tr("Growing skills", "מיומנויות מתפתחות")) {
            ForEach(Skill.allCases, id: \.self) { skill in
                let s = profile.state(skill)
                let first = AppText.t(names[skill.ordinal]) + " · \(s.level + 1)\n"
                let second = tr("Independent: \(s.independent) · With help: \(s.assisted)", "עצמאיות: \(s.independent) · עם עזרה: \(s.assisted)")
                SplashLabel(text: first + second, size: 15)
            }
            SplashButton(title: tr("Back", "חזרה")) { controller.openParentZone() }
        }
    }
}

// MARK: Online

@MainActor
struct OnlinePage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        SplashPage(tr("Play with friends", "לשחק עם חברים")) {
            SplashLabel(text: tr("Private room · up to six players\nHouse players can fill empty places.", "חדר פרטי · עד שישה שחקנים\nשחקני הבית יכולים להשלים מקומות פנויים."), size: 16)
            #if DEBUG
            SplashLabel(text: tr("This development build connects only to a local Firebase test server. Production is not activated.", "גרסת הפיתוח מתחברת רק לשרת בדיקות מקומי של Firebase. הייצור אינו מופעל."), size: 13)
            field("Local test server host", text: $controller.emulatorHost)
            #endif
            field(tr("Room code", "קוד חדר"), text: $controller.roomCode)
            SplashButton(title: tr("Create room", "יצירת חדר")) { controller.createRoom() }
            SplashButton(title: tr("Create a three-round cup", "יצירת גביע של שלושה סיבובים"), color: 0xffdbc7ff) { controller.createCupRoom() }
            SplashButton(title: tr("Join room", "הצטרפות לחדר"), color: 0xffb8dcff) { controller.joinRoom() }
            if let saved = controller.savedRoom {
                SplashButton(title: tr("Return to \(saved)", "חזרה לחדר \(saved)")) { controller.returnToRoom(saved) }
            }
            SplashButton(title: tr("Back", "חזרה")) { controller.home() }
        }
    }

    private func field(_ hint: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(hint).foregroundColor(SplashPalette.color(0xffbad8e8)))
            .font(.system(size: 18))
            .foregroundColor(.white)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .overlay(Rectangle().frame(height: 1).foregroundColor(SplashPalette.color(0xffbad8e8)), alignment: .bottom)
            .padding(.vertical, 4)
    }
}

@MainActor
struct LobbyPage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        let model = controller.lobbyModel
        SplashPage(tr("Splash room", "חדר Splash")) {
            if let model = model {
                SplashButton(title: model.code, color: 0xfff9e59e) { controller.copyCode(model.code) }
                ForEach(Array(model.players.enumerated()), id: \.offset) { pair in
                    SplashLabel(text: pair.element, size: 17)
                }
            }
            SplashButton(title: tr("Ready", "מוכנים")) { controller.lobbyMarkReady() }
            SplashButton(title: tr("Start with house players", "להתחיל עם שחקני הבית"), color: 0xffc0dfff) { controller.lobbyStartGame() }
            SplashButton(title: tr("Leave", "יציאה"), color: 0xffe7cdff) { controller.home() }
        }
    }
}

// MARK: Results

@MainActor
struct ResultsPage: View {
    @ObservedObject var controller: SplashController

    var body: some View {
        if let model = controller.results {
            SplashPage(model.title) {
                SplashLabel(text: tr("Battle complete", "הקרב הסתיים"), size: 20, color: 0xff91fff0)
                ForEach(model.teams) { panel in
                    VStack(spacing: 0) {
                        SplashLabel(text: panel.name, size: 23, color: panel.ink)
                        SplashLabel(text: panel.subtitle, size: 20, color: panel.ink)
                        ForEach(panel.rows) { row in PlayerRow(row: row) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18).fill(SplashPalette.color(panel.color)))
                    .padding(.vertical, 8)
                }
                ForEach(model.rows) { row in PlayerRow(row: row) }
                if let note = model.teamNote { SplashLabel(text: note, size: 14) }
                SplashLabel(text: model.correctLine, size: 15)
                SplashLabel(text: model.countsLine, size: 13)
                if model.onlineCup { SplashLabel(text: controller.standings, size: 16) }
                if model.nextRound {
                    SplashButton(title: tr("Next round", "הסיבוב הבא")) { controller.resultsNextRound() }
                }
                if let cupLine = model.cupLine { SplashLabel(text: cupLine) }
                if let standings = model.cupStandings { SplashLabel(text: standings, size: 15) }
                if model.nextBattle {
                    SplashButton(title: tr("Next battle", "הקרב הבא")) { controller.resultsNextBattle() }
                }
                if model.playAgain {
                    SplashButton(title: tr("Play again", "לשחק שוב")) { controller.resultsPlayAgain() }
                }
                SplashButton(title: tr("Main menu", "תפריט ראשי"), color: 0xffc6dfff) { controller.home() }
            }
        } else {
            SplashPage("") {
                SplashButton(title: tr("Main menu", "תפריט ראשי"), color: 0xffc6dfff) { controller.home() }
            }
        }
    }
}

@MainActor
struct PlayerRow: View {
    let row: ResultPlayerRow

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let portrait = ArtStore.shared.portrait(row.character) {
                    Image(uiImage: portrait).resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 46, height: 58)
            SplashLabel(text: row.name, size: 17, color: row.ink)
            Text("\(row.score)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(SplashPalette.color(row.ink))
                .frame(width: 46)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 18).fill(SplashPalette.color(0x44214760)))
        .padding(.vertical, 3)
    }
}
