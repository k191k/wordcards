//
//  RecView.swift
//  wordcards
//
//  Created by k191k on 2022/04/24.
//

import Combine
import ComposableArchitecture
import Speech
import SwiftUI

struct RecState: Equatable {
    var status: Status = .stop
    var recDetail: RecDetail = RecDetail(word: "", meaning: "")
    
    struct RecDetail: Equatable, Hashable {
        var word: String
        var meaning: String
        
        mutating func reset() {
            self.word = ""
            self.meaning = ""
        }
    }
    
    enum Status: Equatable {
        case recording(Language)
        case waiting
        case stop
        
        var next: Status {
            switch self {
            case .recording(.en): return .waiting
            case .waiting: return .recording(.jp)
            case .recording(.jp): return .stop
            case .stop: return .recording(.en)
            }
        }
        
        var message: String {
            switch self {
            case .recording(.en): return "Recording English"
            case .waiting: return "Next, let's record what it means"
            case .recording(.jp): return "Recording Japanese"
            case .stop: return "Let's record the words😎"
            }
        }
        
        var buttonColor: Color {
            switch self {
            case .recording: return .red
            case .waiting, .stop: return .green
            }
        }
        
        var buttonTitle: String {
            switch self {
            case .recording: return "DONE"
            case .waiting, .stop: return "START"
            }
        }
    }
}

enum RecAction: Equatable {
    case recordButtonTapped
    case speech(Result<String?, SpeechRecognizer.Error>)
    case completed
}

struct RecEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var speechClient: SpeechClient
    var wordCardsRepository: WordCardsRepository
}

let recReducer = Reducer<RecState, RecAction, RecEnvironment> { state, action, environment in
    switch action {
    case .recordButtonTapped:
        state.status = state.status.next
        switch state.status {
        case let .recording(lang):
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            if lang == .en {
                return environment.speechClient.recognitionTask(.en, request)
                    .catchToEffect(RecAction.speech)
            } else if lang == .jp {
                return environment.speechClient.recognitionTask(.jp, request)
                    .catchToEffect(RecAction.speech)
            }
            return .none
        case .waiting:
            return environment.speechClient.finishTask()
                .fireAndForget()
        case .stop:
            return Effect(value: .completed)
        }
        
    case let .speech(.success(transcribedText)):
        guard let text = transcribedText else { return .none }
        if state.status == .recording(.en) {
            state.recDetail.word = text
        } else if state.status == .recording(.jp) {
            state.recDetail.meaning = text
        }
        return .none
        
    case .speech(.failure(_)):
        return .none
        
    case .completed:
        environment.wordCardsRepository.saveCard(word: state.recDetail.word,
                                                 meaning: state.recDetail.meaning)
        state.recDetail.reset()
        return environment.speechClient.finishTask()
            .fireAndForget()
    }
}

struct Rec: View {
    let store: Store<RecState, RecAction>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack {
                if viewStore.state.status != .stop {
                    VStack {
                        Text("🇺🇸" + viewStore.state.recDetail.word)
                            .font(.largeTitle)
                        Text("🇯🇵" + viewStore.state.recDetail.meaning)
                            .font(.largeTitle)
                    }
                }
                Spacer()
                Text(viewStore.state.status.message)
                    .font(.title)
                Button(action: { viewStore.send(.recordButtonTapped) }) {
                    HStack {
                        Text(viewStore.state.status.buttonTitle)
                            .fontWeight(.heavy)
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 100, height: 100)
                    .imageScale(.large)
                    .background(viewStore.state.status.buttonColor)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
            }
        }
    }
}

struct RecView_Previews: PreviewProvider {
    static var previews: some View {
        Rec(store: Store(initialState: RecState(),
                         reducer: recReducer,
                         environment: RecEnvironment(mainQueue: .main, speechClient: .live, wordCardsRepository: .init(context: PersistenceController.shared.container.viewContext))))
    }
}
