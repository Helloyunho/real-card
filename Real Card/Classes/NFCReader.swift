//
//  NFCReader.swift
//  Real Card
//
//  Created by Helloyunho on 2022/09/15.
//

import CoreNFC
import Foundation
import SwiftUI

class NFCReader: NSObject, NFCTagReaderSessionDelegate, ObservableObject {
    var session: NFCTagReaderSession?
    @Published var showErrorAlert = false
    var error: Error?
    @Published var `repeat` = false

    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code == .readerSessionInvalidationErrorSessionTimeout, self.repeat {
                let retryInterval = DispatchTimeInterval.milliseconds(500)
                DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
                    session.restartPolling()
                }
                return
            }
            if readerError.code != .readerSessionInvalidationErrorUserCanceled, readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
                session.invalidate(errorMessage: "Failed to connect.")
                self.error = error
                DispatchQueue.main.async {
                    self.showErrorAlert = true
                }
            }
        }

        self.session = nil
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        let tag = tags.first!

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to connect.")
                self.error = error
                DispatchQueue.main.async {
                    self.showErrorAlert = true
                }
                return
            }

            guard case .feliCa(let feliCaTag) = tag else {
                let retryInterval = DispatchTimeInterval.milliseconds(500)
                session.alertMessage = "FeliCa card is not detected, please try again with FeliCa card."
                DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
                    session.restartPolling()
                }
                return
            }

            session.invalidate()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .nfcCardRead, object: feliCaTag)
            }
            if self.repeat {
                let retryInterval = DispatchTimeInterval.milliseconds(500)
                DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
                    session.restartPolling()
                }
            }
        }
    }

    func initialize() {
        self.error = nil

        guard NFCTagReaderSession.readingAvailable else {
            return
        }

        self.session = NFCTagReaderSession(pollingOption: .iso18092, delegate: self)
        self.session?.alertMessage = "Put your Amusement IC or e-amusement card on your iPhone."
        self.session?.begin()
    }
}
