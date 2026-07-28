import Foundation

enum ResumeDelay: Double, CaseIterable, Identifiable, Sendable {
    case immediately = 0
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .immediately:
            "Immediately"
        case .oneSecond:
            "1 second"
        case .twoSeconds:
            "2 seconds"
        case .fiveSeconds:
            "5 seconds"
        }
    }

    var duration: Duration {
        .milliseconds(Int64(rawValue * 1_000))
    }
}
