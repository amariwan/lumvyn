import Foundation
import ObjectiveC.runtime

private var bundleLanguageKey: UInt8 = 0

private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let language = objc_getAssociatedObject(self, &bundleLanguageKey) as? String,
           !language.isEmpty,
           let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

public extension Bundle {
    static func setLanguage(_ languageCode: String?) {
        if object_getClass(Bundle.main) !== LocalizedBundle.self {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }

        let codeToSet: String?

        if let code = languageCode, code != "system", !code.isEmpty {
            codeToSet = code
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            codeToSet = nil
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }

        objc_setAssociatedObject(
            Bundle.main,
            &bundleLanguageKey,
            codeToSet,
            .OBJC_ASSOCIATION_RETAIN
        )
    }
}
