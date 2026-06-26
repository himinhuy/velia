import Foundation

// MARK: - Benchmark dataset abstraction

//
// Swapping the synthetic stand-in for the real licensed/public irregular-cycle dataset
// (Phase 0, milestone 0.2) is a one-file change: implement `CycleDataset` (e.g. point
// `CSVCycleDataset` at the real export) and feed `dataset.load()` into `Benchmark.evaluate`.

public protocol CycleDataset: Sendable {
    func load() throws -> [BenchmarkUser]
}

/// The synthetic generator exposed as a `CycleDataset` for a uniform call site.
public struct SyntheticCycleDataset: CycleDataset {
    public let seed: UInt64
    public let usersPerSegment: Int
    public let cyclesPerUser: Int

    public init(seed: UInt64 = 42, usersPerSegment: Int = 60, cyclesPerUser: Int = 16) {
        self.seed = seed
        self.usersPerSegment = usersPerSegment
        self.cyclesPerUser = cyclesPerUser
    }

    public func load() throws -> [BenchmarkUser] {
        SyntheticDataset.generate(seed: seed, usersPerSegment: usersPerSegment, cyclesPerUser: cyclesPerUser)
    }
}

/// Loads real data from CSV.
///
/// Expected format (header required), one row per logged period start:
///
///     user_id,segment,period_start
///     u001,pcos,2023-01-04
///     u001,pcos,2023-02-19
///     u002,typical,2023-01-02
///
/// `segment` ∈ {typical, pcos, perimenopause, postpartum, unknown}; `period_start` = `yyyy-MM-dd`.
/// A user is marked irregular when its segment is anything other than `typical`.
public struct CSVCycleDataset: CycleDataset {
    public enum ParseError: Error, Equatable {
        case missingHeader
        case badColumns(line: Int)
        case badDate(String, line: Int)
        case badSegment(String, line: Int)
    }

    private let text: String
    public init(text: String) {
        self.text = text
    }

    public init(url: URL) throws {
        text = try String(contentsOf: url, encoding: .utf8)
    }

    public func load() throws -> [BenchmarkUser] {
        try Self.parse(text)
    }

    /// Serialize users back to the canonical CSV format (handy for templates/round-trip tests).
    public static func serialize(_ users: [BenchmarkUser], userIDPrefix: String = "u") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        var out = "user_id,segment,period_start\n"
        for (index, user) in users.enumerated() {
            let id = "\(userIDPrefix)\(String(format: "%04d", index + 1))"
            for event in user.history.sorted(by: { $0.startDate < $1.startDate }) {
                out += "\(id),\(user.segment.rawValue),\(formatter.string(from: event.startDate))\n"
            }
        }
        return out
    }

    public static func parse(_ text: String) throws -> [BenchmarkUser] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { throw ParseError.missingHeader }
        lines.removeFirst() // drop header

        // Preserve first-seen user order for deterministic output.
        var order: [String] = []
        var bySegment: [String: Segment] = [:]
        var byDates: [String: [Date]] = [:]

        for (idx, raw) in lines.enumerated() {
            let lineNo = idx + 2 // 1-based, accounting for header
            let row = raw.trimmingCharacters(in: .whitespaces)
            if row.isEmpty { continue }
            let cols = row.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 3 else { throw ParseError.badColumns(line: lineNo) }

            let userID = cols[0]
            guard let segment = Segment(rawValue: cols[1].lowercased()) else {
                throw ParseError.badSegment(cols[1], line: lineNo)
            }
            guard let date = formatter.date(from: cols[2]) else {
                throw ParseError.badDate(cols[2], line: lineNo)
            }

            if byDates[userID] == nil { order.append(userID) }
            bySegment[userID] = segment
            byDates[userID, default: []].append(date)
        }

        return order.map { userID in
            let segment = bySegment[userID] ?? .unknown
            let history = (byDates[userID] ?? []).sorted().map { PeriodEvent(startDate: $0) }
            return BenchmarkUser(segment: segment, history: history, isIrregular: segment != .typical)
        }
    }
}
