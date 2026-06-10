import Foundation

/// Trackable items shown on the Track sheet. Stored as `SymptomRecord`s keyed by (category, id).
/// SF Symbols stand in for the bespoke illustrations of the reference design.
struct TrackItem: Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String
    var color: TrackColor
}

enum TrackColor { case rose, amber, blue, teal }

enum TrackCatalog {
    static let feelingCategory = "feeling"
    static let painCategory = "pain"

    static let feelings: [TrackItem] = [
        TrackItem(id: "happy", label: "Vui vẻ", symbol: "sun.max.fill", color: .amber),
        TrackItem(id: "mood_swings", label: "Thất thường", symbol: "tornado", color: .amber),
        TrackItem(id: "sad", label: "Buồn", symbol: "cloud.rain.fill", color: .amber),
        TrackItem(id: "anxious", label: "Lo âu", symbol: "wind", color: .amber),
        TrackItem(id: "calm", label: "Bình tĩnh", symbol: "leaf.fill", color: .amber),
        TrackItem(id: "irritable", label: "Cáu gắt", symbol: "flame.fill", color: .amber),
    ]

    static let pains: [TrackItem] = [
        TrackItem(id: "cramps", label: "Đau bụng kinh", symbol: "bolt.heart.fill", color: .blue),
        TrackItem(id: "headache", label: "Đau đầu", symbol: "brain.head.profile", color: .blue),
        TrackItem(id: "back", label: "Đau lưng", symbol: "figure.walk", color: .blue),
        TrackItem(id: "tender_breasts", label: "Căng tức ngực", symbol: "heart.fill", color: .blue),
        TrackItem(id: "nausea", label: "Buồn nôn", symbol: "face.dashed.fill", color: .blue),
        TrackItem(id: "fatigue", label: "Mệt mỏi", symbol: "zzz", color: .blue),
    ]
}
