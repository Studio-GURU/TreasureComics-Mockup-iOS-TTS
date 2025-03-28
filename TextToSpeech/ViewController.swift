//
//  ViewController.swift
//  exampletts
//
//  Created by SUNRAIN on 3/10/25.
//

import Foundation
import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler, SpeakResult {
    
    private var contentWebView: WKWebView? = nil
    private lazy var speakHeandler: SpeakHandler? = { return SpeakHandler() }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let innerWebView = WKWebView(frame: .zero)
        innerWebView.translatesAutoresizingMaskIntoConstraints = false
        innerWebView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        innerWebView.scrollView.bounces = false
        innerWebView.scrollView.isPagingEnabled = false
        innerWebView.scrollView.alwaysBounceVertical = false
        innerWebView.scrollView.showsVerticalScrollIndicator = false
        innerWebView.scrollView.showsHorizontalScrollIndicator = false
        innerWebView.scrollView.contentInsetAdjustmentBehavior = .never
        innerWebView.scrollView.refreshControl = UIRefreshControl()
        // webview -> javascript
        innerWebView.configuration.userContentController.add(self, name: "treasureComics")
        self.view.addSubview(innerWebView)
        NSLayoutConstraint.activate([
            innerWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            innerWebView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            innerWebView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            innerWebView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        contentWebView = innerWebView
        do {
            let localFilePath = Bundle.main.path(forResource: "webview_content", ofType: "html")
            let contents =  try String(contentsOfFile: localFilePath!, encoding: .utf8)
            let baseUrl = URL(fileURLWithPath: localFilePath!)
            contentWebView?.loadHTMLString(contents as String, baseURL: baseUrl)
        } catch {
            print("error: \(error)")
        }
        
        if let speak = speakHeandler {
            speak.speakStatusListener(result: self)
        }
        
        if #available(iOS 16.4, *) {
            contentWebView?.isInspectable = true
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("userContentController::message { name: \(message.name), body: \(message.body) }")
        if message.name == "treasureComics", let messageBody = message.body as? String {
            do {
                if let withData = messageBody.data(using: .utf8) {
                    if let json = try JSONSerialization.jsonObject(with: withData, options: .allowFragments) as? [String: AnyObject] {
                        // make contract
                        let request = (json["request"] as? String) ?? ""
                        let action = (json["action"] as? String) ?? ""
                        let callbackName = json["callback"] as? String ?? ""
                        let params = json["parameter"] as? [String: AnyObject]
                        if request == "postSpeak" {
                            if action == "start" {
                                let speakId = params?["speakId"] as? String ?? ""
                                let speakText = params?["speakText"] as? String ?? ""
                                let speechRate = params?["speechRate"] as? Float ?? 0.5
                                let pitch = params?["pitch"] as? Float ?? 1.0
                                let speakEntity = SpeakEntity(speakId: speakId, speakText: speakText, speechRate: speechRate, pitch: pitch, callbackName: callbackName)
                                speakHeandler?.speak(speakEntity: speakEntity, callbackName: callbackName)
                                return
                            }
                            
                            if action == "stop" {
                                speakHeandler?.speakStop(callbackName: callbackName)
                                return
                            }
                            
                            if action == "pause" {
                                speakHeandler?.speakPause(callbackName: callbackName)
                                return
                            }
                            
                            if action == "resume" {
                                speakHeandler?.speakResume(callbackName: callbackName)
                                return
                            }
                        }
                    }
                }
            } catch {
                print("error: \(error)")
            }
        }
    }
 
    // MARK:- SpeakResult Implemetation
    public func onSpeakStatus(utteranceId: String, callback: String, speakStatus: SpeakStatus) {
        var param: [String: Any] = [:]
        param["speakId"] = utteranceId
        param["speakStatus"] = speakStatus.rawValue
        sendPostResponse(callbackName: callback, params: param)
    }
    
    func sendPostResponse(callbackName: String, params: [String: Any]? = nil) {
        var paramString: String = ""
        if params != nil {
            guard let json = try? JSONSerialization.data(withJSONObject: params!, options: .fragmentsAllowed) else {
                print("Something is wrong while converting dictionary to JSON data.")
                return
            }
            guard let paramStringify = String(data: json, encoding: .utf8) else {
                print("Something is wrong while converting JSON data to JSON string.")
                return
            }
            paramString = paramStringify.replacingOccurrences(of: "\"", with: "\\\"")
            paramString = "'\(paramString)'"
        }
        DispatchQueue.main.async {
            self.contentWebView?.evaluateJavaScript("(function(){\(callbackName)(\(paramString));})();")
        }
    }
    
    deinit{
        self.contentWebView?.removeFromSuperview()
        if #available(iOS 14.0, *) {
            self.contentWebView?.configuration.userContentController.removeAllScriptMessageHandlers()
        }
    }
}

