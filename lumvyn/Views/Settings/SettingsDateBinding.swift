import SwiftUI

extension Binding where Value == Date {
    init(_ source: Binding<Date?>, replacingNilWith nilReplacement: Date) {
        self.init(
            get: { source.wrappedValue ?? nilReplacement },
            set: { source.wrappedValue = $0 }
        )
    }
}
