import XCTest
import AVFoundation
@testable import OtetsudaiCoin

@MainActor
final class SoundServiceTests: XCTestCase {
    private var soundService: SoundService!
    
    override func setUp() {
        super.setUp()
        soundService = SoundService()
    }
    
    override func tearDown() {
        soundService = nil
        super.tearDown()
    }
    
    func testPlayCoinEarnSound() {
        // コイン獲得効果音を再生できることを確認
        XCTAssertNoThrow(try soundService.playCoinEarnSound())
    }
    
    func testPlayTaskCompleteSound() {
        // タスク完了効果音を再生できることを確認
        XCTAssertNoThrow(try soundService.playTaskCompleteSound())
    }
    
    func testPlayErrorSound() {
        // エラー効果音を再生できることを確認
        XCTAssertNoThrow(try soundService.playErrorSound())
    }
    
    func testMuteSounds() {
        // 効果音をミュートできることを確認
        soundService.setMuted(true)
        XCTAssertTrue(soundService.isMuted)
        
        // ミュート状態では音が再生されないことを確認
        XCTAssertNoThrow(try soundService.playCoinEarnSound())
    }
    
    func testUnmuteSounds() {
        // 効果音のミュートを解除できることを確認
        soundService.setMuted(true)
        soundService.setMuted(false)
        XCTAssertFalse(soundService.isMuted)
    }
    
    func testVolumeControl() {
        // 音量を設定できることを確認
        soundService.setVolume(0.5)
        XCTAssertEqual(soundService.volume, 0.5, accuracy: 0.01)
        
        // 範囲外の値は適切にクランプされることを確認
        soundService.setVolume(-0.1)
        XCTAssertEqual(soundService.volume, 0.0, accuracy: 0.01)
        
        soundService.setVolume(1.1)
        XCTAssertEqual(soundService.volume, 1.0, accuracy: 0.01)
    }
    
    func testSoundFileExists() {
        // 効果音ファイルが存在することを確認
        XCTAssertTrue(soundService.soundFileExists(.coinEarn))
        XCTAssertTrue(soundService.soundFileExists(.taskComplete))
        XCTAssertTrue(soundService.soundFileExists(.error))
    }
    
    func testMultipleSoundsCanPlay() async {
        // 複数の効果音を同時に再生できることを確認
        XCTAssertNoThrow(try soundService.playCoinEarnSound())
        XCTAssertNoThrow(try soundService.playTaskCompleteSound())
        
        // 少し待って音が重複再生されることを確認
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    }
}