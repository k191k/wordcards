//
//  ContentView.swift
//  wordbook
//
//  Created by k191k on 2022/04/24.
//

import SwiftUI
import CoreData
import ComposableArchitecture

struct AppState: Equatable {
    var rec = RecState()
    var wordList = WordCardsListState()
    var toast = ToastState(message: "")
    var currentTab = Tab.rec
    enum Tab {
        case rec
        case wordList
    }
}

enum AppAction: Equatable {
    case rec(RecAction)
    case wordList(WordCardsListAction)
    case toast(ToastAction)
    case selectTab(AppState.Tab)
}

struct AppEnvironment {
    var speechClient: SpeechClient
    var wordCardsRepository: WordCardsRepository
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    recReducer.pullback(
        state: \AppState.rec,
        action: /AppAction.rec,
        environment: { .init(mainQueue: $0.mainQueue,
                             speechClient: $0.speechClient,
                             wordCardsRepository: $0.wordCardsRepository) }
    ),
    wordCardsListReducer.pullback(
        state: \AppState.wordList,
        action: /AppAction.wordList,
        environment: { .init(mainQueue: $0.mainQueue,
                             wordCardsRepository: $0.wordCardsRepository) }
    ),
    toastReducer.pullback(
        state: \AppState.toast,
        action: /AppAction.toast,
        environment: { .init(mainQueue: $0.mainQueue) }
    ),
    Reducer {
        state, action, environment in
        switch action {
        case let .selectTab(tab):
            state.currentTab = tab
            return .none
            
        case .rec(.completed):
            return Effect(value: .toast(.show(.success, "Saved successfully!")))
            
        case .rec(.speech(.failure(let error))):
            return Effect(value: .toast(.show(.error, error.message)))

        case .rec, .wordList, .toast:
            return .none
        }
    }
)

struct ContentView: View {
    let store: Store<AppState, AppAction>
    var body: some View {
        WithViewStore(self.store.scope(state: \.currentTab)) { viewStore in
            ZStack{
                VStack {
                    Picker("Tab",
                           selection: viewStore.binding(send: AppAction.selectTab)
                    ){
                        Text("REC").tag(AppState.Tab.rec)
                        Text("LIST").tag(AppState.Tab.wordList)
                    }.pickerStyle(.segmented)
                    
                    if viewStore.state == .rec {
                        Rec(store: self.store.scope(state: \.rec,
                                                    action: AppAction.rec))
                    }
                    if viewStore.state == .wordList {
                        WordCardsList(store: self.store.scope(state: \.wordList,
                                                              action: AppAction.wordList))
                    }
                }
                Toast(store: self.store.scope(state: \.toast, action: AppAction.toast))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: Store(initialState: AppState(),
                                 reducer: appReducer,
                                 environment: AppEnvironment(speechClient: .live,
                                                          wordCardsRepository: .init(context: PersistenceController.shared.container.viewContext),
                                                          mainQueue: .main)))
    }
}
