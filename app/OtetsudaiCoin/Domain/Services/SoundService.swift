import AVFoundation
import Foundation

enum SoundType: String, CaseIterable {
    case coinEarn = "coin_earn"
    case taskComplete = "task_complete"
    case error = "error"
    
    var filename: String {
        return rawValue + ".wav"
    }
}

protocol SoundServiceProtocol {
    var isMuted: Bool { get }
    var volume: Float { get }
    
    func playCoinEarnSound() throws
    func playTaskCompleteSound() throws
    func playErrorSound() throws
    func setMuted(_ muted: Bool)
    func setVolume(_ volume: Float)
    func soundFileExists(_ soundType: SoundType) -> Bool
}

@MainActor
class SoundService: SoundServiceProtocol {
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private var _isMuted: Bool = false
    private var _volume: Float = 1.0
    
    var isMuted: Bool {
        return _isMuted
    }
    
    var volume: Float {
        return _volume
    }
    
    init() {
        setupAudioSession()
        preloadSounds()
    }
    
    func playCoinEarnSound() throws {
        try playSound(.coinEarn)
    }
    
    func playTaskCompleteSound() throws {
        try playSound(.taskComplete)
    }
    
    func playErrorSound() throws {
        try playSound(.error)
    }
    
    func setMuted(_ muted: Bool) {
        _isMuted = muted
    }
    
    func setVolume(_ volume: Float) {
        _volume = max(0.0, min(1.0, volume))
        updatePlayersVolume()
    }
    
    func soundFileExists(_ soundType: SoundType) -> Bool {
        return Bundle.main.url(forResource: soundType.rawValue, withExtension: "wav") != nil
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func preloadSounds() {
        for soundType in SoundType.allCases {
            do {
                try loadSound(soundType)
            } catch {
                print("Failed to preload sound \(soundType): \(error)")
            }
        }
    }
    
    private func loadSound(_ soundType: SoundType) throws {
        guard let url = Bundle.main.url(forResource: soundType.rawValue, withExtension: "wav") else {
            // テスト環境では音声ファイルがない場合があるので、エラーをスローしない
            return
        }
        
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        player.volume = _volume
        audioPlayers[soundType] = player
    }
    
    private func playSound(_ soundType: SoundType) throws {
        guard !_isMuted else { return }
        
        if let player = audioPlayers[soundType] {
            player.currentTime = 0
            player.play()
        }
    }
    
    private func updatePlayersVolume() {
        for player in audioPlayers.values {
            player.volume = _volume
        }
    }
}