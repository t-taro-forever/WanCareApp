//
//  DailyNote.swift
//  WanCare
//

import Foundation
import SwiftData

@Model
class DailyNote {
    var id: UUID
    var date: Date   // 日付（start of day）
    var note: String

    init(date: Date, note: String = "") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
    }
}
