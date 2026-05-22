import SwiftUI
import SwiftData

struct RacingDetailView: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext
    @State private var newRunnerName = ""
    @FocusState private var fieldFocused: Bool

    private var sortedRunners: [Runner] {
        pool.runners.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            addSection
            runnersSection
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var addSection: some View {
        if pool.status == .setup {
            Section("Add runner") {
                HStack {
                    TextField("Runner name", text: $newRunnerName)
                        .focused($fieldFocused)
                        .onSubmit(addRunner)
                    Button("Add", action: addRunner)
                        .disabled(newRunnerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var runnersSection: some View {
        Section("Runners (\(pool.runners.count))") {
            if pool.runners.isEmpty {
                Text("No runners yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedRunners) { runner in
                    RunnerRow(runner: runner, isEditable: pool.status != .complete)
                }
                .onDelete { offsets in
                    guard pool.status == .setup else { return }
                    deleteRunners(at: offsets)
                }
            }
        }
    }

    private func addRunner() {
        let trimmed = newRunnerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let runner = Runner(name: trimmed)
        modelContext.insert(runner)
        pool.runners.append(runner)
        newRunnerName = ""
        fieldFocused = false
    }

    private func deleteRunners(at offsets: IndexSet) {
        let sorted = sortedRunners
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct RunnerRow: View {
    @Bindable var runner: Runner
    let isEditable: Bool

    private var positionLabel: String {
        guard let pos = runner.finishingPosition else { return "No result" }
        return "Pos: \(pos)"
    }

    private var positionBinding: Binding<Int> {
        Binding(
            get: { runner.finishingPosition ?? 0 },
            set: { runner.finishingPosition = $0 > 0 ? $0 : nil }
        )
    }

    var body: some View {
        HStack {
            Text(runner.name)
            Spacer()
            if isEditable {
                editableTrailing
            } else {
                readOnlyTrailing
            }
        }
    }

    @ViewBuilder
    private var editableTrailing: some View {
        Stepper(positionLabel, value: positionBinding, in: 0...99)
            .labelsHidden()
        if let pos = runner.finishingPosition {
            Text("#\(pos)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30)
        }
    }

    @ViewBuilder
    private var readOnlyTrailing: some View {
        if let pos = runner.finishingPosition {
            Text("#\(pos)")
                .font(.subheadline.monospacedDigit().bold())
        }
    }
}
