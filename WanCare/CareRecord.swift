//
//  CareRecord.swift
//  WanCare
//

import Foundation
import SwiftData

@Model
class CareRecord {
    var id: UUID
    var type: String       // "meal" or "medication"
    var title: String      // 朝ごはん、フィラリア予防薬 など
    var amount: String     // 量・用量
    var recordedAt: Date   // 与えた日時
    var note: String       // メモ
    var isQuickCheck: Bool = false // クイックチェックフラグ

    init(
        type: String,
        title: String,
        amount: String,
        recordedAt: Date = .now,
        note: String = "",
        isQuickCheck: Bool = false
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.amount = amount
        self.recordedAt = recordedAt
        self.note = note
        self.isQuickCheck = isQuickCheck
    }
}
