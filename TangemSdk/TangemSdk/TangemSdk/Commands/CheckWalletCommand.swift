//
//  CheckWalletCommand.swift
//  TangemSdk
//
//  Created by Alexander Osokin on 03/10/2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation

/// Deserialized response from the Tangem card after `CheckWalletCommand`.
public struct CheckWalletResponse {
    /// Unique Tangem card ID number
    public let cardId: String
    /// Random salt generated by the card
    public let salt: Data
    /// Challenge and salt signed with the wallet private key.
    public let walletSignature: Data
    
    public func verify(curve: EllipticCurve, publicKey: Data, challenge: Data) -> Bool? {
        return CryptoUtils.vefify(curve: curve,
                                  publicKey: publicKey,
                                  message: challenge + salt,
                                  signature: walletSignature)
    }
}

/// This command proves that the wallet private key from the card corresponds to the wallet public key.  Standard challenge/response scheme is used
@available(iOS 13.0, *)
public final class CheckWalletCommand: CommandSerializer {
    public typealias CommandResponse = CheckWalletResponse
    /// Unique Tangem card ID number
    let cardId: String
    /// Random challenge generated by application
    public let challenge: Data
    
    public init?(cardId: String) {
        self.cardId = cardId
        if let challenge = CryptoUtils.generateRandomBytes(count: 16) {
            self.challenge = challenge
        } else {
            return nil
        }
    }
    
    public func serialize(with environment: CardEnvironment) throws -> CommandApdu {
        let tlvBuilder = try createTlvBuilder(legacyMode: environment.legacyMode)
            .append(.pin, value: environment.pin1)
            .append(.cardId, value: cardId)
            .append(.challenge, value: challenge)
        
        let cApdu = CommandApdu(.checkWallet, tlv: tlvBuilder.serialize())
        return cApdu
    }
    
    public func deserialize(with environment: CardEnvironment, from responseApdu: ResponseApdu) throws -> CheckWalletResponse {
        guard let tlv = responseApdu.getTlvData(encryptionKey: environment.encryptionKey) else {
            throw TaskError.serializeCommandError
        }
        
        let mapper = TlvMapper(tlv: tlv)
        return CheckWalletResponse(
            cardId: try mapper.map(.cardId),
            salt: try mapper.map(.salt),
            walletSignature: try mapper.map(.walletSignature))
    }
}
