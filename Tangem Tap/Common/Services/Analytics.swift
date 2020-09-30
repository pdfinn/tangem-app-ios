//
//  Analytics.swift
//  Tangem
//
//  Created by Alexander Osokin on 31.03.2020.
//  Copyright © 2020 Smart Cash AG. All rights reserved.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics
import TangemSdk

class Analytics {
    enum Event: String {
        case cardIsScanned = "card_is_scanned"
        case transactionIsSent = "transaction_is_sent"
        case readyToScan = "ready_to_scan"
        case readyToSign = "ready_to_sign"
        case signed = "signed"
    }
    
    enum ParameterKey: String {
        case blockchain = "blockchain"
        case batchId = "batch_id"
        case firmware = "firmware"
    }
    
    static func log(event: Event) {
        FirebaseAnalytics.Analytics.logEvent(event.rawValue, parameters: nil)
    }
    
    static func logScan(card: Card) {
        let blockchainName = card.cardData?.blockchainName ?? ""
        let params = [ParameterKey.blockchain.rawValue: blockchainName,
                      ParameterKey.batchId.rawValue: card.cardData?.batchId ?? "",
                      ParameterKey.firmware.rawValue: card.firmwareVersion ?? ""]
        
        FirebaseAnalytics.Analytics.logEvent(Event.cardIsScanned.rawValue, parameters: params)
        Crashlytics.crashlytics().setCustomValue(blockchainName, forKey: ParameterKey.blockchain.rawValue)
    }
    
    static func logSign(card: Card) {
        let params = [ParameterKey.blockchain.rawValue: card.cardData?.blockchainName ?? "",
                      ParameterKey.batchId.rawValue: card.cardData?.batchId ?? "",
                      ParameterKey.firmware.rawValue: card.firmwareVersion ?? ""]
        
        FirebaseAnalytics.Analytics.logEvent(Event.signed.rawValue, parameters: params)
    }
    
    
    static func logTx(blockchainName: String?) {
          FirebaseAnalytics.Analytics.logEvent(Event.transactionIsSent.rawValue,
                                               parameters: [ParameterKey.blockchain.rawValue: blockchainName ?? ""])
    }
    
    static func log(error: Error) {
        if case .userCancelled = error.toTangemSdkError() {
            return
        }
        
        Crashlytics.crashlytics().record(error: error)
    }
}