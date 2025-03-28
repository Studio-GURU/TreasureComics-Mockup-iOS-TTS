//
//  TikitSpeakHandler.swift
//  TreasureIslandFoundationKit
//
//  Created by sunwoo on 11/21/24.
//

import Foundation
import AVFoundation
import AudioToolbox

public class SpeakHandler: NSObject {

    private lazy var speechSynthesizer: AVSpeechSynthesizer = { AVSpeechSynthesizer() }()

    private let stackGroup: String = "TikitSpeakHandler"
    private var callback: SpeakResult? = nil
    private var currentSpeakEntity: SpeakEntity? = nil
    private var currentCallbackName: String? = nil
    private var completeCallbackName: String? = nil

    override init() {
        super.init()
        self.speechSynthesizer.delegate = self
    }

    public func speak(speakEntity: SpeakEntity, callbackName : String) {
        isDeviceInSilentMode { isMuted in
            if isMuted {
                self.callback?.onSpeakStatus(utteranceId: self.currentSpeakEntity?.speakId ?? "", callback: callbackName, speakStatus: SpeakStatus.muted)
            } else {
                if self.speechSynthesizer.isSpeaking || self.speechSynthesizer.isPaused {
                    self.callback?.onSpeakStatus(utteranceId: self.currentSpeakEntity?.speakId ?? "", callback: callbackName, speakStatus: SpeakStatus.playing)
                } else {
                    let utterance = AVSpeechUtterance(string: speakEntity.speakText)
                    utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
                    utterance.rate = speakEntity.speechRate
                    utterance.pitchMultiplier = speakEntity.pitch
                    self.currentSpeakEntity = speakEntity
                    self.speechSynthesizer.speak(utterance)
                }
            }
        }
    }

    // check device silent mode
    func isDeviceInSilentMode(completion: @escaping (Bool) -> Void) {
        // ID of a system sound(1057)
        AudioServicesPlaySystemSoundWithCompletion(0) {
            // If no sound is heard, assume silent mode
            completion(AVAudioSession.sharedInstance().outputVolume == 0.0)
        }
    }

    public func speakPause(callbackName: String) {
        self.currentCallbackName = callbackName
        self.speechSynthesizer.pauseSpeaking(at: AVSpeechBoundary.immediate)
    }

    public func speakResume(callbackName: String) {
        self.currentCallbackName = callbackName
        self.speechSynthesizer.continueSpeaking()
    }

    public func speakStop(callbackName: String) {
        self.currentCallbackName = callbackName
        self.speechSynthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }

    public func speakDestroy() {
        self.speakStop(callbackName: "")
        self.currentSpeakEntity = nil
        self.callback = nil
    }

    public func speakStatusListener(result: SpeakResult) {
        self.callback = result
    }
}

extension SpeakHandler: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        callback?.onSpeakStatus(utteranceId: currentSpeakEntity?.speakId ?? "", callback: completeCallbackName ?? "", speakStatus: SpeakStatus.start)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        callback?.onSpeakStatus(utteranceId: currentSpeakEntity?.speakId ?? "", callback: completeCallbackName ?? "", speakStatus: SpeakStatus.done)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        callback?.onSpeakStatus(utteranceId: currentSpeakEntity?.speakId ?? "", callback: currentCallbackName ?? "", speakStatus: SpeakStatus.pause)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        callback?.onSpeakStatus(utteranceId: currentSpeakEntity?.speakId ?? "", callback: currentCallbackName ?? "", speakStatus: SpeakStatus.resume)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        callback?.onSpeakStatus(utteranceId: currentSpeakEntity?.speakId ?? "", callback: currentCallbackName ?? "", speakStatus: SpeakStatus.stop)
    }
}


public struct SpeakEntity {
    let speakId: String
    let speakText: String
    let speechRate: Float
    let pitch: Float
    let callback: String

    public init(speakId: String, speakText: String, speechRate: Float = 0.5, pitch: Float = 1.0, callbackName: String) {
        self.speakId = speakId
        self.speakText = speakText
        self.speechRate = speechRate
        self.pitch = pitch
        self.callback = callbackName
    }
}


public protocol SpeakResult {
    func onSpeakStatus(utteranceId: String, callback: String, speakStatus: SpeakStatus)
}

public enum SpeakStatus: Int {
    case start = 1
    case pause = 2
    case resume = 3
    case stop = 4
    case done = 5
    case playing = -100
    case muted = -200
    case error = -999

    public static func from(value: String) -> SpeakStatus {
        if value.lowercased() == "start" {
            return .start
        } else if value.lowercased() == "pause" {
            return .pause
        } else if value.lowercased() == "resume" {
            return .resume
        } else if value.lowercased() == "stop" {
            return .stop
        } else if value.lowercased() == "done" {
            return .done
        } else if value.lowercased() == "playing" {
            return .playing
        } else if value.lowercased() == "muted" {
            return .muted
        } else {
            return .error
        }
    }
}
