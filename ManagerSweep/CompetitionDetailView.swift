import SwiftUI
import SwiftData

struct CompetitionDetailView: View {
    @Bindable var competition: Competition
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTab(competition: competition)
                .tabItem { Label("Overview", systemImage: "info.circle") }
                .tag(0)
            EntriesTab(competition: competition)
                .tabItem { Label("Entries", systemImage: "person.2") }
                .tag(1)
            DrawTab(competition: competition)
                .tabItem { Label("Draw", systemImage: "shuffle") }
                .tag(2)
            ResultsTab(competition: competition)
                .tabItem { Label("Results", systemImage: "trophy") }
                .tag(3)
        }
        .navigationTitle(competition.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    competition.status = competition.status.next
                } label: {
                    CompetitionStatusPill(
                        label: competition.status.displayName,
                        status: competition.status
                    )
                }
            }
        }
    }
}

// MARK: - Overview

struct OverviewTab: View {
    let competition: Competition

    var body: some View {
        List {
            Section {
                LabeledContent("Pool", value: competition.pool?.name ?? "—")
                LabeledContent("Type", value: competition.pool?.type.displayName ?? "—")
                LabeledContent("Status", value: competition.status.displayName)
            }
            Section("Progress") {
                let drawn = competition.drawnCount
                let total = competition.entries.count
                if total > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(drawn), total: Double(total))
                            .tint(drawn == total ? .green : .blue)
                        Text("\(drawn) of \(total) entries drawn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("No entries yet.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Prize Positions") {
                let sorted = competition.prizePositions.sorted { $0.sortOrder < $1.sortOrder }
                if sorted.isEmpty {
                    Text("No prize positions.").foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { pos in
                        Text(pos.label)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Entries

struct EntriesTab: View {
    @Bindable var competition: Competition
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddPlayer = false

    private var sortedEntries: [Entry] {
        competition.entries.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }

    var body: some View {
        List {
            Section("Entries (\(competition.entries.count))") {
                if competition.entries.isEmpty {
                    Text("No entries.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text(entry.playerName)
                            Spacer()
                            if let assigned = entry.assignedName {
                                Text(assigned)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if entry.isDrawn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete(perform: competition.status == .setup ? removeEntries : nil)
                }
            }
            if competition.status == .setup {
                Section {
                    Button("Add players…") { showAddPlayer = true }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showAddPlayer) {
            AddPlayersSheet(competition: competition)
        }
    }

    private func removeEntries(at offsets: IndexSet) {
        let sorted = sortedEntries
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct AddPlayersSheet: View {
    @Bindable var competition: Competition
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var alreadyAdded: Set<UUID> {
        Set(competition.entries.compactMap { $0.player?.id })
    }

    private var available: [Player] {
        allPlayers.filter { !alreadyAdded.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(available) { player in
                Button(player.name) {
                    let entry = Entry(competition: competition, player: player)
                    modelContext.insert(entry)
                    competition.entries.append(entry)
                }
            }
            .navigationTitle("Add Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Draw

struct DrawTab: View {
    @Bindable var competition: Competition
    @Environment(\.modelContext) private var modelContext
    @State private var spinEntry: Entry?

    private var undrawnEntries: [Entry] {
        competition.entries
            .filter { !$0.isDrawn }
            .sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }

    private var drawnEntries: [Entry] {
        competition.entries
            .filter { $0.isDrawn }
            .sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }

    private var spinOptions: [String] {
        guard let pool = competition.pool else { return [] }
        if pool.type == .racing {
            return pool.runners.map(\.name)
        } else {
            return pool.teams.map(\.name)
        }
    }

    var body: some View {
        List {
            if competition.status != .active {
                Section {
                    Label("Set competition to Active to draw entries.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            if !undrawnEntries.isEmpty {
                Section("To draw (\(undrawnEntries.count))") {
                    ForEach(undrawnEntries) { entry in
                        HStack {
                            Text(entry.playerName)
                            Spacer()
                            if competition.status == .active && !spinOptions.isEmpty {
                                Button("Spin") { spinEntry = entry }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            if !drawnEntries.isEmpty {
                Section("Drawn (\(drawnEntries.count))") {
                    ForEach(drawnEntries) { entry in
                        HStack {
                            Text(entry.playerName)
                            Spacer()
                            Text(entry.assignedName ?? "—")
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            if competition.entries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "person.2",
                    description: Text("Add entries in the Entries tab.")
                )
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $spinEntry) { entry in
            SpinScreenView(
                entry: entry,
                options: spinOptions
            ) { assignedName in
                assign(entry: entry, name: assignedName)
            }
            .presentationDetents([.large])
        }
    }

    private func assign(entry: Entry, name: String) {
        guard let pool = competition.pool else { return }
        if pool.type == .racing {
            entry.assignedRunner = pool.runners.first { $0.name == name }
        } else {
            entry.assignedTeam = pool.teams.first { $0.name == name }
        }
        entry.spunAt = Date()
    }
}

// MARK: - Results

struct ResultsTab: View {
    @Bindable var competition: Competition
    @Environment(\.modelContext) private var modelContext
    @State private var editingResult: CompetitionResult?
    @State private var showAddResult = false

    private var sortedPositions: [PrizePosition] {
        competition.prizePositions.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func result(for position: PrizePosition) -> CompetitionResult? {
        competition.results.first { $0.prizePosition?.id == position.id }
    }

    var body: some View {
        List {
            Section("Prize positions") {
                if sortedPositions.isEmpty {
                    Text("No prize positions defined.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPositions) { pos in
                        let res = result(for: pos)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(pos.label).font(.headline)
                                Spacer()
                                if let assigned = res?.assignedName {
                                    Text(assigned).foregroundStyle(.secondary)
                                } else {
                                    Text("—").foregroundStyle(.tertiary)
                                }
                                if competition.status != .complete {
                                    Button(res == nil ? "Assign" : "Edit") {
                                        if let res { editingResult = res }
                                        else { createAndEdit(position: pos) }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                            if let res {
                                let winners = res.winners(in: competition.entries)
                                if !winners.isEmpty {
                                    Text(winners.map(\.playerName).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingResult) { result in
            AssignResultSheet(result: result, pool: competition.pool)
        }
    }

    private func createAndEdit(position: PrizePosition) {
        let result = CompetitionResult(competition: competition, prizePosition: position)
        modelContext.insert(result)
        competition.results.append(result)
        editingResult = result
    }
}

struct AssignResultSheet: View {
    @Bindable var result: CompetitionResult
    let pool: Pool?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let pool {
                    if pool.type == .racing {
                        Section("Assign runner") {
                            Picker("Runner", selection: $result.runner) {
                                Text("None").tag(Optional<Runner>.none)
                                ForEach(pool.runners.sorted { $0.name < $1.name }) { r in
                                    Text(r.name).tag(Optional(r))
                                }
                            }
                        }
                    } else {
                        Section("Assign team") {
                            Picker("Team", selection: $result.team) {
                                Text("None").tag(Optional<Team>.none)
                                ForEach(pool.teams.sorted { $0.name < $1.name }) { t in
                                    Text(t.name).tag(Optional(t))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
