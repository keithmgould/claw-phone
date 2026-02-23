import Foundation

enum VoiceLoopState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case error(String)
}
