import SwiftUI

/// How the remaining rest is drawn. Persisted so the choice survives launches.
enum CountdownMode: String, CaseIterable {
    case fill
    case squares

    var label: String {
        switch self {
        case .fill:    return "Fill"
        case .squares: return "Squares"
        }
    }

    var icon: String {
        switch self {
        case .fill:    return "square.fill.and.line.vertical.and.square"
        case .squares: return "square.grid.3x3.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var timer: RestTimerModel
    @State private var showingCustom = false
    @AppStorage("countdownMode") private var mode: CountdownMode = .fill

    var body: some View {
        ZStack {
            // At completion the indicator has consumed the screen, so the
            // ground turns over rather than special-casing a flood.
            (timer.finished ? Theme.fill : Theme.surface)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.35), value: timer.finished)

            VStack(spacing: 0) {
                topBar
                indicator
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        Menu {
            Picker("Rest duration", selection: presetBinding) {
                ForEach(RestTimerModel.presets, id: \.self) { seconds in
                    Text(ContentView.format(seconds)).tag(seconds)
                }
            }
            .pickerStyle(.inline)

            Button {
                showingCustom = true
            } label: {
                Label("Custom…", systemImage: "slider.horizontal.3")
            }

            Picker("Style", selection: $mode) {
                ForEach(CountdownMode.allCases, id: \.self) { m in
                    Label(m.label, systemImage: m.icon).tag(m)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 10) {
                Text(timer.displayText)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(numeralColor)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: timer.displayText)
                    .animation(.easeOut(duration: 0.3), value: numeralColor)

                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
        }
        .menuOrder(.fixed)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .sheet(isPresented: $showingCustom) {
            CustomDurationSheet(
                initialSeconds: timer.selectedSeconds,
                onSelect: { seconds in
                    selectDuration(seconds)
                    showingCustom = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    /// Urgency rides on the numeral so the indicator stays one clean mass.
    private var numeralColor: Color {
        if timer.finished { return Theme.onFill }
        switch timer.urgency {
        case .normal:  return Theme.ink
        case .warning: return Theme.warning
        case .urgent:  return Theme.urgent
        }
    }

    // MARK: - Indicator

    @ViewBuilder
    private var indicator: some View {
        Group {
            switch mode {
            case .fill:
                FillIndicator(fraction: elapsedFraction)
            case .squares:
                SquaresIndicator(fraction: elapsedFraction, count: squareCount)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        // Runs to the physical edge so the quarter marks stay evenly spaced
        // and the fill reads as full-bleed.
        .ignoresSafeArea(edges: .bottom)
    }

    private var elapsedFraction: Double {
        1 - timer.progress
    }

    /// One square per second, so the grid's density is itself a reading of
    /// how long the rest is. Long customs step to coarser units to stay legible.
    private var squareCount: Int {
        let unit = max(1, Int(ceil(Double(timer.selectedSeconds) / 400)))
        return max(4, Int(ceil(Double(timer.selectedSeconds) / Double(unit))))
    }

    // MARK: - Actions

    /// One gesture runs the whole rest: tap to start, tap again to restart
    /// from the top.
    private func advance() {
        if timer.isRunning {
            timer.reset()
        } else {
            timer.start()
        }
    }

    /// Changing the duration mid-rest restarts at the new length, so the
    /// numeral and the indicator never describe different rests.
    private func selectDuration(_ seconds: Int) {
        timer.select(seconds: seconds)
        if timer.isRunning { timer.reset() }
    }

    private var presetBinding: Binding<Int> {
        Binding(
            get: { timer.selectedSeconds },
            set: { selectDuration($0) }
        )
    }

    static func format(_ seconds: Int) -> String {
        if seconds % 60 == 0 { return "\(seconds / 60):00" }
        if seconds < 60 { return "0:\(String(format: "%02d", seconds))" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Fill indicator

/// A block of colour rising from the bottom, with quarter marks so progress
/// is readable without doing arithmetic on the numeral.
private struct FillIndicator: View {
    let fraction: Double

    private static let marks: [Double] = [0.25, 0.5, 0.75, 1.0]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.fill)
                    .frame(height: geo.size.height * fraction)
                    // Matches the model's 0.1s tick so the rise reads as
                    // continuous motion rather than a sequence of steps.
                    .animation(.linear(duration: 0.1), value: fraction)

                ForEach(Self.marks, id: \.self) { mark in
                    Rectangle()
                        .fill(Theme.ink.opacity(0.15))
                        .frame(height: 1)
                        .offset(y: -geo.size.height * mark)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Squares indicator

/// The same progress as a mosaic: squares light in a scattered order until
/// the screen is solid.
private struct SquaresIndicator: View {
    let fraction: Double
    let count: Int

    /// Fixed shuffle per grid size. Recomputed only when the size changes, so
    /// squares never rearrange mid-rest.
    @State private var order: [Int] = []

    var body: some View {
        GeometryReader { geo in
            let grid = Self.grid(count: count, size: geo.size)
            let total = grid.cols * grid.rows
            let lit = Int((Double(count) * fraction).rounded())

            Canvas { context, size in
                guard !order.isEmpty else { return }
                let cellW = size.width / Double(grid.cols)
                let cellH = size.height / Double(grid.rows)
                let gap = min(2, min(cellW, cellH) * 0.08)

                for i in 0..<min(lit, order.count) {
                    let index = order[i]
                    let col = index % grid.cols
                    let row = index / grid.cols
                    let rect = CGRect(
                        x: Double(col) * cellW + gap / 2,
                        y: Double(row) * cellH + gap / 2,
                        width: cellW - gap,
                        height: cellH - gap
                    )
                    context.fill(Path(rect), with: .color(Theme.fill))
                }
            }
            .animation(.easeOut(duration: 0.18), value: lit)
            .onAppear { rebuild(total) }
            .onChange(of: total) { newTotal in rebuild(newTotal) }
        }
    }

    private func rebuild(_ total: Int) {
        guard total != order.count else { return }
        order = Array(0..<total).shuffled()
    }

    /// Columns chosen so cells come out close to square for the given area.
    private static func grid(count: Int, size: CGSize) -> (cols: Int, rows: Int) {
        guard size.height > 0, count > 0 else { return (1, 1) }
        let ratio = size.width / size.height
        let cols = max(1, Int((Double(count) * ratio).squareRoot().rounded()))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        return (cols, rows)
    }
}

// MARK: - Palette

/// Neutrals are tinted toward the fill hue rather than sitting at pure black
/// and white, which keeps the screen from looking like a default.
private enum Theme {
    static let fill = Color(red: 0.78, green: 0.95, blue: 0.29)

    static let surface = adaptive(
        light: (0.98, 0.98, 0.96),
        dark:  (0.05, 0.06, 0.05)
    )

    static let ink = adaptive(
        light: (0.07, 0.08, 0.06),
        dark:  (0.95, 0.96, 0.93)
    )

    /// Text on the fill stays dark in both appearances: the fill itself does
    /// not change between them.
    static let onFill = Color(red: 0.07, green: 0.08, blue: 0.06)

    static let warning = Color(red: 0.85, green: 0.52, blue: 0.05)
    static let urgent  = Color(red: 0.86, green: 0.20, blue: 0.18)

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
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
