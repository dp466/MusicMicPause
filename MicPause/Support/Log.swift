import OSLog

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.dparadis.MicPause"
    static let microphone = Logger(subsystem: subsystem, category: "Microphone")
    static let playback = Logger(subsystem: subsystem, category: "Playback")
    static let meeting = Logger(subsystem: subsystem, category: "MeetingAssist")
    static let app = Logger(subsystem: subsystem, category: "App")
}
