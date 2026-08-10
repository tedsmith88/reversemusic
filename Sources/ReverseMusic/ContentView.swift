import SwiftUI
import AVFoundation

// MARK: - Colors & Theme

extension Color {
    static let bg          = Color(hex: "0D0D0D")
    static let surface     = Color(hex: "1C1C1E")
    static let surfaceHigh = Color(hex: "2C2C2E")
    static let accent      = Color(hex: "BF5AF2")
    static let accentRed   = Color(hex: "FF453A")
    static let accentGreen = Color(hex: "32D74B")
    static let textPrimary = Color.white
    static let textMuted   = Color(hex: "8E8E93")
    static let separator   = Color(hex: "38383A")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Button Styles

struct PrimaryBtn: ButtonStyle {
    var color: Color = .accent
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(disabled ? Color.surfaceHigh : color.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryBtn: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surfaceHigh.opacity(configuration.isPressed ? 0.7 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shared Components

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.surface))
    }
}

struct SectionLabel: View {
    let icon: String
    let title: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accent)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.surfaceHigh))
            }
        }
    }
}

struct WaveformView: View {
    let level: Float
    private let barCount = 24
    @State private var heights: [CGFloat] = Array(repeating: 4, count: 24)
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.accentRed)
                    .frame(width: 3, height: heights[i])
                    .animation(.easeInOut(duration: 0.12), value: heights[i])
            }
        }
        .frame(height: 50)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let l = Double(level)
                heights = (0..<barCount).map { _ in
                    CGFloat(4.0 + (46.0) * l * Double.random(in: 0.4...1.0))
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct PlaybackWave: View {
    let isPlaying: Bool
    @State private var phase: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(Color.accent)
                    .frame(width: 3, height: barH(i))
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .frame(height: 40)
        .onChange(of: isPlaying) { playing in
            if playing {
                timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                    phase += 0.4
                }
            } else {
                timer?.invalidate()
                timer = nil
                phase = 0
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func barH(_ i: Int) -> CGFloat {
        if !isPlaying { return 4 }
        let x = Double(i) / 24.0 * .pi * 2
        return CGFloat(8 + 24 * abs(sin(x + Double(phase))))
    }
}

struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.accent)
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textMuted)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.surface))
        }
    }
}

func formatTime(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            Group {
                switch vm.phase {
                case .setup:           SetupView(vm: vm)
                case .roundIntro:      RoundIntroView(vm: vm)
                case .singerRecording: SingerRecordingView(vm: vm)
                case .listenerTurn:    ListenerTurnView(vm: vm)
                case .reveal:          RevealView(vm: vm)
                case .guess:           GuessView(vm: vm)
                case .roundComplete:   RoundCompleteView(vm: vm)
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))

            if vm.isProcessing {
                ProcessingOverlay(message: vm.processingMessage)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.phase)
        .animation(.easeInOut(duration: 0.2), value: vm.isProcessing)
        .frame(minWidth: 580, minHeight: 680)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Setup View

struct SetupView: View {
    @ObservedObject var vm: GameViewModel
    @FocusState private var focused: Field?

    enum Field { case p1, p2 }

    private var canStart: Bool {
        !vm.player1Name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !vm.player2Name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / Title
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accent.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.accent)
                }
                Text("Reverse Music")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("Sing it. Reverse it. Guess it.")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
            }
            .padding(.bottom, 48)

            // Player fields
            VStack(spacing: 16) {
                PlayerField(label: "Player 1", placeholder: "Enter name...",
                            text: $vm.player1Name, focused: $focused, field: .p1) {
                    focused = .p2
                }
                PlayerField(label: "Player 2", placeholder: "Enter name...",
                            text: $vm.player2Name, focused: $focused, field: .p2) {
                    if canStart { vm.startGame() }
                }
            }
            .padding(.horizontal, 60)

            Spacer().frame(height: 32)

            // Start button
            Button("Start Game") {
                vm.startGame()
            }
            .buttonStyle(PrimaryBtn())
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.35)
            .padding(.horizontal, 60)

            Spacer()

            // Instructions
            VStack(spacing: 6) {
                Text("How to play")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .padding(.bottom, 4)
                ForEach([
                    ("1", "Singer records a secret song"),
                    ("2", "Listener hears it in reverse"),
                    ("3", "Listener mimics & records the reversed audio"),
                    ("4", "Listener's recording is reversed — sounds like original!"),
                    ("5", "Listener guesses the song. Then swap!")
                ], id: \.0) { step, text in
                    HStack(alignment: .top, spacing: 10) {
                        Text(step)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accent)
                            .frame(width: 16)
                        Text(text)
                            .font(.system(size: 11))
                            .foregroundColor(.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlayerField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<SetupView.Field?>.Binding
    let field: SetupView.Field
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focused.wrappedValue == field ? Color.accent : Color.separator, lineWidth: 1)
                        )
                )
                .focused(focused, equals: field)
                .onSubmit(onSubmit)
        }
    }
}

// MARK: - Round Intro View

struct RoundIntroView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Round \(vm.currentRound)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.surface))
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 32) {
                // Singer card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentRed.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.accentRed)
                    }
                    Text(vm.singerName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("sings this round")
                        .font(.system(size: 15))
                        .foregroundColor(.textMuted)
                }

                // Divider with swap icon
                HStack(spacing: 12) {
                    Rectangle().fill(Color.separator).frame(height: 1)
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.textMuted)
                        .font(.system(size: 13))
                    Rectangle().fill(Color.separator).frame(height: 1)
                }
                .padding(.horizontal, 20)

                // Listener card
                VStack(spacing: 6) {
                    Text(vm.listenerName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("will listen & guess")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                }
            }
            .padding(.horizontal, 60)

            Spacer()

            VStack(spacing: 12) {
                Text("Only \(vm.singerName) should look at the screen now.")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)

                Button("Let's Go!") {
                    vm.phase = .singerRecording
                }
                .buttonStyle(PrimaryBtn())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Singer Recording View

enum SingerState { case idle, recording, done }

struct SingerRecordingView: View {
    @ObservedObject var vm: GameViewModel
    @State private var state: SingerState = .idle

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Round \(vm.currentRound)  ·  Singer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textMuted)
                    Text(vm.singerName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Divider().background(Color.separator)

            Spacer()

            // Main content
            VStack(spacing: 28) {
                switch state {
                case .idle:
                    idleContent
                case .recording:
                    recordingContent
                case .done:
                    doneContent
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var idleContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.accentRed.opacity(0.8))
                Text("Sing a Song")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("\(vm.listenerName) will hear it in reverse\nand try to guess the song!")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
            }

            Button {
                vm.beginSingerRecording()
                state = .recording
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(Color.accentRed).frame(width: 10, height: 10)
                    Text("Start Recording")
                }
            }
            .buttonStyle(PrimaryBtn(color: .accentRed))
        }
    }

    var recordingContent: some View {
        VStack(spacing: 20) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentRed)
                    .frame(width: 8, height: 8)
                    .opacity(0.9)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: vm.audio.elapsedSeconds)
                Text("Recording")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentRed)
            }

            WaveformView(level: vm.audio.micLevel)

            Text(formatTime(vm.audio.elapsedSeconds))
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundColor(.textPrimary)


            Button {
                vm.stopSingerRecording()
                state = .done
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text("Stop Recording")
                }
            }
            .buttonStyle(PrimaryBtn(color: .accentRed))
        }
    }

    var doneContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentGreen)
                Text("Recorded!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("Play it back to check, then hand the device to \(vm.listenerName).")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
            }

            if let url = vm.singerRecordingURL {
                Button {
                    if vm.audio.isPlaying {
                        vm.audio.stopPlayback()
                    } else {
                        vm.audio.play(url: url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.audio.isPlaying ? "pause.fill" : "play.fill")
                        Text(vm.audio.isPlaying ? "Pause" : "Play Recording")
                    }
                }
                .buttonStyle(SecondaryBtn())
            }

            Button("Done — Pass to \(vm.listenerName)") {
                vm.doneSinging()
            }
            .buttonStyle(PrimaryBtn())

            Button("Record Again") {
                vm.beginSingerRecording()
                state = .recording
            }
            .buttonStyle(SecondaryBtn())
        }
    }
}

// MARK: - Listener Turn View

enum ListenerRecordState { case idle, recording, done }

struct ListenerTurnView: View {
    @ObservedObject var vm: GameViewModel
    @State private var listenCount = 0
    @State private var recordState: ListenerRecordState = .idle
    @State private var recordCount = 0

    private var canReveal: Bool { listenCount > 0 && recordState == .done }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Round \(vm.currentRound)  ·  Listener")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textMuted)
                    Text(vm.listenerName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider().background(Color.separator)

            ScrollView {
                VStack(spacing: 16) {
                    // Step 1: Listen
                    Card {
                        SectionLabel(
                            icon: "headphones",
                            title: "Listen to the reversed song",
                            badge: listenCount > 0 ? "\(listenCount)x" : nil
                        )
                        Text("This is what you need to mimic with your voice. Listen as many times as you need!")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)

                        if vm.audio.isPlaying {
                            PlaybackWave(isPlaying: vm.audio.isPlaying)
                        }

                        Button {
                            if vm.audio.isPlaying {
                                vm.audio.stopPlayback()
                            } else if let url = vm.reversedSingerURL {
                                vm.audio.play(url: url) {}
                                listenCount += 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: vm.audio.isPlaying ? "pause.fill" : "play.fill")
                                Text(vm.audio.isPlaying ? "Pause" : listenCount == 0 ? "Play Reversed Song" : "Play Again")
                            }
                        }
                        .buttonStyle(PrimaryBtn())
                    }

                    // Step 2: Record
                    Card {
                        SectionLabel(
                            icon: "waveform",
                            title: "Record your mimic",
                            badge: recordCount > 0 ? "\(recordCount) attempt\(recordCount == 1 ? "" : "s")" : nil
                        )
                        Text("Try to recreate exactly what you heard. Record multiple times until it sounds right!")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)

                        if recordState == .recording {
                            VStack(spacing: 12) {
                                WaveformView(level: vm.audio.micLevel)
                                Text(formatTime(vm.audio.elapsedSeconds))
                                    .font(.system(size: 28, weight: .light, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                                Button {
                                    vm.stopListenerRecording()
                                    recordState = .done
                                    recordCount += 1
                                } label: {
                                    HStack(spacing: 8) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white)
                                            .frame(width: 10, height: 10)
                                        Text("Stop Recording")
                                    }
                                }
                                .buttonStyle(PrimaryBtn(color: .accentRed))
                            }
                        } else {
                            VStack(spacing: 10) {
                                Button {
                                    vm.beginListenerRecording()
                                    recordState = .recording
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle().fill(Color.accentRed).frame(width: 10, height: 10)
                                        Text(recordState == .done ? "Record Again" : "Start Recording")
                                    }
                                }
                                .buttonStyle(PrimaryBtn(color: .accentRed))

                                if recordState == .done, let url = vm.listenerRecordingURL {
                                    Button {
                                        if vm.audio.isPlaying {
                                            vm.audio.stopPlayback()
                                        } else {
                                            vm.audio.play(url: url)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: vm.audio.isPlaying ? "pause.fill" : "play.fill")
                                            Text(vm.audio.isPlaying ? "Pause" : "Play Your Recording")
                                        }
                                    }
                                    .buttonStyle(SecondaryBtn())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }

            Divider().background(Color.separator)

            // Reveal button
            VStack(spacing: 8) {
                if !canReveal {
                    Text(listenCount == 0 ? "Listen to the reversed song first" : "Record your attempt first")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                }
                Button {
                    vm.proceedToReveal()
                } label: {
                    HStack(spacing: 8) {
                        Text("Reveal")
                        Image(systemName: "wand.and.stars")
                    }
                }
                .buttonStyle(PrimaryBtn(disabled: !canReveal))
                .disabled(!canReveal)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reveal View

struct RevealView: View {
    @ObservedObject var vm: GameViewModel
    @State private var hasPlayed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accent.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 34))
                            .foregroundColor(.accent)
                    }
                    Text("Reveal Time!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Hear \(vm.listenerName)'s recording reversed.\nDoes it sound like a song?")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                        .multilineTextAlignment(.center)
                }

                Card {
                    SectionLabel(icon: "arrow.triangle.2.circlepath", title: "Reversed Recording")
                    Text("This is \(vm.listenerName)'s recording, reversed.")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)

                    if vm.audio.isPlaying {
                        PlaybackWave(isPlaying: vm.audio.isPlaying)
                    }

                    Button {
                        if vm.audio.isPlaying {
                            vm.audio.stopPlayback()
                        } else if let url = vm.reversedListenerURL {
                            vm.audio.play(url: url) {}
                            hasPlayed = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: vm.audio.isPlaying ? "pause.fill" : "play.fill")
                            Text(vm.audio.isPlaying ? "Pause" : hasPlayed ? "Play Again" : "Play Reveal")
                        }
                    }
                    .buttonStyle(PrimaryBtn())
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    vm.proceedToGuess()
                } label: {
                    HStack(spacing: 8) {
                        Text("Time to Guess")
                        Image(systemName: "questionmark.bubble.fill")
                    }
                }
                .buttonStyle(PrimaryBtn(disabled: !hasPlayed))
                .disabled(!hasPlayed)

                if !hasPlayed {
                    Text("Play the reveal first")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Guess View

struct GuessView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("🎵")
                        .font(.system(size: 48))
                    Text("What was the song?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("\(vm.listenerName), make your guess!")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                }

                Card {
                    SectionLabel(icon: "arrow.triangle.2.circlepath", title: "Your reversed recording")
                    if vm.audio.isPlaying {
                        PlaybackWave(isPlaying: vm.audio.isPlaying)
                    }
                    if let url = vm.reversedListenerURL {
                        Button {
                            if vm.audio.isPlaying {
                                vm.audio.stopPlayback()
                            } else {
                                vm.audio.play(url: url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: vm.audio.isPlaying ? "pause.fill" : "play.fill")
                                Text(vm.audio.isPlaying ? "Pause" : "Play Again")
                            }
                        }
                        .buttonStyle(SecondaryBtn())
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    vm.resolveRound(won: false)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Give Up")
                    }
                }
                .buttonStyle(PrimaryBtn(color: Color.surfaceHigh))

                Button {
                    vm.resolveRound(won: true)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("I Got It!")
                    }
                }
                .buttonStyle(PrimaryBtn(color: .accentGreen))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Round Complete View

struct RoundCompleteView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Quit") { vm.quitToSetup() }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 24) {
                // Result
                VStack(spacing: 12) {
                    if let won = vm.lastRoundWon {
                        Text(won ? "Round Complete - Got It!" : "Round Complete - Better Luck Next Time!")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(won
                             ? "\(vm.listenerName) guessed \(vm.singerName)'s song!"
                             : "\(vm.listenerName) didn't get it this time.")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Round \(vm.currentRound) Complete!")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.textPrimary)
                    }
                }

                // Next round info
                Card {
                    SectionLabel(icon: "arrow.2.squarepath", title: "Next Round")
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.accentRed)
                            .font(.system(size: 13))
                        Text("\(vm.singerIsPlayer1 ? vm.player2Name : vm.player1Name)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("will sing next")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    vm.nextRound()
                } label: {
                    HStack(spacing: 8) {
                        Text("Next Round")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(PrimaryBtn())

                Button("End Game") {
                    vm.quitToSetup()
                }
                .buttonStyle(SecondaryBtn())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
