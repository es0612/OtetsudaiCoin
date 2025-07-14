import Foundation
import os.log

enum LogLevel: String, CaseIterable {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case critical = "🚨 CRITICAL"
}

struct DebugLogger {
    private static let subsystem = "com.otetsudaicoin.app"
    private static let logger = Logger(subsystem: subsystem, category: "Debug")
    
    static func log(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.debugTimestamp.string(from: Date())
        let threadInfo = Thread.isMainThread ? "[Main]" : "[Background]"
        
        let logMessage = "[\(timestamp)] \(threadInfo) \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)"
        
        // デバッグ時のみコンソール出力
        #if DEBUG
        print(logMessage)
        #endif
        
        // システムログ出力
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
    }
    
    static func logCoreDataOperation(
        _ operation: String,
        context: String = "",
        success: Bool? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "CoreData: \(operation)"
        if !context.isEmpty {
            message += " - \(context)"
        }
        
        if let success = success {
            message += " - Success: \(success)"
        }
        
        if let error = error {
            message += " - Error: \(error.localizedDescription)"
        }
        
        let level: LogLevel = error != nil ? .error : (success == false ? .warning : .info)
        log(message, level: level, file: file, function: function, line: line)
    }
    
    static func logViewModelState(
        viewModel: String,
        state: String,
        details: String = "",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "ViewModel[\(viewModel)]: \(state)"
        if !details.isEmpty {
            message += " - \(details)"
        }
        
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func logTaskStart(
        taskName: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("Task Started: \(taskName)", level: .info, file: file, function: function, line: line)
    }
    
    static func logTaskEnd(
        taskName: String,
        duration: TimeInterval? = nil,
        success: Bool = true,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "Task Ended: \(taskName)"
        if let duration = duration {
            message += " - Duration: \(String(format: "%.3f", duration))s"
        }
        message += " - Success: \(success)"
        if let error = error {
            message += " - Error: \(error.localizedDescription)"
        }
        
        let level: LogLevel = error != nil ? .error : .info
        log(message, level: level, file: file, function: function, line: line)
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let debugTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Convenience Extensions
extension DebugLogger {
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    static func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }
}