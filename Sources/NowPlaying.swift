import MediaPlayer
import UIKit

/// iOS's half of the lock-screen player - the same job the Android app gives a MediaSession.
///
/// It follows the page and never leads it. The transport buttons send commands back into the
/// page, which owns the stream and its own single-owner playback model; this class only says
/// what the page is doing. That is the whole design: the Android app spent three releases
/// learning what happens when a shell tries to own audio the page is already playing, and the
/// answer is to own none of it.
final class NowPlaying {

    /// Send a command into the page: "play", "pause" or "toggle".
    var command: ((String) -> Void)?

    private let centre = MPNowPlayingInfoCenter.default()
    private var playing = false
    private var title = ""
    private var subtitle = ""
    private var artKey = ""
    private var artwork: MPMediaItemArtwork?
    private var task: URLSessionDataTask?

    init() {
        let centre = MPRemoteCommandCenter.shared()
        centre.playCommand.addTarget { [weak self] _ in
            self?.command?("play")
            return .success
        }
        centre.pauseCommand.addTarget { [weak self] _ in
            self?.command?("pause")
            return .success
        }
        centre.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.command?("toggle")
            return .success
        }
        // Pause and stop mean the same thing for live radio, which is what the site's stop
        // button does: disconnect.
        centre.stopCommand.addTarget { [weak self] _ in
            self?.command?("pause")
            return .success
        }
        // No seek, no tracks, no skipping: offering them on live radio would be a lie the
        // lock screen tells the user.
        centre.changePlaybackPositionCommand.isEnabled = false
        centre.nextTrackCommand.isEnabled = false
        centre.previousTrackCommand.isEnabled = false
        centre.skipForwardCommand.isEnabled = false
        centre.skipBackwardCommand.isEnabled = false
        centre.seekForwardCommand.isEnabled = false
        centre.seekBackwardCommand.isEnabled = false
    }

    func setPlaying(_ value: Bool) {
        playing = value
        publish()
    }

    func set(title: String, subtitle: String, art: String) {
        self.title = title
        self.subtitle = subtitle
        if art != artKey {
            artKey = art
            loadArtwork(art)
        }
        publish()
    }

    private func publish() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title.isEmpty ? "MODDYS World Radio" : title,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        // A stop leaves the card up with Play rather than removing it, so there is always a
        // way back - the same rule the Android notification follows.
        if !subtitle.isEmpty { info[MPMediaItemPropertyArtist] = subtitle }
        if let artwork = artwork { info[MPMediaItemPropertyArtwork] = artwork }
        centre.nowPlayingInfo = info
    }

    private func loadArtwork(_ address: String) {
        task?.cancel()
        artwork = nil
        guard let url = URL(string: address),
              url.scheme == "http" || url.scheme == "https" else {
            publish()
            return
        }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.publish()
            }
        }
        task?.resume()
    }
}
