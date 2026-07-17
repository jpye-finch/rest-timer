import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var timer: RestTimerModel
    @State private var showingCustom = false

    var body: some View {
        ZStack {
            // Adapts automatically to light / dark appearance.
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 40) {
                presetPills

                Spacer(minLength: 0)

                timerDial

                Spacer(minLength: 0)

                controls
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingCustom) {
            CustomDurationSheet(
                initialSeconds: timer.selectedSeconds,
                onSelect: { seconds in
                    timer.select(seconds: seconds)
                    showingCustom = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Ring colour (mirrors the artifact: green → amber ≤20s → red ≤10s)

    private var ringColor: Color {
        if timer.finished { return .accentColor }
        switch timer.urgency {
        case .normal:  return .accentColor
        case .warning: return .orange
        case .urgent:  return .red
        }
    }

    private var statusText: String {
        if timer.finished { return "GO" }
        if timer.isRunning { return "RESTING" }
        if timer.progress < 1 { return "PAUSED" }
        return "TAP TO START"
    }

    // MARK: - Preset pills

    private var presetPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RestTimerModel.presets, id: \.self) { seconds in
                    Pill(
                        label: "\(seconds)s",
                        isSelected: timer.selectedSeconds == seconds,
                        action: { timer.select(seconds: seconds) }
                    )
                }
                Pill(
                    label: timer.isCustomSelection ? ContentView.format(timer.selectedSeconds) : "Custom",
                    isSelected: timer.isCustomSelection,
                    isDashed: true,
                    action: { showingCustom = true }
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Dial

    private var timerDial: some View {
        Button {
            timer.toggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: timer.progress)
                    .animation(.easeInOut(duration: 0.3), value: ringColor)

                VStack(spacing: 10) {
                    Text(timer.displayText)
                        .font(.system(size: 76, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.finished ? Color.accentColor : .primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: timer.displayText)

                    Text(statusText)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(timer.finished ? Color.accentColor : .secondary)
                }
            }
            .frame(width: 280, height: 280)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 24) {
            IconButton(system: "stop.fill") { timer.clear() }
                .disabled(!timer.isRunning && !timer.finished && timer.progress == 1)

            IconButton(system: timer.isRunning ? "pause.fill" : "play.fill", prominent: true) {
                timer.toggle()
            }

            IconButton(system: "arrow.counterclockwise") { timer.reset() }
        }
    }

    // MARK: - Helpers

    static func format(_ seconds: Int) -> String {
        if seconds % 60 == 0 { return "\(seconds / 60):00" }
        if seconds < 60 { return "0:\(String(format: "%02d", seconds))" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Preset pill

private struct Pill: View {
    let label: String
    let isSelected: Bool
    var isDashed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .tracking(0.5)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.5, dash: isDashed && !isSelected ? [4] : [])
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Circular icon button

private struct IconButton: View {
    let system: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: prominent ? 28 : 20, weight: .medium))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(width: prominent ? 76 : 58, height: prominent ? 76 : 58)
                .background(
                    Circle().fill(prominent ? Color.accentColor : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Custom duration sheet

private struct CustomDurationSheet: View {
    let initialSeconds: Int
    let onSelect: (Int) -> Void

    @State private var minutes: Int
    @State private var seconds: Int

    init(initialSeconds: Int, onSelect: @escaping (Int) -> Void) {
        self.initialSeconds = initialSeconds
        self.onSelect = onSelect
        _minutes = State(initialValue: initialSeconds / 60)
        _seconds = State(initialValue: initialSeconds % 60)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)

                Picker("Seconds", selection: $seconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) {
                        Text("\($0) sec").tag($0)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal)
            .navigationTitle("Custom Rest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") { onSelect(max(1, minutes * 60 + seconds)) }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(RestTimerModel())
}
