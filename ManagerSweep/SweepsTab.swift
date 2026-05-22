import SwiftUI
import SwiftData

struct SweepsTab: View {
    @Query(sort: \Competition.createdAt, order: .reverse) private var competitions: [Competition]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if competitions.isEmpty {
                    ContentUnavailableView(
                        "No Sweeps",
                        systemImage: "trophy",
                        description: Text("Tap + to create your first sweep.")
                    )
                } else {
                    List {
                        ForEach(competitions) { comp in
                            NavigationLink(destination: CompetitionDetailView(competition: comp)) {
                                CompetitionRow(competition: comp)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Sweeps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Label("New Sweep", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateCompetitionView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(competitions[index]) }
    }
}

struct CompetitionRow: View {
    let competition: Competition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(competition.name).font(.headline)
                Spacer()
                CompetitionStatusPill(
                    label: competition.status.displayName,
                    status: competition.status
                )
            }
            if let pool = competition.pool {
                Text(pool.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if competition.entries.count > 0 {
                let drawn = competition.drawnCount
                let total = competition.entries.count
                ProgressView(value: Double(drawn), total: Double(total))
                    .tint(drawn == total ? .green : .blue)
                Text("\(drawn)/\(total) drawn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateCompetitionView: View {
    @Query(sort: \Pool.name) private var pools: [Pool]
    @Query(sort: \Player.name) private var players: [Player]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedPool: Pool?
    @State private var prizeLabels = ["1st", "2nd", "3rd"]
    @State private var selectedPlayers: Set<UUID> = []
    @State private var newPrizeLabel = ""

    private var activePools: [Pool] {
        pools.filter { $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sweep name") {
                    TextField("e.g. Grand National Sweep", text: $name)
                }
                Section("Pool") {
                    if activePools.isEmpty {
                        Text("No active pools. Set a pool to Active first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Pool", selection: $selectedPool) {
                            Text("Select pool…").tag(Optional<Pool>.none)
                            ForEach(activePools) { pool in
                                Text(pool.name).tag(Optional(pool))
                            }
                        }
                    }
                }
                Section("Prize positions") {
                    ForEach(prizeLabels.indices, id: \.self) { i in
                        TextField("Label", text: $prizeLabels[i])
                    }
                    .onDelete { prizeLabels.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add position…", text: $newPrizeLabel)
                            .onSubmit(addPrize)
                        Button("Add", action: addPrize)
                            .disabled(newPrizeLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Players (\(selectedPlayers.count) selected)") {
                    if players.isEmpty {
                        Text("No players. Add them in the Players tab.")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Select all") {
                            if selectedPlayers.count == players.count {
                                selectedPlayers = []
                            } else {
                                selectedPlayers = Set(players.map(\.id))
                            }
                        }
                        ForEach(players) { player in
                            HStack {
                                Text(player.name)
                                Spacer()
                                if selectedPlayers.contains(player.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(player) }
                        }
                    }
                }
            }
            .navigationTitle("New Sweep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || selectedPool == nil
                                  || selectedPlayers.isEmpty)
                }
            }
        }
    }

    private func addPrize() {
        let trimmed = newPrizeLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        prizeLabels.append(trimmed)
        newPrizeLabel = ""
    }

    private func toggle(_ player: Player) {
        if selectedPlayers.contains(player.id) {
            selectedPlayers.remove(player.id)
        } else {
            selectedPlayers.insert(player.id)
        }
    }

    private func create() {
        guard let pool = selectedPool,
              let trimmedName = Optional(name.trimmingCharacters(in: .whitespaces)),
              !trimmedName.isEmpty else { return }
        let competition = Competition(name: trimmedName, pool: pool)
        modelContext.insert(competition)
        for (i, label) in prizeLabels.enumerated() {
            guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let pos = PrizePosition(label: label, sortOrder: i)
            modelContext.insert(pos)
            competition.prizePositions.append(pos)
        }
        let orderedPlayers = players.filter { selectedPlayers.contains($0.id) }
        for player in orderedPlayers {
            let entry = Entry(competition: competition, player: player)
            modelContext.insert(entry)
            competition.entries.append(entry)
        }
        dismiss()
    }
}
