import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            SweepsTab()
                .tabItem { Label("Sweeps", systemImage: "trophy.fill") }
            PoolsTab()
                .tabItem { Label("Pools", systemImage: "rectangle.3.group.fill") }
            PlayersTab()
                .tabItem { Label("Players", systemImage: "person.2.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Pool.self, Runner.self, Team.self, TournamentGroup.self,
            GroupMatch.self, KnockoutStage.self, KnockoutMatch.self,
            Competition.self, PrizePosition.self, Player.self,
            Entry.self, CompetitionResult.self,
        ], inMemory: true)
}
