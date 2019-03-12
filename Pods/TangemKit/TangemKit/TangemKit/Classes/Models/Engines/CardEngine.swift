//
//  CardEngine.swift
//  TangemKit
//
//  Created by Gennady Berezovsky on 04.03.19.
//  Copyright © 2019 Smart Cash AG. All rights reserved.
//

import Foundation

public enum WalletType {
    case btc
    case eth
    case seed
    case cle
    case qlear
    case ert
    case wrl
    case rsk
    case cardano
    case empty
}

public protocol CardEngine: class {
    
    var card: Card { get set }
    
    var walletType: WalletType { get }
    var walletUnits: String { get }
    var walletAddress: String { get }
    
    var exploreLink: String { get }
    
    init(card: Card)
    
    func setupAddress()
    
}

class NoWalletCardEngine: CardEngine {
    
    var card: Card
    
    var walletType: WalletType = .empty
    var walletUnits: String = "---"
    var walletAddress: String = ""
    var exploreLink: String {
        return ""
    }
    
    required init(card: Card) {
        self.card = card
    }
    
    func setupAddress() {

    }
    
}