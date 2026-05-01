//
//  ScheduleModels.swift
//  sample
//

import Foundation
import SwiftData

@Model
class MealSchedule {
    var id: UUID
    var name: String     // タイトル（例: ごはん１）
    var content: String = "" // 内容（例: ドッグフード）
    var time: String     // "08:00"
    var amount: String   // "80g"
    var sortOrder: Int

    init(name: String, content: String = "", time: String, amount: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.time = time
        self.amount = amount
        self.sortOrder = sortOrder
    }
}

@Model
class MedicationSchedule {
    var id: UUID
    var name: String     // タイトル（例: お薬１）
    var content: String = "" // 内容（例: フィラリア予防薬）
    var time: String     // "09:00"
    var dose: String     // "1錠"
    var sortOrder: Int

    init(name: String, content: String = "", time: String, dose: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.time = time
        self.dose = dose
        self.sortOrder = sortOrder
    }
}

@Model
class SpecialEvent {
    var id: UUID
    var title: String
    var note: String
    var scheduledDate: Date

    init(title: String, note: String = "", scheduledDate: Date) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.scheduledDate = scheduledDate
    }
}

@Model
class DogProfile {
    var name: String
    @Attribute(.externalStorage) var photoData: Data?

    init(name: String = "", photoData: Data? = nil) {
        self.name = name
        self.photoData = photoData
    }
}
