import SwiftUI
import SwiftData

struct PlayersTab: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Environment(\.modelContext) private var modelContext
    @State private var newName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Player name", text: $newName)
                            .focused($fieldFocused)
                            .onSubmit(addPlayer)
                        Button("Add", action: addPlayer)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if players.isEmpty {
                    ContentUnavailableView(
                        "No Players",
                        systemImage: "person.2",
                        description: Text("Add players above to include them in sweeps.")
                    )
                } else {
                    Section {
                        ForEach(players) { player in
                            Text(player.name)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Players")
            .toolbar {
                EditButton()
            }
        }
    }

    private func addPlayer() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Player(name: trimmed))
        newName = ""
        fieldFocused = false
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
    }
}
