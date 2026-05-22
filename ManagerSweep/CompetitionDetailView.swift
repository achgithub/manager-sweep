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

    private var drawn: Int { competition.drawnCount }
    private var total: Int { competition.entries.count }
    private var sortedPositions: [PrizePosition] {
        competition.prizePositions.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            infoSection
            progressSection
            prizeSection
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var infoSection: some View {
        Section {
            LabeledContent("Pool", value: competition.pool?.name ?? "—")
            LabeledContent("Type", value: competition.pool?.type.displayName ?? "—")
            LabeledContent("Status", value: competition.status.displayName)
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        Section("Progress") {
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
    }

    @ViewBuilder
    private var prizeSection: some View {
        Section("Prize Positions") {
            if sortedPositions.isEmpty {
                Text("No prize positions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedPositions) { pos in
                    Text(pos.label)
                }
            }
        }
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
            entriesSection
            addSection
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showAddPlayer) {
            AddPlayersSheet(competition: competition)
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        Section("Entries (\(competition.entries.count))") {
            if competition.entries.isEmpty {
                Text("No entries.").foregroundStyle(.secondary)
            } else {
                ForEach(sortedEntries) { entry in
                    EntryRow(entry: entry)
                }
                .onDelete { offsets in
                    guard competition.status == .setup else { return }
                    removeEntries(at: offsets)
                }
            }
        }
    }

    @ViewBuilder
    private var addSection: some View {
        if competition.status == .setup {
            Section {
                Button("Add players…") { showAddPlayer = true }
            }
        }
    }

    private func removeEntries(at offsets: IndexSet) {
        let sorted = sortedEntries
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
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
        return pool.type == .racing ? pool.runners.map(\.name) : pool.teams.map(\.name)
    }

    private var canSpin: Bool {
        competition.status == .active && !spinOptions.isEmpty
    }

    var body: some View {
        List {
            inactiveNotice
            undrawnSection
            drawnSection
            emptyNotice
        }
        .listStyle(.insetGrouped)
        .sheet(item: $spinEntry) { entry in
            SpinScreenView(entry: entry, options: spinOptions) { name in
                assign(entry: entry, name: name)
            }
            .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var inactiveNotice: some View {
        if competition.status != .active {
            Section {
                Label("Set competition to Active to draw entries.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var undrawnSection: some View {
        if !undrawnEntries.isEmpty {
            Section("To draw (\(undrawnEntries.count))") {
                ForEach(undrawnEntries) { entry in
                    DrawEntryRow(entry: entry, canSpin: canSpin) {
                        spinEntry = entry
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var drawnSection: some View {
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
    }

    @ViewBuilder
    private var emptyNotice: some View {
        if competition.entries.isEmpty {
            ContentUnavailableView(
                "No Entries",
                systemImage: "person.2",
                description: Text("Add entries in the Entries tab.")
            )
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

struct DrawEntryRow: View {
    let entry: Entry
    let canSpin: Bool
    let onSpin: () -> Void

    var body: some View {
        HStack {
            Text(entry.playerName)
            Spacer()
            if canSpin {
                Button("Spin", action: onSpin)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Results

struct ResultsTab: View {
    @Bindable var competition: Competition
    @Environment(\.modelContext) private var modelContext
    @State private var editingResult: CompetitionResult?

    private var sortedPositions: [PrizePosition] {
        competition.prizePositions.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func existingResult(for position: PrizePosition) -> CompetitionResult? {
        competition.results.first { $0.prizePosition?.id == position.id }
    }

    var body: some View {
        List {
            Section("Prize positions") {
                if sortedPositions.isEmpty {
                    Text("No prize positions defined.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPositions) { pos in
                        ResultPositionRow(
                            position: pos,
                            result: existingResult(for: pos),
                            entries: competition.entries,
                            canEdit: competition.status != .complete
                        ) {
                            if let res = existingResult(for: pos) {
                                editingResult = res
                            } else {
                                createAndEdit(position: pos)
                            }
                        }
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

struct ResultPositionRow: View {
    let position: PrizePosition
    let result: CompetitionResult?
    let entries: [Entry]
    let canEdit: Bool
    let onEdit: () -> Void

    private var winners: [Entry] {
        result?.winners(in: entries) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(position.label).font(.headline)
                Spacer()
                assignedLabel
                if canEdit {
                    Button(result == nil ? "Assign" : "Edit", action: onEdit)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
            if !winners.isEmpty {
                Text(winners.map(\.playerName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var assignedLabel: some View {
        if let name = result?.assignedName {
            Text(name).foregroundStyle(.secondary)
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
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
