#if canImport(UIKit)
import UIKit
import AVFoundation
import AudioToolbox
import vBoardEngine

/// Quản lý âm thanh khi gõ phím với khả năng điều chỉnh âm lượng chuẩn xác theo soundVolume
public final class SoundManager: @unchecked Sendable {
    public static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?
    private var lastVolume: Float = -1.0

    private init() {
        preparePlayer()
    }

    /// Chuẩn bị AudioPlayer với âm thanh phím gõ click tối ưu trong bộ nhớ
    private func preparePlayer() {
        guard audioPlayer == nil else { return }
        // Tạo âm thanh click phím (20ms, 44.1kHz, 16-bit PCM) hoàn toàn trong bộ nhớ (chỉ ~1.8KB)
        let sampleRate: Double = 44100.0
        let duration: Double = 0.020
        let numSamples = Int(sampleRate * duration)
        var pcmData = Data()

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let env = exp(-t * 220.0)
            let freq = 1400.0 * exp(-t * 50.0)
            let val = sin(2.0 * .pi * freq * t) * env
            let intVal = Int16(max(-32767.0, min(32767.0, val * 32767.0 * 0.95)))
            var s = intVal.littleEndian
            pcmData.append(Data(bytes: &s, count: 2))
        }

        var wavData = Data()
        wavData.append(contentsOf: "RIFF".utf8)
        var totalSize = UInt32(36 + pcmData.count).littleEndian
        wavData.append(Data(bytes: &totalSize, count: 4))
        wavData.append(contentsOf: "WAVEfmt ".utf8)
        var subchunk1 = UInt32(16).littleEndian
        wavData.append(Data(bytes: &subchunk1, count: 4))
        var audioFormat = UInt16(1).littleEndian
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var channels = UInt16(1).littleEndian
        wavData.append(Data(bytes: &channels, count: 2))
        var sRate = UInt32(sampleRate).littleEndian
        wavData.append(Data(bytes: &sRate, count: 4))
        var byteRate = UInt32(sampleRate * 2).littleEndian
        wavData.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = UInt16(2).littleEndian
        wavData.append(Data(bytes: &blockAlign, count: 2))
        var bits = UInt16(16).littleEndian
        wavData.append(Data(bytes: &bits, count: 2))
        wavData.append(contentsOf: "data".utf8)
        var dataSize = UInt32(pcmData.count).littleEndian
        wavData.append(Data(bytes: &dataSize, count: 4))
        wavData.append(pcmData)

        do {
            let player = try AVAudioPlayer(data: wavData)
            player.prepareToPlay()
            self.audioPlayer = player
        } catch {
            self.audioPlayer = nil
        }
    }

    /// Phát âm thanh gõ phím, áp dụng âm lượng từ vBoardSettings.shared.soundVolume
    public func playKeyClick() {
        guard vBoardSettings.shared.isKeySoundEnabled else { return }

        let volume = max(0.05, min(1.0, vBoardSettings.shared.soundVolume))
        if let player = audioPlayer {
            if lastVolume != volume {
                player.volume = volume
                lastVolume = volume
            }
            if player.isPlaying {
                player.currentTime = 0
            }
            player.play()
        } else {
            // Fallback âm thanh click mặc định của hệ thống iOS
            AudioServicesPlaySystemSound(1104)
        }
    }
}
#endif
