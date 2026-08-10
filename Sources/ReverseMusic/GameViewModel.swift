import Foundation
import Combine

enum GamePhase: Equatable {
    case setup
    case roundIntro
    case singerRecording
    case listenerTurn
    case reveal
    case guess
    case roundComplete
}

class GameViewModel: ObservableObject {
    @Published var phase: GamePhase = .setup
    @Published var player1Name: String = ""
    @Published var player2Name: String = ""
    @Published var currentRound: Int = 1
    @Published var singerIsPlayer1: Bool = true
    @Published var isProcessing: Bool = false
    @Published var processingMessage: String = ""
    @Published var lastRoundWon: Bool? = nil

    var singerRecordingURL: URL?
    var reversedSingerURL: URL?
    var listenerRecordingURL: URL?
    var reversedListenerURL: URL?

    let audio: AudioManager
    private var audioCancellable: AnyCancellable?

    init() {
        audio = AudioManager()
        // Forward AudioManager's published changes so views observing this VM re-render
        audioCancellable = audio.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var singerName: String { singerIsPlayer1 ? player1Name : player2Name }
    var listenerName: String { singerIsPlayer1 ? player2Name : player1Name }

    func startGame() {
        let p1 = player1Name.trimmingCharacters(in: .whitespaces)
        let p2 = player2Name.trimmingCharacters(in: .whitespaces)
        guard !p1.isEmpty, !p2.isEmpty else { return }
        player1Name = p1
        player2Name = p2
        currentRound = 1
        singerIsPlayer1 = true
        phase = .roundIntro
    }

    func beginSingerRecording() {
        audio.startRecording(filename: "singer_r\(currentRound).wav")
        phase = .singerRecording
    }

    func stopSingerRecording() {
        singerRecordingURL = audio.stopRecording()
    }

    func doneSinging() {
        guard let url = singerRecordingURL else { return }
        isProcessing = true
        processingMessage = "Reversing your song..."
        let audioMgr = audio
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let reversed = try audioMgr.reverseAudio(inputURL: url)
                DispatchQueue.main.async {
                    self?.reversedSingerURL = reversed
                    self?.isProcessing = false
                    self?.phase = .listenerTurn
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    print("Reverse error: \(error)")
                }
            }
        }
    }

    func beginListenerRecording() {
        audio.stopPlayback()
        audio.startRecording(filename: "listener_r\(currentRound).wav")
    }

    func stopListenerRecording() {
        listenerRecordingURL = audio.stopRecording()
    }

    func proceedToReveal() {
        guard let url = listenerRecordingURL else { return }
        audio.stopPlayback()
        isProcessing = true
        processingMessage = "Preparing the reveal..."
        let audioMgr = audio
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let reversed = try audioMgr.reverseAudio(inputURL: url)
                DispatchQueue.main.async {
                    self?.reversedListenerURL = reversed
                    self?.isProcessing = false
                    self?.phase = .reveal
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    print("Reverse error: \(error)")
                }
            }
        }
    }

    func proceedToGuess() {
        audio.stopPlayback()
        phase = .guess
    }

    func resolveRound(won: Bool) {
        audio.stopPlayback()
        lastRoundWon = won
        phase = .roundComplete
    }

    func nextRound() {
        audio.stopPlayback()
        currentRound += 1
        singerIsPlayer1.toggle()
        singerRecordingURL = nil
        reversedSingerURL = nil
        listenerRecordingURL = nil
        reversedListenerURL = nil
        lastRoundWon = nil
        phase = .roundIntro
    }

    func quitToSetup() {
        audio.stopPlayback()
        audio.stopRecording()
        currentRound = 1
        singerIsPlayer1 = true
        singerRecordingURL = nil
        reversedSingerURL = nil
        listenerRecordingURL = nil
        reversedListenerURL = nil
        lastRoundWon = nil
        phase = .setup
    }
}
