//
//  CardViewModel.swift
//  Tangem Tap
//
//  Created by Alexander Osokin on 18.07.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk
import BlockchainSdk
import Combine
import Alamofire
import  SwiftUI


class CardViewModel: Identifiable, ObservableObject {
    @Published var card: Card
    let service = NetworkService()
    var payIDService: PayIDService? = nil
    var ratesService: CoinMarketCapService! {
        didSet {
            selectedCurrency = ratesService.selectedCurrencyCode
            $selectedCurrency
                .dropFirst()
                .sink(receiveValue: { [unowned self] value in
                    self.ratesService.selectedCurrencyCode = value
                    self.loadRates()
                })
                .store(in: &bag)
        }
    }
    var rates: [String: [String: Decimal]] = [:]
    
    @Published var isWalletLoading: Bool = false
    @Published var loadingError: Error?
    @Published var noAccountMessage: String?
    @Published var isCardSupported: Bool = true
    @Published var payId: PayIdStatus = .notCreated
    @Published var balanceViewModel: BalanceViewModel!
    @Published var wallet: Wallet? = nil
    @Published var image: UIImage? = nil
    @Published var selectedCurrency: String = ""
    @Published private(set) var currentSecOption: SecurityManagementOption = .longTap
    
    var walletManager: WalletManager?
    public let verifyCardResponse: VerifyCardResponse?
    
    private var bag =  Set<AnyCancellable>()
    
    init(card: Card, verifyCardResponse: VerifyCardResponse? = nil) {
        self.card = card
        self.verifyCardResponse = verifyCardResponse
        updateCurrentSecOption()
        if let walletManager = WalletManagerFactory().makeWalletManager(from: card) {
            self.walletManager = walletManager
            self.payIDService = PayIDService.make(from: walletManager.wallet.blockchain)
            self.balanceViewModel = self.makeBalanceViewModel(from: walletManager.wallet)
            walletManager.$wallet
                .subscribe(on: DispatchQueue.global())
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: {[unowned self] wallet in
                    print("wallet received")
                    self.wallet = wallet
                    self.balanceViewModel = self.makeBalanceViewModel(from: wallet)
                })
                .store(in: &bag)
        } else {
            isCardSupported = WalletManagerFactory().isBlockchainSupported(card) 
        }
    }
    
    func updateCurrentSecOption() {
        if !(card.isPin1Default ?? true) {
            self.currentSecOption = .accessCode
        } else if !(card.isPin2Default ?? true) {
            self.currentSecOption = .passCode
        }
        else {
            self.currentSecOption = .longTap
        }
    }
    
    func loadPayIDInfo () {
        guard let cid = card.cardId, let key = card.cardPublicKey else {
            payId = .notSupported
            return
        }
        
        payIDService?.loadPayId(cid: cid, key: key, completion: { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let payIdString):
                if let payIdString = payIdString {
                    self.payId = .created(payId: payIdString)
                } else {
                    self.payId = .notCreated
                }
            case .failure(let error):
                //TODO: Handle error?
                self.payId = .notSupported
            }
        })
    }
    
    func createPayID(_ payIDString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !payIDString.isEmpty,
            let cid = card.cardId,
            let address = wallet?.address,
            let cardPublicKey = card.cardPublicKey,
            let payIdService = self.payIDService else {
                completion(.failure(PayIdError.unknown))
                return
        }
        
        let fullPayIdString = payIDString + "$payid.tangem.com"
        payIdService.createPayId(cid: cid, key: cardPublicKey, payId: fullPayIdString, address: address) { [weak self] result in
            switch result {
            case .success:
                UIPasteboard.general.string = fullPayIdString
                self?.payId = .created(payId: fullPayIdString)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    public func update(silent: Bool = false) {
        loadingError = nil
        loadImage()
        if let walletManager = self.walletManager {
            if !silent {
                isWalletLoading = true
            }
            loadPayIDInfo()
            walletManager.update { [weak self] result in
                guard let self = self else {return}
                
                DispatchQueue.main.async {
                    if case let .failure(error) = result {
                        self.loadingError = error.detailedError
                        if case let .noAccount(noAccountMessage) = (error as? WalletError) {
                            self.noAccountMessage = noAccountMessage
                        }
                        if let wallet = self.wallet  {
                            self.balanceViewModel = self.makeBalanceViewModel(from: wallet)
                        }
                    } else {
                        self.loadRates()
                    }
                    self.isWalletLoading = false
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isWalletLoading = false
            }
        }
    }
    
    func loadRates() {
        rates = [:]
        if let currenciesToExchange = wallet?.amounts
            .filter({ $0.key != .reserve }).values
            .flatMap({ [$0.currencySymbol: Decimal(1.0)] })
            .reduce(into: [String: Decimal](), { $0[$1.0] = $1.1 }) {
            
            ratesService?
                .loadRates(for: currenciesToExchange)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print(error.localizedDescription)
                    case .finished:
                        break
                    }
                }) {[unowned self] rates in
                    self.rates = rates
                    if let wallet = self.wallet  {
                        self.balanceViewModel = self.makeBalanceViewModel(from: wallet)
                    }
            }
            .store(in: &bag)
            
        }
    }
    
    func loadImage() {
        guard image == nil, let cid = card.cardId?.lowercased() else {
            return
        }
        
        if cid.starts(with: "bc01") { //Sergio
            backedLoadImage(name: "card_tg059")
            return
        }
        
        if cid.starts(with: "bc02") { //Marta
            backedLoadImage(name: "card_tg083")
            return
        }
        
        guard let artworkId = verifyCardResponse?.artworkInfo?.id,
            let cardPublicKey = card.cardPublicKey else {
                backedLoadImage(name: "card_default")
                return
        }
        
        service.request(TangemEndpoint.artwork(cid: cid, cardPublicKey: cardPublicKey, artworkId: artworkId)) {[weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let img = UIImage(data: data) {
                        self?.image = img
                    }
                case .failure(let error):
                    print(error)
                    //TODO: image loading error
                    break
                }
            }
        }
    }
    
    func backedLoadImage(name: String) {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: configuration)
        session
            .dataTaskPublisher(for: URL(string: "https://app.tangem.com/cards/\(name).png")!)
            .subscribe(on: DispatchQueue.global())
            .map { data, response -> UIImage? in
                return UIImage(data: data)
        }
        .catch{ error -> AnyPublisher<UIImage?, Never> in
            print(error)
            return Just(nil).eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.image, on: self)
        .store(in: &bag)
    }
    
    func hasRates(for amount: Amount) -> Bool {
        return rates[amount.currencySymbol] != nil
    }
    
    func getFiatFormatted(for amount: Amount?) -> String? {
        return getFiat(for: amount)?.currencyFormatted(code: selectedCurrency)
    }
    
    func getFiat(for amount: Amount?) -> Decimal? {
        if let amount = amount {
            return getFiat(for: amount.value, currencySymbol: amount.currencySymbol)
        }
        return nil
    }
    
    func getCrypto(for amount: Amount?) -> Decimal? {
        if let amount = amount {
            return getCrypto(for: amount.value, currencySymbol: amount.currencySymbol)
        }
        return nil
    }
    
    func getFiat(for value: Decimal, currencySymbol: String) -> Decimal? {
        if let quotes = rates[currencySymbol],
            let rate = quotes[selectedCurrency] {
            return (value * rate).rounded(2)
        }
        return nil
    }
    
    func getCrypto(for value: Decimal, currencySymbol: String) -> Decimal? {
        if let quotes = rates[currencySymbol],
            let rate = quotes[selectedCurrency] {
            return (value / rate).rounded(blockchain: wallet!.blockchain)
        }
        return nil
    }
    
    private func makeBalanceViewModel(from wallet: Wallet) -> BalanceViewModel? {
        guard self.loadingError != nil || !wallet.amounts.isEmpty else { //not yet loaded
            return self.balanceViewModel
        }
        
        if let token = wallet.token {
            return BalanceViewModel(isToken: true,
                                    hasTransactionInProgress: self.wallet?.hasPendingTx ?? false,
                                    loadingError: self.loadingError?.localizedDescription,
                                    name: token.displayName,
                                    fiatBalance: getFiatFormatted(for: wallet.amounts[.token]) ?? " ",
                                    balance: wallet.amounts[.token]?.description ?? "-",
                                    secondaryBalance: wallet.amounts[.coin]?.description ?? "-",
                                    secondaryFiatBalance: getFiatFormatted(for: wallet.amounts[.coin]) ?? " ",
                                    secondaryName: wallet.blockchain.displayName )
        } else {
            return BalanceViewModel(isToken: false,
                                    hasTransactionInProgress: self.wallet?.hasPendingTx ?? false,
                                    loadingError: self.loadingError?.localizedDescription,
                                    name:  wallet.blockchain.displayName,
                                    fiatBalance: getFiatFormatted(for: wallet.amounts[.coin]) ?? " ",
                                    balance: wallet.amounts[.coin]?.description ?? "-",
                                    secondaryBalance: "-",
                                    secondaryFiatBalance: " ",
                                    secondaryName: "-")
        }
    }
}

enum WalletState {
    case empty
    case initialized
    case loading
    case loaded
    case accountNotCreated(message: String)
    case loadingFailed(message: String)
}

struct BalanceViewModel {
    let isToken: Bool
    let hasTransactionInProgress: Bool
    let loadingError: String?
    let name: String
    let fiatBalance: String
    let balance: String
    let secondaryBalance: String
    let secondaryFiatBalance: String
    let secondaryName: String
}