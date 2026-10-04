import OSLog

enum Log {
    static let audio = Logger(subsystem: "com.notype.app", category: "audio")
    static let speech = Logger(subsystem: "com.notype.app", category: "speech")
    static let hotkey = Logger(subsystem: "com.notype.app", category: "hotkey")
    static let inject = Logger(subsystem: "com.notype.app", category: "inject")
    static let app = Logger(subsystem: "com.notype.app", category: "app")
}
