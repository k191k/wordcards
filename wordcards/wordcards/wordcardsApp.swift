//
//  wordcardsApp.swift
//  wordcards
//
//  Created by k191k on 2022/04/24.
//

import SwiftUI
import ComposableArchitecture

@main
struct wordcardsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialState: AppState(),
                                     reducer: appReducer.debug(),
                                     environment: AppEnvironment(speechClient: .live,
                                                              wordCardsRepository: WordCardsRepository(context: PersistenceController.shared.container.viewContext),
                                                              mainQueue: .main)))
        }
    }
}
