//
//  lumvynWidget_Extension.swift
//  lumvynWidget-Extension
//
//  Created by Aland Baban on 18.04.26.
//

import AppIntents

struct lumvynWidget_Extension: AppIntent {
    static var title: LocalizedStringResource { "lumvynWidget-Extension" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
