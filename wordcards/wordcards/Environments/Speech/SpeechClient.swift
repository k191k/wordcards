//
//  SpeechRecognizer.swift
//  wordcards
//
//  Created by k191k on 2022/04/26.
//

import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
    var finishTask: () -> Effect<Never, Never>
    var recognitionTask: (Language, SFSpeechAudioBufferRecognitionRequest) -> Effect<String?, SpeechRecognizer.Error>
    
    static var live: Self {
        let speechRecognizer = SpeechRecognizer()
        return Self(
            finishTask: {
                .fireAndForget {
                    speechRecognizer.reset()
                }
            }, recognitionTask: { (language, request) in
                Effect.run { subscriber in
                    let cancellable = AnyCancellable {
                        speechRecognizer.reset()
                    }
                    do {
                        try speechRecognizer.transcribe(language: language,
                                                        request: request,
                                                        resultHandler: { result in subscriber.send(result) })
                    } catch {
                        if (error is SpeechRecognizer.Error) {
                            subscriber.send(completion: .failure(error as! SpeechRecognizer.Error))
                        }
                        subscriber.send(completion: .failure(.recognizerIsUnavailable))
                      return cancellable
                    }
                    return cancellable
                }
            }
        )
        
    }
}

