//
//  CardManager.swift
//  TangemSdk
//
//  Created by Alexander Osokin on 03/10/2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation

@available(iOS 13.0, *)
public final class CardManager {
    
    public private(set) var card: Card? =  nil
    
    private let cardReader: CardReader
    private let cardManagerDelegate: CardManagerDelegate
    private let cardEnvironmentRepository: CardEnvironmentRepository
    
    public init(cardReader: CardReader, dataStorage: DataStorage? = nil, cardManagerDelegate: CardManagerDelegate) {
        self.cardReader = cardReader
        self.cardManagerDelegate = cardManagerDelegate
        cardEnvironmentRepository = CardEnvironmentRepository(dataStorage: dataStorage)
    }
    
    public func scanCard(completion: @escaping (ScanResult) -> Void) {
        let task = ScanTask()
        runTask(task, completion: completion)
    }
    
    public func sign(completion: @escaping (SignResult) -> Void) {
        
        
        //TODO: implement sign
    }
    
    func runTask<TaskResult>(_ task: Task<TaskResult>, completion: @escaping (TaskResult) -> Void) {
        task.cardReader = cardReader
        task.delegate = cardManagerDelegate
        task.cardEnvironmentRepository = cardEnvironmentRepository
        task.run(with: cardEnvironmentRepository.cardEnvironment, completion: completion)
    }
    
    func runCommand<T: CommandSerializer>(_ commandSerializer: T, completion: @escaping (TaskCompletionResult<T.CommandResponse>) -> Void) {
            let task = SingleCommandTask<T>(commandSerializer)
            task.cardReader = cardReader
            task.delegate = cardManagerDelegate
            task.cardEnvironmentRepository = cardEnvironmentRepository
            runTask(task, completion: completion)
    }
}

@available(iOS 13.0, *)
extension CardManager {
    public convenience init(cardReader: CardReader = NFCReader(), dataStorage: DataStorage? = DefaultDataStorage(), cardManagerDelegate: CardManagerDelegate? = nil) {
        let delegate = cardManagerDelegate ?? DefaultCardManagerDelegate(reader: cardReader as! NFCReaderText)
        self.init(cardReader: cardReader, dataStorage: dataStorage, cardManagerDelegate: delegate  )
    }
}
