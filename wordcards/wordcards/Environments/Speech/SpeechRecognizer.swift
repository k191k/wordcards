//
//  SpeechRecognizer.swift
//  wordbook
//
//  Created by k191k on 2022/04/28.
//

import AVFoundation
import Speech

class SpeechRecognizer {
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    enum Error: Swift.Error, Equatable {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    init() {
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw Error.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw Error.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw Error.notPermittedToRecord
                }
            } catch {
                throw error
            }
        }
    }
    
    private static func prepareEngine(_ request: SFSpeechAudioBufferRecognitionRequest) throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    func transcribe(language: Language, request: SFSpeechAudioBufferRecognitionRequest, resultHandler: @escaping (String) -> Void) throws {
        
        recognizer = SFSpeechRecognizer(locale: language.locale)
        
        guard let recognizer = self.recognizer, recognizer.isAvailable else {
            throw Error.recognizerIsUnavailable
        }
                
        do {
            let (audioEngine, request) = try Self.prepareEngine(request)
            self.audioEngine = audioEngine
            self.request = request
            
            self.task = recognizer.recognitionTask(with: request) { result, error in
                let receivedFinalResult = result?.isFinal ?? false
                let receivedError = error != nil
                
                if receivedFinalResult || receivedError {
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)
                }
                
                if let result = result {
                    resultHandler(result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces))
                }
            }
        } catch {
            self.reset()
            throw error
        }
    }
    
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
        recognizer = nil
    }
    
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}

