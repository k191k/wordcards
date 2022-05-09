//
//  wordcardsTests.swift
//  wordcardsTests
//
//  Created by k191k on 2022/04/24.
//

import XCTest
import ComposableArchitecture
import CoreData
import Speech
import Combine

@testable import WordCards

class wordcardsTests: XCTestCase {
    
    let recognitionTaskSubject = PassthroughSubject<String?, SpeechRecognizer.Error>()
    
    func testError() {
        let context = PersistenceController(inMemory: true).container.viewContext
        var speechClient = SpeechClient.failing
        speechClient.recognitionTask = { _,_ in self.recognitionTaskSubject.eraseToEffect() }
        let store = TestStore(initialState: AppState(),
                              reducer: appReducer,
                              environment: .mock(speechClient: speechClient,
                                                 wordCardsRepository: .mock(context: context),
                                                 mainQueue: .immediate))
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .recording(.en)
        }
        
        self.recognitionTaskSubject.send(completion: .failure(.notPermittedToRecord))
        
        store.receive(.rec(.speech(.failure(.notPermittedToRecord))))
        store.receive(.toast(.show(.error, SpeechRecognizer.Error.notPermittedToRecord.message))) {
            $0.toast.isShow = true
            $0.toast.severity = .error
            $0.toast.message = SpeechRecognizer.Error.notPermittedToRecord.message
        }
        store.receive(.toast(.disappear)) {
            $0.toast.isShow = false
        }
    }
    
    func testRecoadEnglish() {
        let context = PersistenceController(inMemory: true).container.viewContext
        var speechClient = SpeechClient.failing
        speechClient.finishTask = {
            .fireAndForget { self.recognitionTaskSubject.send(completion: .finished) }
        }
        speechClient.recognitionTask = { _,_ in self.recognitionTaskSubject.eraseToEffect() }
        
        let store = TestStore(initialState: AppState(),
                              reducer: appReducer,
                              environment:  .mock(speechClient: speechClient,
                                                  wordCardsRepository: .mock(context: context),
                                                  mainQueue: .immediate))
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .recording(.en)
        }
        
        let word = "Hello"
        
        self.recognitionTaskSubject.send(word)
        
        store.receive(.rec(.speech(.success(word)))) {
            $0.rec.recDetail.word = word
        }
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .waiting
        }
    }
    
    func testRecoadJapanese() {
        let context = PersistenceController(inMemory: true).container.viewContext
        var speechClient = SpeechClient.failing
        speechClient.finishTask = {
            .fireAndForget { self.recognitionTaskSubject.send(completion: .finished) }
        }
        speechClient.recognitionTask = { _,_ in self.recognitionTaskSubject.eraseToEffect() }
        
        let store = TestStore(initialState: AppState(rec: RecState(status: .waiting)),
                              reducer: appReducer,
                              environment: .mock(speechClient: speechClient,
                                                 wordCardsRepository: .mock(context: context),
                                                  mainQueue: .immediate))
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .recording(.jp)
        }
        
        let meaning = "こんにちは"
        
        self.recognitionTaskSubject.send(meaning)
        
        store.receive(.rec(.speech(.success(meaning)))) {
            $0.rec.recDetail.meaning = meaning
        }
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .stop
        }
                
        store.receive(.rec(.completed)) {
            $0.rec.recDetail.word = ""
            $0.rec.recDetail.meaning = ""
        }
        store.receive(.toast(.show(.success, "Saved successfully!"))){
            $0.toast.isShow = true
            $0.toast.severity = .success
            $0.toast.message = "Saved successfully!"
        }
        store.receive(.toast(.disappear)) {
            $0.toast.isShow = false
        }
    }
    
    func testChangeTab() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let store = TestStore(initialState: AppState(),
                              reducer: appReducer,
                              environment: .mock(wordCardsRepository: .mock(context: context)))
        
        store.send(.selectTab(.wordList)) {
            $0.currentTab = .wordList
        }
        
        store.send(.selectTab(.rec)) {
            $0.currentTab = .rec
        }
    }
    
    func testSaveWords() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let recDetail = RecState.RecDetail(word: "Hello", meaning: "こんにちは")
        var speechClient = SpeechClient.failing
        speechClient.finishTask = {
            .fireAndForget { self.recognitionTaskSubject.send(completion: .finished) }
        }
        let store = TestStore(initialState: AppState(rec: RecState(status: .recording(.jp), recDetail: recDetail)),
                              reducer: appReducer,
                              environment: .mock(speechClient: speechClient,
                                                 wordCardsRepository: .mock(context: context),
                                                 mainQueue: .immediate))
        
        store.send(.rec(.recordButtonTapped)) {
            $0.rec.status = .stop
        }
        
        store.receive(.rec(.completed)) {
            $0.rec.recDetail.word = ""
            $0.rec.recDetail.meaning = ""
        }
        
        store.receive(.toast(.show(.success, "Saved successfully!"))){
            $0.toast.isShow = true
            $0.toast.severity = .success
            $0.toast.message = "Saved successfully!"
        }
        store.receive(.toast(.disappear)) {
            $0.toast.isShow = false
        }
        
        store.send(.wordList(.update)) {
            let cards = store.environment.wordCardsRepository.getCards()
            $0.wordList.cards = cards
            XCTAssertEqual(cards[0].word, recDetail.word)
            XCTAssertEqual(cards[0].meaning, recDetail.meaning)
        }
    }
    
    func testDeleteWords() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let recDetail = RecState.RecDetail(word: "Hello", meaning: "こんにちは")
        let store = TestStore(initialState: AppState(rec: RecState(status: .recording(.jp), recDetail: recDetail)),
                              reducer: appReducer,
                              environment: .mock(wordCardsRepository: .mock(context: context),
                                                 mainQueue: .immediate))
        
        store.environment.wordCardsRepository.saveCard(word: recDetail.word, meaning: recDetail.meaning)
        
        let card = store.environment.wordCardsRepository.getCards().first!
        
        XCTAssertEqual(card.word, recDetail.word)
        XCTAssertEqual(card.meaning, recDetail.meaning)
        
        store.send(.wordList(.delete(card)))
        
        store.receive(.wordList(.update)) {
            $0.wordList.cards = []
        }
    }
}

private extension AppEnvironment {
    static func mock(speechClient: SpeechClient = .failing,
                     wordCardsRepository: WordCardsRepository = .mock(),
                     mainQueue: AnySchedulerOf<DispatchQueue> = DispatchQueue.immediate.eraseToAnyScheduler()) -> Self {
        Self(speechClient: speechClient, wordCardsRepository: wordCardsRepository, mainQueue: mainQueue)
    }
}

private extension SpeechClient {
    static let failing = Self(
      finishTask: { .failing("SpeechClient.finishTask") },
      recognitionTask: { _,_  in .failing("SpeechClient.recognitionTask") }
    )
}

private extension WordCardsRepository {
    static func mock (context: NSManagedObjectContext = {
        XCTFail("WordCardsRepository is unimplemented")
        return PersistenceController(inMemory: true).container.viewContext
    }() ) -> Self {
        Self(context: context)
    }
}
