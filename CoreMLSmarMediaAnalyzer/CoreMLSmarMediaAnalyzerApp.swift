//
//  CoreMLSmarMediaAnalyzerApp.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//

import SwiftUI

@main
struct CoreMLSmarMediaAnalyzerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
