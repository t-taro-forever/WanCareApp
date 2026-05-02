//
//  sampleApp.swift
//  sample
//
//  Created by shirai on 2026/04/29.
//

import SwiftUI
import SwiftData

@main
struct WanCareApp: App {
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
        }
        .modelContainer(container)
    }
}
