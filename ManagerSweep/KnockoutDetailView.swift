import SwiftUI
import SwiftData

struct KnockoutDetailView: View {
    @Bindable var pool: Pool
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TeamsPanel(pool: pool)
                .tabItem { Label("Teams", systemImage: "person.3.fill") }
                .tag(0)

            if pool.hasGroupStage {
                GroupsPanel(pool: pool)
                    .tabItem { Label("Groups", systemImage: "list.bullet.rectangle") }
                    .tag(1)
            }

            BracketPanel(pool: pool)
                .tabItem { Label("Bracket", systemImage: "trophy") }
                .tag(pool.hasGroupStage ? 2 : 1)
        }
    }
}

// MARK: - Teams Panel

struct TeamsPanel: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext
    @State private var newTeamName = ""
    @FocusState private var fieldFocused: Bool

    private var sortedTeams: [Team] {
        pool.teams.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if pool.status == .setup {
                Section("Add team") {
                    HStack {
                        TextField("Team name", text: $newTeamName)
                            .focused($fieldFocused)
                            .onSubmit(addTeam)
                        Button("Add", action: addTeam)
                            .disabled(newTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            Section("Teams (\(pool.teams.count))") {
                if pool.teams.isEmpty {
                    Text("No teams yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTeams) { team in
                        Text(team.name)
                    }
                    .onDelete { offsets in
                        guard pool.status == .setup else { return }
                        deleteTeams(at: offsets)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func addTeam() {
        let trimmed = newTeamName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let team = Team(name: trimmed)
        modelContext.insert(team)
        pool.teams.append(team)
        newTeamName = ""
        fieldFocused = false
    }

    private func deleteTeams(at offsets: IndexSet) {
        let sorted = sortedTeams
        for index in offsets { modelContext.delete(sorted[index]) }
    }
}

// MARK: - Groups Panel

struct GroupsPanel: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext
    @State private var newGroupName = ""
    @State private var selectedGroup: TournamentGroup?

    private var sortedGroups: [TournamentGroup] {
        pool.groups.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if pool.status == .setup {
                Section("New group") {
                    HStack {
                        TextField("Group name (e.g. Group A)", text: $newGroupName)
                            .onSubmit(addGroup)
                        Button("Add", action: addGroup)
                            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            ForEach(sortedGroups) { group in
                Section {
                    Button {
                        selectedGroup = group
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name).font(.headline).foregroundStyle(.primary)
                                Text("\(group.teams.count) teams · \(group.matches.count) matches")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    GroupStandingsRow(group: group)
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(group: group, pool: pool)
        }
    }

    private func addGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = TournamentGroup(name: trimmed)
        modelContext.insert(group)
        pool.groups.append(group)
        newGroupName = ""
    }
}

struct GroupStandingsRow: View {
    let group: TournamentGroup

    var body: some View {
        if group.standings.isEmpty { EmptyView() }
        else {
            VStack(spacing: 0) {
                HStack {
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        Text("P"); Text("W"); Text("D"); Text("L"); Text("GD"); Text("Pts").bold()
                    }
                    .frame(width: 26)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                ForEach(Array(group.standings.enumerated()), id: \.offset) { i, standing in
                    HStack {
                        Text("\(i + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                        Text(standing.team.name)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Group {
                            Text("\(standing.played)")
                            Text("\(standing.won)")
                            Text("\(standing.drawn)")
                            Text("\(standing.lost)")
                            Text("\(standing.goalDifference)")
                            Text("\(standing.points)").bold()
                        }
                        .font(.caption.monospacedDigit())
                        .frame(width: 26)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Group Detail Sheet

struct GroupDetailSheet: View {
    @Bindable var group: TournamentGroup
    let pool: Pool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddTeam = false
    @State private var showAddMatch = false
    @State private var scoringMatch: GroupMatch?

    private var sortedMatches: [GroupMatch] {
        group.matches.sorted { ($0.scheduledAt ?? $0.createdAt) < ($1.scheduledAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Teams in group") {
                    if group.teams.isEmpty {
                        Text("No teams assigned.").foregroundStyle(.secondary)
                    }
                    ForEach(group.teams.sorted { $0.name < $1.name }) { team in
                        Text(team.name)
                    }
                    if pool.status == .setup {
                        Button("Assign team…") { showAddTeam = true }
                    }
                }

                Section("Standings") {
                    if group.standings.isEmpty {
                        Text("Play some matches to see standings.").foregroundStyle(.secondary)
                    } else {
                        GroupStandingsRow(group: group)
                    }
                }

                Section("Fixtures") {
                    if group.matches.isEmpty {
                        Text("No fixtures yet.").foregroundStyle(.secondary)
                    }
                    ForEach(sortedMatches) { match in
                        GroupMatchRow(match: match)
                            .contentShape(Rectangle())
                            .onTapGesture { scoringMatch = match }
                    }
                    if pool.status != .complete {
                        Button("Add fixture…") { showAddMatch = true }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddTeam) {
                AssignTeamToGroupSheet(group: group, pool: pool)
            }
            .sheet(isPresented: $showAddMatch) {
                AddGroupMatchSheet(group: group)
            }
            .sheet(item: $scoringMatch) { match in
                ScoreGroupMatchSheet(match: match)
            }
        }
    }
}

struct GroupMatchRow: View {
    let match: GroupMatch

    var body: some View {
        HStack {
            Text(match.homeTeam?.name ?? "TBD")
                .frame(maxWidth: .infinity, alignment: .trailing)
            if match.status == .complete, let hs = match.homeScore, let as_ = match.awayScore {
                Text("\(hs)–\(as_)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 60, alignment: .center)
            } else {
                Text("vs")
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .center)
            }
            Text(match.awayTeam?.name ?? "TBD")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }
}

struct AssignTeamToGroupSheet: View {
    @Bindable var group: TournamentGroup
    let pool: Pool
    @Environment(\.dismiss) private var dismiss

    private var unassignedTeams: [Team] {
        pool.teams.filter { team in
            !group.teams.contains { $0.id == team.id }
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List(unassignedTeams) { team in
                Button(team.name) {
                    group.teams.append(team)
                    dismiss()
                }
            }
            .navigationTitle("Assign Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct AddGroupMatchSheet: View {
    @Bindable var group: TournamentGroup
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var homeTeam: Team?
    @State private var awayTeam: Team?
    @State private var scheduledAt = Date()
    @State private var hasDate = false

    private var teams: [Team] { group.teams.sorted { $0.name < $1.name } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Home team", selection: $homeTeam) {
                        Text("Select…").tag(Optional<Team>.none)
                        ForEach(teams) { t in Text(t.name).tag(Optional(t)) }
                    }
                    Picker("Away team", selection: $awayTeam) {
                        Text("Select…").tag(Optional<Team>.none)
                        ForEach(teams) { t in Text(t.name).tag(Optional(t)) }
                    }
                }
                Section {
                    Toggle("Set date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Add Fixture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(homeTeam == nil || awayTeam == nil || homeTeam?.id == awayTeam?.id)
                }
            }
        }
    }

    private func add() {
        guard let home = homeTeam, let away = awayTeam else { return }
        let match = GroupMatch(homeTeam: home, awayTeam: away, scheduledAt: hasDate ? scheduledAt : nil)
        modelContext.insert(match)
        group.matches.append(match)
        dismiss()
    }
}

struct ScoreGroupMatchSheet: View {
    @Bindable var match: GroupMatch
    @Environment(\.dismiss) private var dismiss
    @State private var homeScore = 0
    @State private var awayScore = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("\(match.homeTeam?.name ?? "Home") vs \(match.awayTeam?.name ?? "Away")") {
                    Stepper("Home: \(homeScore)", value: $homeScore, in: 0...99)
                    Stepper("Away: \(awayScore)", value: $awayScore, in: 0...99)
                }
                Section {
                    Picker("Status", selection: $match.status) {
                        Text("Scheduled").tag(GroupMatchStatus.scheduled)
                        Text("Complete").tag(GroupMatchStatus.complete)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Score Match")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                homeScore = match.homeScore ?? 0
                awayScore = match.awayScore ?? 0
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        match.homeScore = homeScore
                        match.awayScore = awayScore
                        if homeScore != awayScore || match.status == .complete {
                            match.status = .complete
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bracket Panel

struct BracketPanel: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext
    @State private var showAddStage = false
    @State private var selectedStage: KnockoutStage?

    private var sortedStages: [KnockoutStage] {
        pool.knockoutStages.sorted { $0.stageOrder < $1.stageOrder }
    }

    var body: some View {
        List {
            if pool.status != .complete {
                Section {
                    Button("Add stage…") { showAddStage = true }
                }
            }
            ForEach(sortedStages) { stage in
                Section(stage.name) {
                    ForEach(stage.matches.sorted { $0.matchNumber < $1.matchNumber }) { match in
                        KnockoutMatchRow(match: match)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedStage = stage }
                    }
                    if stage.matches.isEmpty {
                        Text("No matches.").foregroundStyle(.secondary)
                    }
                    if pool.status != .complete {
                        Button("Manage…") { selectedStage = stage }
                            .font(.subheadline)
                    }
                }
            }
            if pool.knockoutStages.isEmpty {
                ContentUnavailableView(
                    "No Stages",
                    systemImage: "trophy",
                    description: Text("Add stages like Quarter-finals, Semi-finals, Final.")
                )
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showAddStage) {
            AddStageSheet(pool: pool)
        }
        .sheet(item: $selectedStage) { stage in
            StageDetailSheet(stage: stage, pool: pool)
        }
    }
}

struct KnockoutMatchRow: View {
    let match: KnockoutMatch

    var body: some View {
        HStack {
            Text(match.homeTeam?.name ?? "TBD")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(match.homeTeam == nil ? .secondary : .primary)
            if match.status == .complete,
               let hs = match.homeScore, let as_ = match.awayScore {
                Text("\(hs)–\(as_)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 60, alignment: .center)
            } else {
                Text("vs").foregroundStyle(.secondary).frame(width: 60, alignment: .center)
            }
            Text(match.awayTeam?.name ?? "TBD")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(match.awayTeam == nil ? .secondary : .primary)
        }
        .font(.subheadline)
    }
}

struct AddStageSheet: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var matchCount = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Stage name (e.g. Quarter-finals)", text: $name)
                    Stepper("Matches: \(matchCount)", value: $matchCount, in: 1...32)
                }
            }
            .navigationTitle("Add Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let nextOrder = (pool.knockoutStages.map(\.stageOrder).max() ?? -1) + 1
                        let stage = KnockoutStage(name: name.trimmingCharacters(in: .whitespaces), stageOrder: nextOrder)
                        modelContext.insert(stage)
                        for i in 1...matchCount {
                            let match = KnockoutMatch(matchNumber: i)
                            modelContext.insert(match)
                            stage.matches.append(match)
                        }
                        pool.knockoutStages.append(stage)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct StageDetailSheet: View {
    @Bindable var stage: KnockoutStage
    let pool: Pool
    @Environment(\.dismiss) private var dismiss
    @State private var scoringMatch: KnockoutMatch?

    private var sortedMatches: [KnockoutMatch] {
        stage.matches.sorted { $0.matchNumber < $1.matchNumber }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedMatches) { match in
                    KnockoutMatchRow(match: match)
                        .contentShape(Rectangle())
                        .onTapGesture { scoringMatch = match }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(stage.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $scoringMatch) { match in
                ScoreKnockoutMatchSheet(match: match, pool: pool)
            }
        }
    }
}

struct ScoreKnockoutMatchSheet: View {
    @Bindable var match: KnockoutMatch
    let pool: Pool
    @Environment(\.dismiss) private var dismiss
    @State private var homeScore = 0
    @State private var awayScore = 0
    @State private var manualWinner: Team?

    private var isScoredDraw: Bool {
        homeScore == awayScore && match.status == .complete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    Picker("Home", selection: $match.homeTeam) {
                        Text("TBD").tag(Optional<Team>.none)
                        ForEach(pool.teams.sorted { $0.name < $1.name }) { t in
                            Text(t.name).tag(Optional(t))
                        }
                    }
                    Picker("Away", selection: $match.awayTeam) {
                        Text("TBD").tag(Optional<Team>.none)
                        ForEach(pool.teams.sorted { $0.name < $1.name }) { t in
                            Text(t.name).tag(Optional(t))
                        }
                    }
                }
                Section("Score") {
                    Stepper("Home: \(homeScore)", value: $homeScore, in: 0...99)
                    Stepper("Away: \(awayScore)", value: $awayScore, in: 0...99)
                }
                if isScoredDraw {
                    Section("Winner (penalty/extra time)") {
                        Picker("Winner", selection: $match.winnerTeam) {
                            Text("None").tag(Optional<Team>.none)
                            if let h = match.homeTeam { Text(h.name).tag(Optional(h)) }
                            if let a = match.awayTeam { Text(a.name).tag(Optional(a)) }
                        }
                    }
                }
                Section {
                    Picker("Status", selection: $match.status) {
                        Text("Pending").tag(KnockoutMatchStatus.pending)
                        Text("Scheduled").tag(KnockoutMatchStatus.scheduled)
                        Text("Complete").tag(KnockoutMatchStatus.complete)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Match \(match.matchNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                homeScore = match.homeScore ?? 0
                awayScore = match.awayScore ?? 0
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        match.homeScore = homeScore
                        match.awayScore = awayScore
                        dismiss()
                    }
                }
            }
        }
    }
}
