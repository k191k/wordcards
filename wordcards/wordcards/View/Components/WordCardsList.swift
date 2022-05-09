//
//  WordsCardsList.swift
//  wordcards
//
//  Created by k191k on 2022/04/24.
//

import SwiftUI
import ComposableArchitecture
import OrderedCollections

struct WordCardsListState: Equatable {
    var cards: [Card]?
}

enum WordCardsListAction: Equatable {
    case update
    case delete(Card)
}

struct WordCardsListEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var wordCardsRepository: WordCardsRepository
}

let wordCardsListReducer = Reducer<WordCardsListState, WordCardsListAction, WordCardsListEnvironment> {
    state, action, environment in
    switch action {
    case .update:
        state.cards = environment.wordCardsRepository.getCards()
        return .none
        
    case let .delete(card):
        environment.wordCardsRepository.deleteCard(card)
        return Effect(value: .update)
    }
    
}

struct WordCardsList: View {
    let store: Store<WordCardsListState, WordCardsListAction>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack {
                IfLetStore(
                    store.scope(state: { $0.cards }),
                    then: { store in
                        WithViewStore(store) { viewStore in
                            List(viewStore.state, id: \.self) { card in
                                WordCell(word: card.word!, meaning: card.meaning!)
                                    .swipeActions(edge: .leading, allowsFullSwipe: false, content: {
                                        Button(action: { viewStore.send(.delete(card)) },
                                               label: { Image(systemName: "trash")})
                                })
                            }
                        }
                    },
                    else: { Spacer() }
                )
            }.onAppear{
                viewStore.send(.update)
            }
        }
    }
}


struct WordList_Previews: PreviewProvider {
    static var previews: some View {
        WordCardsList(store: Store(initialState: WordCardsListState(),
                                   reducer: wordCardsListReducer,
                                   environment: WordCardsListEnvironment(mainQueue: .main,
                                                                         wordCardsRepository: .init(context: PersistenceController.shared.container.viewContext))))
    }
}
