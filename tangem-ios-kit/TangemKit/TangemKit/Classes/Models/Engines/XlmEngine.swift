//
//  XlmEngine.swift
//  TangemKit
//
//  Created by Alexander Osokin on 20/09/2019.
//  Copyright © 2019 Smart Cash AG. All rights reserved.
//

import Foundation
import stellarsdk

public class XlmEngine: CardEngine {
    unowned public var card: Card
    
    public lazy var stellarSdk: StellarSDK = {
        return StellarSDK(withHorizonUrl: "https://\(card.node)")
    }()
    
    public var blockchainDisplayName: String {
        return "Stellar"
    }
    
    public var walletType: WalletType {
        return .stellar
    }
    
    public var walletUnits: String {
        return "XLM"
    }
    
    public var qrCodePreffix: String {
        return ""
    }
    
    public var walletReserve: String?
    
    public var walletAddress: String = ""
    var sequence: Int64?
    var baseReserve: Decimal?
    var baseFee: Decimal?
    var latestTxDate: Date?
    var transaction: TransactionXDR?
    
    var sourceKeyPair: KeyPair?
    
    public var exploreLink: String {
        let baseUrl = card.isTestBlockchain ? "http://testnet.stellarchain.io/address/" : "http://stellarchain.io/address/"
        return baseUrl + walletAddress
    }
    
    public required init(card: Card) {
        self.card = card
        if card.isWallet {
            setupAddress()
        }
    }
    
    public func setupAddress() {        
        guard let keyPair = try? KeyPair(publicKey: PublicKey(card.walletPublicKeyBytesArray)) else {
            return
        }
        sourceKeyPair = keyPair
        walletAddress = keyPair.accountId
        card.node = card.isTestBlockchain ? "horizon-testnet.stellar.org" : "horizon.stellar.org"
        
    }
}

extension XlmEngine: CoinProvider, CoinProviderAsync {
    public var hasPendingTransactions: Bool {
        guard let txDate = latestTxDate else {
            return false
        }
        
        let sinceTxInterval = DateInterval(start: txDate, end: Date()).duration
        let expired = Int(sinceTxInterval) > 10
        if expired {
            latestTxDate = nil
            return false
        }
        return true
    }
    
    public var coinTraitCollection: CoinTrait {
        .allowsFeeInclude
    }
    
    
    private func checkIfAccountCreated(_ address: String, completion: @escaping (Bool) -> Void) {
        stellarSdk.accounts.getAccountDetails(accountId: address) { response -> (Void) in
            switch response {
            case .success(_):
                completion(true)
            case .failure(_):
                completion(false)
            }
        }
    }
    
    public func getHashForSignature(amount: String, fee: String, includeFee: Bool, targetAddress: String, completion: @escaping (Data?) -> Void) {
        guard let amountDecimal = Decimal(string: amount),
            let feeDecimal = Decimal(string: fee),
            let sourceKeyPair = self.sourceKeyPair,
            let seqNumber = self.sequence,
            let destinationKeyPair = try? KeyPair(accountId: targetAddress) else {
                completion(nil)
                return
        }
        
        let finalAmountDecimal = includeFee ? amountDecimal - feeDecimal : amountDecimal
        
        
        checkIfAccountCreated(targetAddress) {[weak self] isCreated in
            guard let self = self else {
                return
            }
            
            let operation = isCreated ? PaymentOperation(sourceAccount: sourceKeyPair,
                                                         destination: destinationKeyPair,
                                                         asset: Asset(type: AssetType.ASSET_TYPE_NATIVE)!,
                                                         amount: finalAmountDecimal) :
                CreateAccountOperation(destination: destinationKeyPair, startBalance: finalAmountDecimal)
            
            
            guard let xdrOperation = try? operation.toXDR() else {
                completion(nil)
                return
            }
            
            
            let minTime = Date().timeIntervalSince1970
            let maxTime = minTime + 60.0
            
            let tx = TransactionXDR(sourceAccount: sourceKeyPair.publicKey,
                                    seqNum: seqNumber + 1,
                                    timeBounds: TimeBoundsXDR(minTime: UInt64(minTime), maxTime: UInt64(maxTime)),
                                    memo: Memo.none.toXDR(),
                                    operations: [xdrOperation])
            
            let network = self.card.isTestBlockchain ? Network.testnet : Network.public
            guard let hash = try? tx.hash(network: network) else {
                completion(nil)
                return
            }
            self.transaction = tx
            completion(hash)
        }
    }
    
    public func getHashForSignature(amount: String, fee: String, includeFee: Bool, targetAddress: String) -> Data? {
        return nil
    }
    
    public func sendToBlockchain(signFromCard: [UInt8], completion: @escaping (Bool) -> Void) {
        guard transaction != nil else {
            completion(false)
            return
        }
        
        var publicKeyData = card.walletPublicKeyBytesArray
        let hint = Data(bytes: &publicKeyData, count: publicKeyData.count).suffix(4)
        let decoratedSignature = DecoratedSignatureXDR(hint: WrappedData4(hint), signature: Data(signFromCard))
        transaction!.addSignature(signature: decoratedSignature)
        
        guard let envelope = try? transaction!.encodedEnvelope() else {
            completion(false)
            return
        }
        
        stellarSdk.transactions.postTransaction(transactionEnvelope: envelope) {[weak self] postResponse -> Void in
            switch postResponse {
            case .success(let submitTransactionResponse):
                if submitTransactionResponse.transactionResult.code == .success {
                    self?.latestTxDate = Date()
                    completion(true)
                } else {
                    print(submitTransactionResponse.transactionResult.code)
                    completion(false)
                }
                break
            case .failure(let horizonRequestError):
                print(horizonRequestError.localizedDescription)
                completion(false)
            }
        }
    }
    
    public func getFee(targetAddress: String, amount: String, completion: @escaping ((min: String, normal: String, max: String)?) -> Void) {
        guard let fee = baseFee else {
            completion(nil)
            return
        }
        let feeString = "\(fee)"
        completion((feeString,feeString,feeString))
    }
    
    public func validate(address: String) -> Bool {
        let keyPair = try? KeyPair(accountId: address)
        return keyPair != nil
    }
}
