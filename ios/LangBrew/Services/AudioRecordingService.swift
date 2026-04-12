import AVFoundation
import Foundation

// MARK: - Permission Status

enum MicrophonePermissionStatus: Sendable {
    case notDetermined
    case granted
    case denied
}

// MARK: - Recording Errors

enum AudioRecordingError: Error, LocalizedError, Sendable {
    case permissionDenied
    case recorderSetupFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required for voice input."
        case .recorderSetupFailed:
            return "Could not set up audio recording."
        case .recordingFailed:
            return "Audio recording failed."
        }
    }
}

// MARK: - Audio Recording Service

/// Manages AVAudioRecorder-based recording with tap-to-record / tap-to-stop UX.
/// Produces 16kHz 16-bit PCM mono WAV data suitable for STT upload.
@MainActor
@Observable
final class AudioRecordingService {

    // MARK: - Observable Properties

    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0
    var currentAmplitude: Float = 0
    var permissionStatus: MicrophonePermissionStatus = .notDetermined

    // MARK: - Private State

    private var recorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var meteringTimer: Timer?
    private var recordingStartTime: Date?

    /// Temporary file URL for the recording.
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("langbrew_recording.wav")
    }

    // MARK: - Permission

    /// Requests microphone permission and updates `permissionStatus`.
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionStatus = granted ? .granted : .denied
        return granted
    }

    /// Checks the current microphone permission status without prompting.
    func checkPermissionStatus() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            permissionStatus = .notDetermined
        case .denied:
            permissionStatus = .denied
        case .granted:
            permissionStatus = .granted
        @unknown default:
            permissionStatus = .notDetermined
        }
    }

    // MARK: - Start Recording

    /// Starts audio capture using AVAudioRecorder.
    func startRecording() async throws {
        guard !isRecording else { return }

        // Verify permission
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw AudioRecordingError.permissionDenied
        }

        // Remove any previous recording file
        try? FileManager.default.removeItem(at: recordingURL)

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        // Recording settings: 16kHz, 16-bit, mono PCM (WAV)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let newRecorder: AVAudioRecorder
        do {
            newRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        } catch {
            throw AudioRecordingError.recorderSetupFailed
        }

        newRecorder.isMeteringEnabled = true

        guard newRecorder.record() else {
            throw AudioRecordingError.recordingFailed
        }

        self.recorder = newRecorder
        self.recordingStartTime = Date()
        self.isRecording = true
        self.recordingDuration = 0
        self.currentAmplitude = 0

        // Timer for duration updates
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        // Timer for amplitude metering
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder, self.isRecording else { return }
                recorder.updateMeters()
                // averagePower is in dB, typically -160 (silence) to 0 (max).
                // Normalize to 0-1 range.
                let power = recorder.averagePower(forChannel: 0)
                let normalized = max(0, min(1, (power + 50) / 50))
                self.currentAmplitude = normalized
            }
        }
    }

    // MARK: - Stop Recording

    /// Stops recording and returns WAV data, or nil if the recording was too short.
    func stopRecording() -> Data? {
        guard isRecording, let recorder else { return nil }

        // Stop timers
        durationTimer?.invalidate()
        durationTimer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil

        // Stop recorder
        recorder.stop()
        self.recorder = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Reset state
        let finalDuration = recordingDuration
        isRecording = false
        recordingDuration = 0
        currentAmplitude = 0
        recordingStartTime = nil

        // Check minimum duration
        guard finalDuration >= 0.5 else {
            try? FileManager.default.removeItem(at: recordingURL)
            return nil
        }

        // Read the WAV file
        guard let wavData = try? Data(contentsOf: recordingURL) else {
            return nil
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: recordingURL)

        return wavData
    }
}
