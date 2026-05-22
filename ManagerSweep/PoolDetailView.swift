import SwiftUI
import SwiftData

struct PoolDetailView: View {
    @Bindable var pool: Pool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if pool.type == .racing {
                RacingDetailView(pool: pool)
            } else {
                KnockoutDetailView(pool: pool)
            }
        }
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    pool.status = pool.status.next
                } label: {
                    StatusPill(label: pool.status.displayName, status: pool.status)
                }
            }
        }
    }
}
