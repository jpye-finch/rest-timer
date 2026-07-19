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

/// The colour the indicator fills with. Every option is light enough that the
/// countdown, which is always near-black, stays legible sitting on top of it.
enum FillColour: String, CaseIterable {
    case lime, mint, aqua, sky, lilac, pink, coral, amber

    var label: String {
        switch self {
        case .lime:  return "Lime"
        case .mint:  return "Mint"
        case .aqua:  return "Aqua"
        case .sky:   return "Sky"
        case .lilac: return "Lilac"
        case .pink:  return "Pink"
        case .coral: return "Coral"
        case .amber: return "Amber"
        }
    }

    var color: Color {
        switch self {
        case .lime:  return Color(red: 0.78, green: 0.95, blue: 0.29)
        case .mint:  return Color(red: 0.44, green: 0.93, blue: 0.68)
        case .aqua:  return Color(red: 0.36, green: 0.86, blue: 0.91)
        case .sky:   return Color(red: 0.55, green: 0.78, blue: 1.00)
        case .lilac: return Color(red: 0.74, green: 0.66, blue: 0.99)
        case .pink:  return Color(red: 1.00, green: 0.62, blue: 0.82)
        case .coral: return Color(red: 1.00, green: 0.58, blue: 0.45)
        case .amber: return Color(red: 1.00, green: 0.80, blue: 0.25)
        }
    }

    /// Menus render template images by default, so a swatch has to be drawn
    /// and handed over with its original colours intact.
    var swatch: UIImage {
        let side = 22.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor(color).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2)
            )
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

struct ContentView: View {
    @EnvironmentObject private var timer: RestTimerModel
    @State private var showingCustom = false
    @AppStorage("countdownMode") private var mode: CountdownMode = .fill
    @AppStorage("fillColour") private var fillColour: FillColour = .lime

    var body: some View {
        ZStack(alignment: .top) {
            // Squares leave gaps between cells, so the ground turns over at
            // completion to make the flood solid in both styles.
            (timer.finished ? fillColour.color : Theme.surface)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.35), value: timer.finished)

            indicator
                .ignoresSafeArea()

            topBar
        }
        // The fill is the surface, and dark text has to read on it at any
        // height, so this screen commits to one appearance.
        .preferredColorScheme(.light)
    }

    // MARK: - Top bar

    private var topBar: some View {
        // Buttons throughout rather than Pickers: a Picker ignores a tap on
        // the value already selected, and two Pickers in one Menu left the
        // second selection unwritten. The headers also push the first row
        // clear of the countdown, which the menu opens directly on top of.
        Menu {
            Section("Rest length") {
                ForEach(RestTimerModel.presets, id: \.self) { seconds in
                    Button {
                        selectDuration(seconds)
                    } label: {
                        if timer.selectedSeconds == seconds {
                            Label(ContentView.format(seconds), systemImage: "checkmark")
                        } else {
                            Text(ContentView.format(seconds))
                        }
                    }
                }

                Button {
                    showingCustom = true
                } label: {
                    Label("Custom…", systemImage: "slider.horizontal.3")
                }
            }

            // Submenus keep appearance out of the way of the durations, which
            // are the rows actually reached mid-workout.
            Section {
                Menu {
                    ForEach(CountdownMode.allCases, id: \.self) { style in
                        Button {
                            mode = style
                        } label: {
                            Label(
                                style.label,
                                systemImage: mode == style ? "checkmark" : style.icon
                            )
                        }
                    }
                } label: {
                    Label("Style", systemImage: mode.icon)
                }

                Menu {
                    ForEach(FillColour.allCases, id: \.self) { colour in
                        Button {
                            fillColour = colour
                        } label: {
                            if fillColour == colour {
                                Label(colour.label, systemImage: "checkmark")
                            } else {
                                Label {
                                    Text(colour.label)
                                } icon: {
                                    Image(uiImage: colour.swatch)
                                }
                            }
                        }
                    }
                } label: {
                    Label {
                        Text("Colour")
                    } icon: {
                        Image(uiImage: fillColour.swatch)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(timer.displayText)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: timer.displayText)

                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
        }
        .menuOrder(.fixed)
        .padding(.top, 8)
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

    // MARK: - Indicator

    @ViewBuilder
    private var indicator: some View {
        Group {
            switch mode {
            case .fill:
                FillIndicator(fraction: elapsedFraction, colour: fillColour.color)
            case .squares:
                SquaresIndicator(
                    fraction: elapsedFraction,
                    count: squareCount,
                    colour: fillColour.color
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
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

    /// Picking a length mid-rest restarts at that length, including when it
    /// is the one already selected, so the menu always means "rest this long,
    /// starting now".
    private func selectDuration(_ seconds: Int) {
        timer.select(seconds: seconds)
        if timer.isRunning { timer.reset() }
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
    let colour: Color

    /// Quarter marks only. The screen's own edges bound the run, so lines at
    /// 0 and 100% would just be borders.
    private static let marks: [Double] = [0.25, 0.5, 0.75]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(colour)
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
    let colour: Color

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
                    context.fill(Path(rect), with: .color(colour))
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
    static let surface = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let ink     = Color(red: 0.07, green: 0.08, blue: 0.07)
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
