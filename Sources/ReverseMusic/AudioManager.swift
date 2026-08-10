import Foundation
import AVFoundation

enum AudioError: LocalizedError {
    case failedToCreateBuffer
    case failedToAccessChannelData

    var errorDescription: String? {
        switch self {
        case .failedToCreateBuffer: return "Failed to create audio buffer"
        case .failedToAccessChannelData: return "Failed to access audio channel data"
        }
    }
}

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var micLevel: Float = 0.0
    @Published var elapsedSeconds: Int = 0
    @Published var permissionGranted = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var levelTimer: Timer?
    private var countTimer: Timer?
    private var playCompletion: (() -> Void)?

    let tempDir: URL

    override init() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReverseMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
        super.init()
        checkPermission()
    }

    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        permissionGranted = (status == .authorized)
    }

    func startRecording(filename: String) {
        let url = tempDir.appendingPathComponent(filename)

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            doStartRecording(url: url)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.doStartRecording(url: url) }
                }
            }
        default:
            break
        }
    }

    private func doStartRecording(url: URL) {
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            if recorder?.record() == true {
                isRecording = true
                elapsedSeconds = 0
                startTimers()
            }
        } catch {
            print("Recording failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func stopRecording() -> URL? {
        stopTimers()
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        isRecording = false
        micLevel = 0
        return url
    }

    func play(url: URL, completion: (() -> Void)? = nil) {
        stopPlayback()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            playCompletion = completion
            player?.play()
            isPlaying = true
        } catch {
            print("Playback failed: \(error)")
            completion?()
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        playCompletion = nil
    }

    func reverseAudio(inputURL: URL) throws -> URL {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioError.failedToCreateBuffer
        }
        try inputFile.read(into: buffer)
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            throw AudioError.failedToAccessChannelData
        }

        let numChannels = Int(format.channelCount)
        let numFrames = Int(frameCount)
        for c in 0..<numChannels {
            var left = 0
            var right = numFrames - 1
            while left < right {
                let tmp = channelData[c][left]
                channelData[c][left] = channelData[c][right]
                channelData[c][right] = tmp
                left += 1
                right -= 1
            }
        }

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = tempDir.appendingPathComponent("\(baseName)_reversed.caf")
        try? FileManager.default.removeItem(at: outputURL)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: true
        ]

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        try outputFile.write(from: buffer)
        return outputURL
    }

    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recorder?.updateMeters()
            let power = self.recorder?.averagePower(forChannel: 0) ?? -80
            let normalized = Float(max(0.0, min(1.0, (Double(power) + 70.0) / 70.0)))
            self.micLevel = normalized
        }
        countTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate(); levelTimer = nil
        countTimer?.invalidate(); countTimer = nil
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimers()
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playCompletion?()
            self.playCompletion = nil
        }
    }
}
