//
//  SpeechViewController.swift
//  CoreMLDemo
//
//  Created by Максим Алексеев on 03.03.2020.
//  Copyright © 2020 Максим Алексеев. All rights reserved.
//

import UIKit
import Speech
import AVKit

class SpeechViewController: UIViewController {
    // MARK:- Outlets
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    // MARK:- Private properties
    private let audioEngine: AVAudioEngine? = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "ru"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK:- Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        
        speechRecognizer?.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (status) in
            var buttonState = false
            
            switch status {
            case .authorized:
                buttonState = true
                print("Permission denied")
            case .denied:
                buttonState = false
                print("User didn't give permission")
            case .notDetermined:
                buttonState = false
                print("Permission has not been received yet")
            case .restricted:
                buttonState = false
                print("Voice recognizer doesn't supported on this device")
            }
            
            DispatchQueue.main.async {
                self.startButton.isEnabled = buttonState
            }
        }
    }
    
    // MARK:- Private methods
    private func setupViews() {
        self.startButton.layer.cornerRadius = 10
        startButton.isEnabled = false
    }
    
    private func prepareAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("Can not configure audio session")
        }
    }
    
    private func prepareSpeechRequest() -> SFSpeechAudioBufferRecognitionRequest {
        request = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = request else {
            fatalError("Can not create instant of SFSpeechAudioBufferRecognitionRequest")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        return recognitionRequest
    }
    
    private func stopAudioEngine(with request: SFSpeechAudioBufferRecognitionRequest?, _ recognitionTask: SFSpeechRecognitionTask?, _ inputNode: AVAudioInputNode, completion: @escaping () -> Void) {
        self.audioEngine?.stop()
        inputNode.removeTap(onBus: 0)
        
        self.request = nil
        self.recognitionTask = nil
        
        DispatchQueue.main.async {
            completion()
        }
    }
    
    func startAudioEngine(with inputNode: AVAudioInputNode) {
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, _) in
            self.request?.append(buffer)
        }
        
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
        } catch {
            print("Couldn't start audio engine")
        }
    }
    
    private func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
            return
        }
        
        prepareAudioSession()
        
        let recognitionRequest = prepareSpeechRequest()
        
        guard let inputNode = audioEngine?.inputNode else {
            fatalError("Audio engine does not have input node")
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                self.textLabel.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal ?? false)
            }

            if error != nil || isFinal {
                self.stopAudioEngine(with: self.request, self.recognitionTask, inputNode) {
                    self.startButton.isEnabled = true
                }
            }
        })
        
        startAudioEngine(with: inputNode)
    }
    
    // MARK:- Actions
    @IBAction func startTapped(_ sender: UIButton) {
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            request?.endAudio()
            startButton.isEnabled = false
            startButton.setTitle("Start recording", for: .normal)
        } else {
            startRecording()
            startButton.setTitle("Stop recording", for: .normal)
        }
    }
}

extension SpeechViewController: SFSpeechRecognizerDelegate  {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        startButton.isEnabled = available
    }
}
