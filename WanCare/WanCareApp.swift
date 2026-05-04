//
//  WanCareApp.swift
//  WanCare
//
//  Created by shirai on 2026/04/29.
//

import SwiftUI
import SwiftData
import GoogleMobileAds
import StoreKit
import Combine

@main
struct WanCareApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var showingOnboarding = false
    @StateObject private var purchaseManager = PurchaseManager()

    init() {
        #if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["SIMULATOR"]
        #endif
        MobileAds.shared.start()
    }

    let container: ModelContainer = {
        let schema = Schema([CareRecord.self, MealSchedule.self, MedicationSchedule.self, SpecialEvent.self, DogProfile.self, WeightRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("モデルコンテナの作成に失敗しました: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
                .onAppear {
                    if !hasLaunchedBefore {
                        showingOnboarding = true
                        hasLaunchedBefore = true
                    }
                }
                .sheet(isPresented: $showingOnboarding) {
                    OnboardingView(isHelp: false) {
                        showingOnboarding = false
                    }
                }
        }
        .modelContainer(container)
    }
}

// MARK: - Purchase

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isFullUnlocked: Bool
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private enum StorageKey {
        static let isFullUnlocked = "isFullUnlocked"
    }

    enum ProductID {
        // App Store Connectで作成した買い切りのProduct IDに合わせてください。
        static let fullUnlock = "com.shirai.wancare.fullunlock"
    }

    init() {
        self.isFullUnlocked = UserDefaults.standard.bool(forKey: StorageKey.isFullUnlocked)
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [ProductID.fullUnlock])
            products = storeProducts.sorted { $0.displayName < $1.displayName }
        } catch {
            errorMessage = "商品情報の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    func purchaseFullUnlock() async {
        guard let product = products.first(where: { $0.id == ProductID.fullUnlock }) else {
            errorMessage = "購入商品が見つかりません。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await apply(transaction: transaction)
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == ProductID.fullUnlock {
                unlocked = true
            }
        }
        setUnlocked(unlocked)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.apply(transaction: transaction)
                    await transaction.finish()
                } catch {
                    await MainActor.run {
                        self.errorMessage = "取引の確認に失敗しました。"
                    }
                }
            }
        }
    }

    private func apply(transaction: StoreKit.Transaction) async {
        if transaction.productID == ProductID.fullUnlock {
            setUnlocked(true)
        }
    }

    private func setUnlocked(_ unlocked: Bool) {
        isFullUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: StorageKey.isFullUnlocked)
    }

    #if DEBUG
    func debugSetUnlocked(_ unlocked: Bool) {
        setUnlocked(unlocked)
        if unlocked {
            errorMessage = nil
        }
    }
    #endif

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
