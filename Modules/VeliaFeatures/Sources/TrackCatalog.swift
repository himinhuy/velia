import Foundation

/// Trackable items shown on the Track sheet. Stored as `SymptomRecord`s keyed by (category, id).
/// SF Symbols stand in for the bespoke illustrations of the reference design.
struct TrackItem: Identifiable, Hashable {
    let id: String
    let labelVI: String
    let labelEN: String
    let symbol: String
    var color: TrackColor

    var label: String {
        L2(labelVI, labelEN)
    }
}

enum TrackColor { case rose, amber, blue, teal }

enum TrackCatalog {
    static let feelingCategory = "feeling"
    static let painCategory = "pain"
    static let energyCategory = "energy" // single-choice
    static let sleepCategory = "sleep" // single-choice
    static let sexCategory = "sex" // single-choice
    static let dischargeCategory = "discharge" // single-choice (general, non-conceive modes)

    static let feelings: [TrackItem] = [
        TrackItem(id: "happy", labelVI: "Vui vẻ", labelEN: "Happy", symbol: "sun.max.fill", color: .amber),
        TrackItem(id: "mood_swings", labelVI: "Thất thường", labelEN: "Mood swings", symbol: "tornado", color: .amber),
        TrackItem(id: "sad", labelVI: "Buồn", labelEN: "Sad", symbol: "cloud.rain.fill", color: .amber),
        TrackItem(id: "anxious", labelVI: "Lo âu", labelEN: "Anxious", symbol: "wind", color: .amber),
        TrackItem(id: "calm", labelVI: "Bình tĩnh", labelEN: "Calm", symbol: "leaf.fill", color: .amber),
        TrackItem(id: "irritable", labelVI: "Cáu gắt", labelEN: "Irritable", symbol: "flame.fill", color: .amber)
    ]

    static let pains: [TrackItem] = [
        TrackItem(id: "cramps", labelVI: "Đau bụng kinh", labelEN: "Cramps", symbol: "bolt.heart.fill", color: .blue),
        TrackItem(id: "headache", labelVI: "Đau đầu", labelEN: "Headache", symbol: "brain.head.profile", color: .blue),
        TrackItem(id: "back", labelVI: "Đau lưng", labelEN: "Back pain", symbol: "figure.walk", color: .blue),
        TrackItem(
            id: "tender_breasts",
            labelVI: "Căng tức ngực",
            labelEN: "Tender breasts",
            symbol: "heart.fill",
            color: .blue
        ),
        TrackItem(id: "nausea", labelVI: "Buồn nôn", labelEN: "Nausea", symbol: "face.dashed.fill", color: .blue),
        TrackItem(id: "fatigue", labelVI: "Mệt mỏi", labelEN: "Fatigue", symbol: "zzz", color: .blue)
    ]

    /// Single-choice: one energy level per day.
    static let energy: [TrackItem] = [
        TrackItem(id: "high", labelVI: "Tràn đầy", labelEN: "Energetic", symbol: "bolt.fill", color: .teal),
        TrackItem(id: "ok", labelVI: "Bình thường", labelEN: "Normal", symbol: "equal.circle.fill", color: .teal),
        TrackItem(id: "low", labelVI: "Uể oải", labelEN: "Low", symbol: "battery.25", color: .teal)
    ]

    /// Single-choice: sleep quality.
    static let sleep: [TrackItem] = [
        TrackItem(id: "good", labelVI: "Ngon giấc", labelEN: "Slept well", symbol: "moon.stars.fill", color: .blue),
        TrackItem(id: "ok", labelVI: "Tạm ổn", labelEN: "Okay", symbol: "moon.fill", color: .blue),
        TrackItem(id: "poor", labelVI: "Khó ngủ", labelEN: "Poor sleep", symbol: "moon.zzz.fill", color: .blue)
    ]

    /// Single-choice: intercourse (Tier-1 neutral).
    static let sex: [TrackItem] = [
        TrackItem(id: "protected", labelVI: "Có bảo vệ", labelEN: "Protected", symbol: "shield.fill", color: .rose),
        TrackItem(
            id: "unprotected",
            labelVI: "Không bảo vệ",
            labelEN: "Unprotected",
            symbol: "heart.fill",
            color: .rose
        )
    ]

    /// Single-choice: general discharge type (conceive mode uses the detailed cervical-mucus picker).
    static let discharge: [TrackItem] = [
        TrackItem(id: "dry", labelVI: "Khô", labelEN: "Dry", symbol: "circle", color: .teal),
        TrackItem(id: "sticky", labelVI: "Dính", labelEN: "Sticky", symbol: "circle.dotted", color: .teal),
        TrackItem(id: "creamy", labelVI: "Kem", labelEN: "Creamy", symbol: "drop.halffull", color: .teal),
        TrackItem(id: "eggwhite", labelVI: "Trong, dai", labelEN: "Egg-white", symbol: "drop.fill", color: .teal),
        TrackItem(id: "watery", labelVI: "Loãng", labelEN: "Watery", symbol: "drop", color: .teal),
        TrackItem(
            id: "unusual",
            labelVI: "Bất thường",
            labelEN: "Unusual",
            symbol: "exclamationmark.circle",
            color: .teal
        )
    ]
}
