import Foundation

/// Android ModernTutorial order: three serves, the Beginner automatic return, then five tap/aim returns.
enum MPTutorialStep: Int, CaseIterable {
    case serveMiddle, serveLeft, serveRight, autoReturn, middleAny, middleRight, leftMiddle, leftLeft, rightLeft
    var serve: Bool { rawValue < 3 }
    /// The automatic-return lesson runs on Beginner; every other lesson uses Android's EASY court (iOS `.medium`).
    var level: MPLevel { self == .autoReturn ? .beginner : .medium }
    var incoming: Double? { switch self { case .middleAny, .middleRight: return 0; case .autoReturn, .leftMiddle, .leftLeft: return -1; case .rightLeft: return 1; default: return nil } }
    var target: MPZone? { switch self { case .serveMiddle, .leftMiddle: return .middle; case .serveLeft, .leftLeft, .rightLeft: return .left; case .serveRight, .middleRight: return .right; case .middleAny, .autoReturn: return nil } }
    var aim: Double { switch self { case .serveLeft, .leftLeft, .rightLeft: return -1; case .serveRight, .middleRight: return 1; case .leftMiddle: return 0.025 / 0.085; default: return 0 } }
    var exercise: MPExercise { .init(serve: serve, incoming: incoming, expected: target) }
    /// Android `TutorialLesson.swipeDirection`: the aimed returns' demonstrated swipe direction.
    var swipeDirection: Double? { switch self { case .middleRight, .leftMiddle: return 1; case .leftLeft, .rightLeft: return -1; default: return nil } }
    /// Android `ModernTutorial.demonstrate`: sideways distance of the demonstrated aiming swipe.
    var demoDistance: Double { switch self { case .leftLeft: return 0.013; case .rightLeft: return 0.13; case .leftMiddle: return 0.055; default: return 0.065 } }
    var servePoint: MPPoint { switch self { case .serveLeft: return .init(0.16, 0.22); case .serveRight: return .init(0.84, 0.22); default: return .init(0.5, 0.85) } }
    func title(_ he: Bool) -> String {
        let en = ["Serve: try a tap", "Serve to the left", "Serve to the right", "Move into place. We time the hit!", "Return with a tap", "Aim from the middle to a side", "Return from a side to the middle", "Return to the same side", "Return to the opposite side"]
        let heb = ["הגשה: נסו נגיעה", "הגישו לשמאל", "הגישו לימין", "מזיזים והמחבט חובט", "החזירו בנגיעה", "כוונו מהאמצע לצד", "החזירו מהצד לאמצע", "החזירו לאותו הצד", "החזירו לצד הנגדי"]
        return (he ? heb : en)[rawValue]
    }
    func instruction(_ he: Bool) -> String {
        let en = [
            "Tap any point on the table to aim your serve there. First, tap the middle of your side of the table to get a feel for serving. The ball bounces on your side, then Minik’s side.",
            "Tap the left third of Minik’s side of the table. Your serve must land on that side. Left and right are as you see them on the screen.",
            "Now tap the right third of Minik’s side of the table. Watch the diagonal serve and where it lands.",
            "Beginner is the default. Drag your paddle into the incoming ball’s path on your side. You can position it early and lift your finger: it stays there and hits at the right time. Move left to meet this ball.",
            "Minik sends a gentle ball to the middle. Tap when it reaches your paddle. You can return anywhere. A plain tap keeps the ball’s natural sideways direction.",
            "Minik sends to the middle again. While hitting, swipe diagonally forward and right. Aim for the right third of Minik’s side. A tiny sideways movement is not enough.",
            "Minik sends to your left. Swipe gently forward and right to bring the return to the middle third. Adjust your diagonal direction to choose where it lands.",
            "Minik sends left again. Swipe diagonally forward and left. Land the return in the left third, on the same side of the screen.",
            "Minik sends to your right. Swipe diagonally forward and left to cross the table and land in the left third. Standard is forgiving; Pro uses the same idea with precise timing, direction and power."
        ]
        let heb = [
            "געו בכל נקודה בשולחן כדי לכוון אליה את ההגשה. תחילה, געו באמצע הצד שלכם בשולחן כדי להרגיש את ההגשה. הכדור קופץ בצד שלכם ואז בצד של מיניק.",
            "געו בשליש השמאלי בצד של מיניק בשולחן. ההגשה צריכה לנחות שם. שמאל וימין הם כפי שרואים אותם על המסך.",
            "עכשיו געו בשליש הימני בצד של מיניק בשולחן. שימו לב להגשה האלכסונית ולמקום שבו הכדור נוחת.",
            "ברמת מתחילים מספיק להציב את המחבט בדרך של הכדור בצד שלכם. אפשר לגרור אותו מראש ולהרים את האצבע — הוא יישאר במקום ויחבוט בזמן הנכון. נסו להזיז אותו שמאלה לקראת הכדור.",
            "מיניק שולח כדור קל לאמצע. געו כשהכדור מגיע למחבט שלכם. אפשר להחזיר לכל מקום. נגיעה פשוטה שומרת על כיוון התנועה הטבעי לצדדים.",
            "מיניק שוב שולח לאמצע. בזמן המכה החליקו באלכסון קדימה וימינה. כוונו לשליש הימני בצד של מיניק. תנועה קטנה מדי הצדה אינה מספיקה.",
            "מיניק שולח לשמאל שלכם. החליקו בעדינות קדימה וימינה כדי להחזיר לשליש האמצעי. זווית ההחלקה קובעת לאן הכדור יגיע.",
            "מיניק שוב שולח לשמאל. החליקו באלכסון קדימה ושמאלה כדי להחזיר לשליש השמאלי, באותו צד של המסך.",
            "מיניק שולח לימין שלכם. החליקו באלכסון קדימה ושמאלה כדי לחצות את השולחן ולנחות בשליש השמאלי. שליטה רגילה סלחנית; שליטת מקצוענים דורשת דיוק בתזמון, בכיוון ובעוצמה."
        ]; return (he ? heb : en)[rawValue]
    }
}
enum MPTutorialPhase { case explanation, demonstration, attempt, feedback }
