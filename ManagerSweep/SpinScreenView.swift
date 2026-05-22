import SwiftUI

struct SpinScreenView: View {
    let entry: Entry
    let options: [String]
    let onAssign: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: SpinPhase = .ready
    @State private var displayedName: String = ""
    @State private var spinTask: Task<Void, Never>?

    private let predeterminedResult: String

    enum SpinPhase {
        case ready, spinning, revealed
    }

    init(entry: Entry, options: [String], onAssign: @escaping (String) -> Void) {
        self.entry = entry
        self.options = options
        self.onAssign = onAssign
        self.predeterminedResult = options.randomElement() ?? ""
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text(entry.playerName)
                .font(.title2.bold())
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(phase == .revealed ? Color.green : Color.clear, lineWidth: 3)
                    )

                if phase == .ready {
                    Text("Press Spin")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text(displayedName.isEmpty ? "…" : displayedName)
                        .font(.title.bold())
                        .foregroundStyle(phase == .revealed ? .green : .primary)
                        .animation(.easeInOut(duration: 0.1), value: displayedName)
                }
            }
            .padding(.horizontal, 40)

            if phase == .revealed {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Assigned!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Group {
                switch phase {
                case .ready:
                    Button(action: startSpin) {
                        Text("SPIN")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(options.isEmpty)
                case .spinning:
                    Text("Spinning…")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                case .revealed:
                    Button(action: finish) {
                        Text("Done")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            displayedName = options.first ?? ""
        }
        .onDisappear {
            spinTask?.cancel()
        }
    }

    private func startSpin() {
        guard !options.isEmpty else { return }
        phase = .spinning

        spinTask = Task {
            let totalFrames = 48
            for frame in 0..<totalFrames {
                if Task.isCancelled { break }
                let isLast = frame == totalFrames - 1
                let name = isLast ? predeterminedResult : options.randomElement()!
                let delay = frameDelay(frame: frame, total: totalFrames)

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { break }

                displayedName = name

                if isLast {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        phase = .revealed
                    }
                }
            }
        }
    }

    private func frameDelay(frame: Int, total: Int) -> Double {
        let progress = Double(frame) / Double(total)
        // Start fast (0.04s), ease to slow (0.25s) near the end
        let base = 0.04
        let slow = 0.25
        if progress < 0.6 { return base }
        let t = (progress - 0.6) / 0.4
        return base + (slow - base) * t * t
    }

    private func finish() {
        onAssign(predeterminedResult)
        dismiss()
    }
}
