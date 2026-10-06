import SwiftUI

/// Android `home()`.
struct HomeScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AmuduPage(GameText.title(), background: model.art.scene(model.scene)) {
            nameSection
            avatarRow
            AmuduLabel(model.tr("Your avatar", "הדמות שלכם"), size: 16)
            menuButtons
        }
        .alert(model.tr("Join a private room", "הצטרפות לחדר פרטי"), isPresented: $model.joinVisible) {
            TextField(model.tr("Six-character code", "קוד בן שישה תווים"), text: $model.joinInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button(model.tr("Join", "הצטרפות")) { model.join() }
            Button(model.tr("Cancel", "ביטול"), role: .cancel) {}
        }
    }

    private var nameSection: some View {
        VStack(spacing: 0) {
            Image(uiImage: model.art.ball(.neon))
                .resizable()
                .scaledToFit()
                .frame(height: 110)
                .frame(maxWidth: .infinity)
            AmuduLabel(model.tr("Call. Catch. Freeze. Laugh.", "קוראים. תופסים. עוצרים. צוחקים."), size: 18, color: 0xff9bffe4)
            AmuduLabel(model.tr("Your name", "השם שלכם"), size: 18, color: 0xffb8f3dc)
            TextField("", text: Binding(get: { model.playerName }, set: { model.updateName($0) }),
                      prompt: Text(model.tr("Your name", "השם שלכם")).foregroundColor(Color(argb: 0xffbbd6de)))
                .font(.system(size: 18))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: 55)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(argb: 0x55335167)))
            Rectangle()
                .fill(Color(argb: 0xffa8f7df))
                .frame(height: 3)
            AmuduLabel(model.tr("Used only when you play with friends in a private room.", "ישמש רק במשחק עם חברים בחדר פרטי."), size: 14, color: 0xffc4dfe8)
        }
    }

    private var menuButtons: some View {
        VStack(spacing: 0) {
            AmuduButton(model.tr("Create game", "יצירת משחק"), color: 0xffb7dcff) { model.openSetup() }
            AmuduButton(model.tr("Join by code", "הצטרפות עם קוד"), color: 0xffb7dcff) { model.requestJoin() }
            if let code = model.savedRoom {
                AmuduButton(model.tr("Return to room (\(code))", "חזרה לחדר (\(code))"), color: 0xffdfcfff) { model.returnToRoom(code) }
            }
            if model.hasSavedGame {
                AmuduButton(model.tr("Continue saved game", "המשך משחק שמור"), color: 0xffdfcfff) { model.continueSaved() }
            }
            AmuduButton(model.tr("How to play", "איך משחקים")) { model.openHelp() }
        }
    }

    /// The avatar row stays left-to-right in every language (Android forces LTR here).
    private var avatarRow: some View {
        HStack(spacing: 0) {
            AvatarArrow(right: false) { model.shiftAvatar(-1) }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            Image(uiImage: model.art.portrait(model.avatar))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 126)
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > 35 && abs(dx) > abs(dy) { model.shiftAvatar(dx < 0 ? 1 : -1) }
                })
            AvatarArrow(right: true) { model.shiftAvatar(1) }
                .padding(.leading, 12)
                .padding(.trailing, 8)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Android `setup()`: arena, ball, time of day, players, SPUD rule, throw mode, wind, turn limit, house players.
struct SetupScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AmuduPage(model.tr("Create your game", "יוצרים משחק"), background: model.art.scene(model.scene)) {
            arenaChoices
            ruleChoices
            AmuduLabel(model.tr("House players · choose your team of friends", "שחקני הבית · בוחרים עם מי לשחק"), size: 17)
            ForEach(AmuduCharacters.all, id: \.id) { c in
                characterRow(c)
            }
            AmuduButton(model.tr("Start", "התחלה")) { model.startLocal() }
            AmuduButton(model.tr("Open private room", "פתיחת חדר פרטי"), color: 0xffb7dcff) { model.openPrivateRoom() }
            AmuduButton(model.tr("Back", "חזרה"), color: 0xffdfcfff) { model.home() }
        }
    }

    private var arenaChoices: some View {
        VStack(spacing: 0) {
            ChoiceMenu(title: model.tr("Arena", "זירה"), items: ArenaScene.allCases.map { model.tr($0.en, $0.he) },
                       selected: ArenaScene.allCases.firstIndex(of: model.scene) ?? 0) { i in
                model.scene = ArenaScene.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Ball", "כדור"), items: BallKind.allCases.map { model.tr($0.en, $0.he) },
                       selected: BallKind.allCases.firstIndex(of: model.ball) ?? 0) { i in
                model.ball = BallKind.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Time of day", "שעה ביום"), items: Daylight.allCases.map { model.tr($0.en, $0.he) },
                       selected: Daylight.allCases.firstIndex(of: model.daylight) ?? 0) { i in
                model.daylight = Daylight.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Number of players", "מספר שחקנים"), items: (2...10).map { String($0) },
                       selected: model.count - 2) { i in
                model.count = i + 2
                model.persist()
            }
        }
    }

    private var ruleChoices: some View {
        VStack(spacing: 0) {
            ChoiceMenu(title: model.tr("When SPUD is called", "כשקוראים עמודו"),
                       items: [model.tr("Freeze in place", "עוצרים במקום"), model.tr("Honor rule · moving adds a penalty", "חוק הכבוד · זזים ומקבלים נקודת חובה")],
                       selected: FreezeRule.allCases.firstIndex(of: model.freeze) ?? 0) { i in
                model.freeze = FreezeRule.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Throw mode", "מצב זריקה"), items: ThrowMode.allCases.map { model.tr($0.en, $0.he) },
                       selected: ThrowMode.allCases.firstIndex(of: model.throwMode) ?? 0) { i in
                model.throwMode = ThrowMode.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Wind", "רוח"), items: Wind.allCases.map { model.tr($0.en, $0.he) },
                       selected: Wind.allCases.firstIndex(of: model.wind) ?? 0) { i in
                model.wind = Wind.allCases[i]
                model.persist()
            }
            ChoiceMenu(title: model.tr("Turn limit", "תורים במשחק"), items: ["10", "20", "35", "50", model.tr("No limit", "ללא")],
                       selected: AppModel.turnChoices.firstIndex(of: model.turns) ?? 4) { i in
                model.turns = AppModel.turnChoices[i]
                model.persist()
            }
        }
    }

    private func characterRow(_ c: AmuduCharacter) -> some View {
        let isAvatar = c.id == model.avatar
        let title = c.name(hebrew: model.hebrew) + (isAvatar ? model.tr(" · Your avatar", " · הדמות שלכם") : "")
        let q = c.qualities
        let ratings: [(String, Int)] = [(model.tr("Accuracy", "דיוק"), q.accuracy), (model.tr("Power", "עוצמה"), q.power),
                                        (model.tr("Speed", "מהירות"), q.speed), (model.tr("Catch", "תפיסה"), q.catching)]
        return HStack(alignment: .center, spacing: 0) {
            Image(uiImage: model.art.portrait(c.id))
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 78)
            VStack(spacing: 0) {
                HouseCheck(title: title, checked: model.house.contains(c.id), enabled: !isAvatar) { selected in
                    model.setHouse(c.id, selected)
                }
                ForEach(0..<ratings.count, id: \.self) { i in
                    HStack(spacing: 0) {
                        Text(ratings[i].0)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(argb: 0xffffe49a))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SkillStars(value: ratings[i].1)
                            .frame(width: 116, height: 29)
                    }
                }
            }
        }
        .padding(.vertical, 7)
    }
}

/// Android `help()`.
struct HelpScreen: View {
    @ObservedObject var model: AppModel

    static let english = [
        "1 · Choose and toss",
        "Start in a circle. Tap a player, then swipe upward from your held ball. Faster means higher; the ball travels toward the circle center. Names are spoken aloud. After a successful catch, everyone stays where they are: call someone even far away.",
        "2 · Run and catch",
        "Drag and hold to run; lift to stop. Tap or briefly hold to prepare a catch for 0.7 seconds. Your character raises their hands and stops moving. Be close to the descending ball. After the attempt ends you can move again. Double-tap to duck.",
        "3 · Pick up, then choose",
        "After missing the airborne catch, get close and tap to pick up the ball. Your feet stay planted there. You may aim and throw immediately, or tap SPUD to stop the runners first. SPUD is only spoken when chosen.",
        "4 · Control the throw",
        "Tap a player to aim, then swipe from your ball. Standard: too slow drops short; too fast can fly over their head. The ball must not touch the ground first. Easy: lower throws and ground bounces are allowed. Wind changes the flight.",
        "5 · Catch or be tagged",
        "A timed catch gives the thrower a penalty. A hit gives the target a penalty and the ball rebounds; touching a player never becomes an automatic catch. A miss penalizes the thrower. Runners have a harder catch. Only a penalty returns everyone to the circle.",
        "6 · Remember the new name",
        "Every three penalties the other players privately choose one funny word. The first replaces the original name; later words are added. Write your own word or use a suggestion. When you are the only human, your proposal wins. Type the nickname to call that player; a wrong nickname earns a penalty. No one is eliminated.",
        "No turn limit is the default. You can finish from the pause menu; in a private room its host can finish. A chosen 10, 20, 35 or 50-turn limit ends automatically. Fewest penalties wins. No ads interrupt a turn.",
    ]

    static let hebrew = [
        "1 · בוחרים ומעיפים",
        "מתחילים במעגל. געו בשחקן והחליקו כלפי מעלה מהכדור שביד. מהר יותר פירושו גבוה יותר; הכדור נזרק למרכז המעגל. השם נקרא בקול. אחרי תפיסה מוצלחת כולם נשארים במקומם: אפשר לקרוא גם למי שרחוק.",
        "2 · רצים ותופסים",
        "גררו והחזיקו כדי לרוץ; הרימו כדי לעצור. נגיעה או לחיצה קצרה מכינות תפיסה למשך 0.7 שניות. הדמות מרימה ידיים ועוצרת. התקרבו לכדור היורד. בתום הניסיון אפשר שוב לזוז. נגיעה כפולה כדי להתכופף.",
        "3 · אוספים ובוחרים",
        "אחרי החטאת התפיסה, התקרבו וגעו כדי לאסוף. הרגליים נשארות במקום האיסוף. אפשר לכוון ולזרוק מיד, או ללחוץ עמודו כדי לעצור קודם את הרצים. הקריאה מושמעת רק כשלוחצים.",
        "4 · שולטים בזריקה",
        "געו בשחקן כדי לכוון והחליקו מהכדור. במצב רגיל: לאט מדי ייפול קרוב, ומהר מדי עלול לעבור מעל הראש. אסור שהכדור יפגע קודם בקרקע. במצב קל הזריקה נמוכה ומותרת קפיצה מהקרקע. הרוח משנה את המסלול.",
        "5 · תפיסה או פגיעה",
        "תפיסה בתזמון נכון נותנת נקודת חובה לזורק. פגיעה נותנת נקודה לנפגע והכדור ניתז ממנו; מגע בדמות אינו תפיסה אוטומטית. החטאה נותנת נקודה לזורק. קשה יותר לתפוס בזמן ריצה. חוזרים למעגל רק אחרי נקודת חובה.",
        "6 · זוכרים שם חדש",
        "בכל שלוש נקודות חובה האחרים בוחרים בסוד מילה מצחיקה אחת. הראשונה מחליפה את השם המקורי; בהמשך מוסיפים מילים. אפשר לכתוב מילה משלכם או לבחור הצעה. כשאתם היחידים שאינם שחקני בית, ההצעה שלכם נבחרת. מקלידים את הכינוי כדי לקרוא לשחקן; כינוי שגוי מוסיף נקודת חובה. אף אחד לא יוצא מהמשחק.",
        "ברירת המחדל היא ללא הגבלת תורים. אפשר לסיים מתפריט ההשהיה; בחדר פרטי המארח יכול לסיים. הגבלה של 10, 20, 35 או 50 תורים מסיימת אוטומטית. מנצחים עם הכי מעט נקודות חובה. אין פרסומות באמצע תור.",
    ]

    var body: some View {
        let texts = model.hebrew ? HelpScreen.hebrew : HelpScreen.english
        return AmuduPage(model.tr("How to play", "איך משחקים"), background: model.art.scene(model.scene)) {
            ForEach(0..<texts.count, id: \.self) { i in
                AmuduLabel(AppText.t(texts[i]), size: (i % 2 == 0 && i < 12) ? 20 : 16)
            }
            AmuduButton(model.tr("Back", "חזרה")) { model.home() }
        }
    }
}

/// Android `openRoom()` connecting page.
struct ConnectingScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AmuduPage(model.tr("Connecting…", "מתחברים…"), background: model.art.scene(model.scene)) {
            AmuduLabel(model.connectingInfo)
            AmuduButton(model.tr("Back", "חזרה")) { model.home() }
        }
    }
}

/// Android `lobby()`.
struct LobbyScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AmuduPage(model.tr("Your private game", "המשחק הפרטי שלכם"), background: model.art.scene(model.scene)) {
            if let state = model.lobbyState {
                AmuduLabel(state.code, size: 32, color: 0xffa2fff1)
                AmuduButton(model.tr("Copy code", "העתקת הקוד"), color: 0xffc4e5ff) { model.copyCode(state.code) }
                ForEach(state.lines) { line in
                    AmuduLabel(line.text, size: 18)
                }
                AmuduButton(model.tr("Ready", "מוכנים")) { state.onReady() }
                if state.host {
                    AmuduButton(model.tr("Start", "התחלה"), color: 0xffc4e5ff) { state.onStart() }
                }
                AmuduLabel(model.tr("Friends join by code. At least two players are needed; empty places can stay empty.", "חברים מצטרפים עם הקוד. צריך לפחות שני שחקנים; מקומות ריקים יכולים להישאר ריקים."), size: 14)
            }
            AmuduButton(model.tr("Back", "חזרה"), color: 0xffe2d3ff) { model.home() }
        }
    }
}

/// Android `result()`.
struct ResultScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AmuduPage(model.tr("What a game!", "איזה משחק!"), background: model.art.scene(model.scene)) {
            AmuduLabel(model.tr("Fewest penalties wins", "מנצחים עם הכי מעט נקודות חובה"), size: 18, color: 0xffacffe7)
            ForEach(model.results) { row in
                HStack(spacing: 0) {
                    Image(uiImage: model.art.portrait(row.character))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 55, height: 65)
                    AmuduLabel(row.name, size: 16)
                    AmuduLabel(String(row.penalties), size: 22, color: 0xffffe487)
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(minHeight: 75)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(argb: row.winner ? 0xb53c7b75 : 0xa51b3e59)))
                .padding(.vertical, 5)
            }
            AmuduButton(model.tr("Main menu", "תפריט ראשי")) { model.home() }
        }
    }
}
