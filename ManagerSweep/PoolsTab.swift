import SwiftUI
import SwiftData

struct PoolsTab: View {
    @Query(sort: \Pool.createdAt, order: .reverse) private var pools: [Pool]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if pools.isEmpty {
                    ContentUnavailableView(
                        "No Pools",
                        systemImage: "rectangle.3.group",
                        description: Text("Tap + to create a racing or knockout pool.")
                    )
                } else {
                    List {
                        ForEach(pools) { pool in
                            NavigationLink(destination: PoolDetailView(pool: pool)) {
                                PoolRow(pool: pool)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Pools")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Label("Add Pool", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreatePoolView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(pools[index]) }
    }
}

struct PoolRow: View {
    let pool: Pool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pool.type.icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(pool.name).font(.headline)
                Text(pool.type == .knockout && pool.hasGroupStage
                     ? "Knockout with groups"
                     : pool.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(label: pool.status.displayName, status: pool.status)
        }
        .padding(.vertical, 4)
    }
}

struct StatusPill: View {
    let label: String
    let status: PoolStatus

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor.opacity(0.15))
            .foregroundStyle(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch status {
        case .setup: .yellow
        case .active: .green
        case .complete: .secondary
        }
    }
}

struct CompetitionStatusPill: View {
    let label: String
    let status: CompetitionStatus

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor.opacity(0.15))
            .foregroundStyle(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch status {
        case .setup: .yellow
        case .active: .green
        case .complete: .secondary
        }
    }
}

struct CreatePoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: PoolType = .racing
    @State private var hasGroupStage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pool name") {
                    TextField("e.g. Grand National 2026", text: $name)
                }
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(PoolType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if type == .knockout {
                    Section {
                        Toggle("Include group stage", isOn: $hasGroupStage)
                    }
                }
            }
            .navigationTitle("New Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let pool = Pool(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            hasGroupStage: hasGroupStage
        )
        modelContext.insert(pool)
        dismiss()
    }
}
