import Foundation
import SwiftData

// MARK: - Enums

enum PoolType: String, Codable, CaseIterable {
    case racing, knockout
    var displayName: String {
        switch self {
        case .racing: "Racing"
        case .knockout: "Knockout"
        }
    }
    var icon: String {
        switch self {
        case .racing: "figure.equestrian.sports"
        case .knockout: "sportscourt.fill"
        }
    }
}

enum PoolStatus: String, Codable, CaseIterable {
    case setup, active, complete
    var next: PoolStatus {
        switch self {
        case .setup: .active
        case .active: .complete
        case .complete: .setup
        }
    }
    var displayName: String { rawValue.capitalized }
    var color: String {
        switch self {
        case .setup: "yellow"
        case .active: "green"
        case .complete: "gray"
        }
    }
}

enum CompetitionStatus: String, Codable, CaseIterable {
    case setup, active, complete
    var next: CompetitionStatus {
        switch self {
        case .setup: .active
        case .active: .complete
        case .complete: .setup
        }
    }
    var displayName: String { rawValue.capitalized }
}

enum GroupMatchStatus: String, Codable {
    case scheduled, complete
}

enum KnockoutMatchStatus: String, Codable {
    case pending, scheduled, complete
}

// MARK: - Pool

@Model final class Pool {
    var id: UUID
    var name: String
    var type: PoolType
    var hasGroupStage: Bool
    var status: PoolStatus
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Runner.pool)
    var runners: [Runner] = []

    @Relationship(deleteRule: .cascade, inverse: \Team.pool)
    var teams: [Team] = []

    @Relationship(deleteRule: .cascade, inverse: \TournamentGroup.pool)
    var groups: [TournamentGroup] = []

    @Relationship(deleteRule: .cascade, inverse: \KnockoutStage.pool)
    var knockoutStages: [KnockoutStage] = []

    @Relationship(deleteRule: .cascade, inverse: \Competition.pool)
    var competitions: [Competition] = []

    init(name: String, type: PoolType, hasGroupStage: Bool = false) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.hasGroupStage = type == .knockout ? hasGroupStage : false
        self.status = .setup
        self.createdAt = Date()
    }
}

// MARK: - Racing

@Model final class Runner {
    var id: UUID
    var name: String
    var finishingPosition: Int?
    var createdAt: Date
    var pool: Pool?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Knockout Teams & Groups

@Model final class Team {
    var id: UUID
    var name: String
    var createdAt: Date
    var pool: Pool?
    var group: TournamentGroup?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

@Model final class TournamentGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    var pool: Pool?

    @Relationship(deleteRule: .cascade, inverse: \GroupMatch.group)
    var matches: [GroupMatch] = []

    @Relationship(inverse: \Team.group)
    var teams: [Team] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    struct Standing {
        let team: Team
        var played = 0
        var won = 0
        var drawn = 0
        var lost = 0
        var goalsFor = 0
        var goalsAgainst = 0
        var points: Int { won * 3 + drawn }
        var goalDifference: Int { goalsFor - goalsAgainst }
    }

    var standings: [Standing] {
        var records: [UUID: Standing] = [:]
        for team in teams {
            records[team.id] = Standing(team: team)
        }
        for match in matches where match.status == .complete {
            guard let home = match.homeTeam,
                  let away = match.awayTeam,
                  let hs = match.homeScore,
                  let as_ = match.awayScore else { continue }
            var hr = records[home.id] ?? Standing(team: home)
            var ar = records[away.id] ?? Standing(team: away)
            hr.played += 1; ar.played += 1
            hr.goalsFor += hs; hr.goalsAgainst += as_
            ar.goalsFor += as_; ar.goalsAgainst += hs
            if hs > as_ { hr.won += 1; ar.lost += 1 }
            else if as_ > hs { ar.won += 1; hr.lost += 1 }
            else { hr.drawn += 1; ar.drawn += 1 }
            records[home.id] = hr
            records[away.id] = ar
        }
        return records.values.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            return $0.goalsFor > $1.goalsFor
        }
    }
}

@Model final class GroupMatch {
    var id: UUID
    var homeScore: Int?
    var awayScore: Int?
    var status: GroupMatchStatus
    var scheduledAt: Date?
    var createdAt: Date
    var group: TournamentGroup?
    var homeTeam: Team?
    var awayTeam: Team?

    init(homeTeam: Team, awayTeam: Team, scheduledAt: Date? = nil) {
        self.id = UUID()
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.scheduledAt = scheduledAt
        self.status = .scheduled
        self.createdAt = Date()
    }
}

// MARK: - Knockout Bracket

@Model final class KnockoutStage {
    var id: UUID
    var name: String
    var stageOrder: Int
    var createdAt: Date
    var pool: Pool?

    @Relationship(deleteRule: .cascade, inverse: \KnockoutMatch.stage)
    var matches: [KnockoutMatch] = []

    init(name: String, stageOrder: Int) {
        self.id = UUID()
        self.name = name
        self.stageOrder = stageOrder
        self.createdAt = Date()
    }
}

@Model final class KnockoutMatch {
    var id: UUID
    var matchNumber: Int
    var homeScore: Int?
    var awayScore: Int?
    var status: KnockoutMatchStatus
    var scheduledAt: Date?
    var createdAt: Date
    var stage: KnockoutStage?
    var homeTeam: Team?
    var awayTeam: Team?
    var winnerTeam: Team?

    init(matchNumber: Int) {
        self.id = UUID()
        self.matchNumber = matchNumber
        self.status = .pending
        self.createdAt = Date()
    }

    var computedWinner: Team? {
        guard let hs = homeScore, let as_ = awayScore else { return winnerTeam }
        if hs > as_ { return homeTeam }
        if as_ > hs { return awayTeam }
        return winnerTeam
    }
}

// MARK: - Competition (Sweep)

@Model final class Competition {
    var id: UUID
    var name: String
    var status: CompetitionStatus
    var createdAt: Date
    var pool: Pool?

    @Relationship(deleteRule: .cascade, inverse: \PrizePosition.competition)
    var prizePositions: [PrizePosition] = []

    @Relationship(deleteRule: .cascade, inverse: \Entry.competition)
    var entries: [Entry] = []

    @Relationship(deleteRule: .cascade, inverse: \CompetitionResult.competition)
    var results: [CompetitionResult] = []

    init(name: String, pool: Pool) {
        self.id = UUID()
        self.name = name
        self.pool = pool
        self.status = .setup
        self.createdAt = Date()
    }

    var drawnCount: Int { entries.filter { $0.isDrawn }.count }
}

@Model final class PrizePosition {
    var id: UUID
    var label: String
    var sortOrder: Int
    var createdAt: Date
    var competition: Competition?

    init(label: String, sortOrder: Int) {
        self.id = UUID()
        self.label = label
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

@Model final class Player {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Entry.player)
    var entries: [Entry] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

@Model final class Entry {
    var id: UUID
    var spunAt: Date?
    var createdAt: Date
    var competition: Competition?
    var player: Player?
    var assignedRunner: Runner?
    var assignedTeam: Team?

    init(competition: Competition, player: Player) {
        self.id = UUID()
        self.competition = competition
        self.player = player
        self.createdAt = Date()
    }

    var isDrawn: Bool { spunAt != nil }
    var assignedName: String? { assignedRunner?.name ?? assignedTeam?.name }
    var playerName: String { player?.name ?? "Unknown" }
}

@Model final class CompetitionResult {
    var id: UUID
    var createdAt: Date
    var competition: Competition?
    var prizePosition: PrizePosition?
    var runner: Runner?
    var team: Team?

    init(competition: Competition, prizePosition: PrizePosition) {
        self.id = UUID()
        self.competition = competition
        self.prizePosition = prizePosition
        self.createdAt = Date()
    }

    var assignedName: String? { runner?.name ?? team?.name }

    func winners(in entries: [Entry]) -> [Entry] {
        if let runner {
            return entries.filter { $0.assignedRunner?.id == runner.id }
        } else if let team {
            return entries.filter { $0.assignedTeam?.id == team.id }
        }
        return []
    }
}
