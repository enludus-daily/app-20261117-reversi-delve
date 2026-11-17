import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 石は宝石なので、置く音は硬い「カツ」、返る音はガラスの「チン」で、連鎖するほど高くなる。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap
        case place
        case flip(Int)
        case blast
        case chime
        case thud
        case descend
        case pick
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階（五十音マインスイーパーの段階にならう）
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: 0.35
        case .flip: 0.45
        case .place, .pick, .descend: 0.6
        case .blast, .thud: 0.7
        case .chime: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - 音を作る

    private struct Partial {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var sweepTo: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            return synth(0.04, noise: 0.05, partials: [Partial(freq: 2400, amp: 0.5, decay: 90)])
        case .place:
            return synth(0.09, noise: 0.25, noiseDecay: 120, partials: [Partial(freq: 1250, amp: 0.6, decay: 55), Partial(freq: 2630, amp: 0.35, decay: 70)])
        case .flip(let step):
            let f = 1500 * pow(1.06, Double(min(step, 10)))
            return synth(0.14, noise: 0.04, partials: [Partial(freq: f, amp: 0.5, decay: 30), Partial(freq: f * 2.76, amp: 0.25, decay: 40)])
        case .blast:
            return synth(0.42, noise: 0.6, noiseDecay: 9, partials: [Partial(freq: 160, amp: 0.6, decay: 8, sweepTo: 70), Partial(freq: 900, amp: 0.2, decay: 20)])
        case .chime:
            let notes = [659.3, 830.6, 987.8, 1318.5]
            return synth(1.1, noise: 0, partials: notes.enumerated().flatMap { i, f in
                [Partial(freq: f, amp: 0.4, decay: 4.5, delay: Double(i) * 0.11), Partial(freq: f * 2, amp: 0.12, decay: 7, delay: Double(i) * 0.11)]
            })
        case .thud:
            return synth(0.55, noise: 0.3, noiseDecay: 14, partials: [Partial(freq: 92, amp: 0.8, decay: 6, sweepTo: 55), Partial(freq: 138, amp: 0.4, decay: 9)])
        case .descend:
            return synth(0.7, noise: 0.1, noiseDecay: 4, partials: [Partial(freq: 620, amp: 0.35, decay: 4, sweepTo: 180), Partial(freq: 930, amp: 0.15, decay: 5, sweepTo: 270)])
        case .pick:
            return synth(0.3, noise: 0, partials: [Partial(freq: 880, amp: 0.4, decay: 12), Partial(freq: 1760, amp: 0.2, decay: 16), Partial(freq: 1318.5, amp: 0.25, decay: 10, delay: 0.06)])
        }
    }

    private func synth(_ seconds: Double, noise: Double, noiseDecay: Double = 60, partials: [Partial]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRandom(seed: 42)
        var phases = Array(repeating: 0.0, count: partials.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in partials.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.sweepTo { f = p.freq + (to - p.freq) * min(1, local / seconds) }
                phases[k] += 2 * .pi * f / rate
                // 立ち上がりを 3ms でならす（ぷつっと鳴らない）
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = Double(rng.next() % 20_000) / 10_000 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            // 終わりを 10ms でならす
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
