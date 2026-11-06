import Foundation

enum AppLanguage {
    static func isChinese(_ languages: [String]) -> Bool {
        languages.first?.lowercased().split(separator: "-").first == "zh"
    }

    static var chinese: Bool {
        if CommandLine.arguments.contains("--render-preview"),
           let language = ProcessInfo.processInfo.environment["KEEP_AWAKE_PREVIEW_LANGUAGE"] {
            return isChinese([language])
        }
        return isChinese(Locale.preferredLanguages)
    }
}

func localized(_ chinese: String, _ english: String) -> String {
    AppLanguage.chinese ? chinese : english
}
