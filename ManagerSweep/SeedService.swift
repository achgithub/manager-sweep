#if DEBUG
import Foundation
import SwiftData

struct SeedService {

    enum SeedError: LocalizedError {
        case missingFile
        var errorDescription: String? { "world_cup_2026_schedule.json not found in app bundle." }
    }

    /// Inserts the full FIFA World Cup 2026 pool. No-op if the pool already exists.
    static func seedWorldCup(context: ModelContext) throws {
        // Idempotency — fetch all pools and check in Swift (avoids enum-predicate issues)
        let allPools = try context.fetch(FetchDescriptor<Pool>())
        guard !allPools.contains(where: { $0.name == "FIFA World Cup 2026" }) else { return }

        // Load bundled JSON
        guard let url = Bundle.main.url(forResource: "world_cup_2026_schedule", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw SeedError.missingFile
        }
        let schedule = try JSONDecoder().decode(WCSchedule.self, from: data)

        // EDT (UTC-4) converter
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        func toDate(_ date: String, _ timeET: String) -> Date? {
            iso.date(from: "\(date)T\(timeET):00-04:00")
        }

        // ── Pool ──────────────────────────────────────────────────────────
        let pool = Pool(name: "FIFA World Cup 2026", type: .knockout, hasGroupStage: true)
        pool.status = .active
        context.insert(pool)

        // ── Teams (48) ────────────────────────────────────────────────────
        var teamByName: [String: Team] = [:]
        for names in schedule.groups.values {
            for name in names where teamByName[name] == nil {
                let team = Team(name: name)
                context.insert(team)
                pool.teams.append(team)
                teamByName[name] = team
            }
        }

        // ── Groups + team assignments ─────────────────────────────────────
        var groupByLetter: [String: TournamentGroup] = [:]
        for letter in schedule.groups.keys.sorted() {
            let group = TournamentGroup(name: "Group \(letter)")
            context.insert(group)
            pool.groups.append(group)
            groupByLetter[letter] = group
            for name in schedule.groups[letter] ?? [] {
                if let team = teamByName[name] {
                    group.teams.append(team)
                }
            }
        }

        // ── Group stage fixtures (72) ─────────────────────────────────────
        for m in schedule.stages.groupStage.matches {
            guard let letter = m.group,
                  let homeName = m.home,
                  let awayName = m.away,
                  let group = groupByLetter[letter],
                  let home = teamByName[homeName],
                  let away = teamByName[awayName] else { continue }
            let match = GroupMatch(homeTeam: home, awayTeam: away,
                                   scheduledAt: toDate(m.date, m.timeET))
            context.insert(match)
            group.matches.append(match)
        }

        // ── Knockout stages ───────────────────────────────────────────────
        let stageDefs: [(String, Int, WCSchedule.MatchList)] = [
            ("Round of 32",          1, schedule.stages.roundOf32),
            ("Round of 16",          2, schedule.stages.roundOf16),
            ("Quarter-finals",       3, schedule.stages.quarterfinals),
            ("Semi-finals",          4, schedule.stages.semifinals),
            ("Final",                5, schedule.stages.finalMatch),
            ("Third-place play-off", 6, schedule.stages.thirdPlacePlayoff),
        ]
        for (name, order, list) in stageDefs {
            let stage = KnockoutStage(name: name, stageOrder: order)
            context.insert(stage)
            pool.knockoutStages.append(stage)
            for (i, m) in list.matches.enumerated() {
                let match = KnockoutMatch(matchNumber: i + 1)
                match.scheduledAt = toDate(m.date, m.timeET)
                match.status = .scheduled
                context.insert(match)
                stage.matches.append(match)
            }
        }
    }
}

// MARK: - Private JSON types

private struct WCSchedule: Decodable {
    let groups: [String: [String]]
    let stages: Stages

    struct Stages: Decodable {
        let groupStage: MatchList
        let roundOf32: MatchList
        let roundOf16: MatchList
        let quarterfinals: MatchList
        let semifinals: MatchList
        let finalMatch: MatchList
        let thirdPlacePlayoff: MatchList

        enum CodingKeys: String, CodingKey {
            case groupStage = "group_stage"
            case roundOf32 = "round_of_32"
            case roundOf16 = "round_of_16"
            case quarterfinals
            case semifinals
            case finalMatch = "final"
            case thirdPlacePlayoff = "third_place_playoff"
        }
    }

    struct MatchList: Decodable {
        let matches: [ScheduledMatch]
    }

    struct ScheduledMatch: Decodable {
        let date: String
        let timeET: String
        let group: String?
        let home: String?
        let away: String?

        enum CodingKeys: String, CodingKey {
            case date, group, home, away
            case timeET = "time_et"
        }
    }
}
#endif
