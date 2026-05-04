//
//  ContentView.swift
//  WanCare
//
//  Created by shirai on 2026/04/29.
//

import SwiftUI
import SwiftData
import PhotosUI
import Charts
import StoreKit
import UIKit

// MARK: - Root

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "sun.max") }
            MealsView()
                .tabItem { Label("ごはん", systemImage: "fork.knife") }
            MedicationsView()
                .tabItem { Label("お薬", systemImage: "pills") }
            WeightView()
                .tabItem { Label("体重", systemImage: "scalemass") }
            CalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @Query(sort: \CareRecord.recordedAt, order: .reverse) private var records: [CareRecord]
    @Query(sort: \MealSchedule.sortOrder) private var mealSchedules: [MealSchedule]
    @Query(sort: \MedicationSchedule.sortOrder) private var medSchedules: [MedicationSchedule]
    @Query(sort: \SpecialEvent.scheduledDate) private var specialMedSchedules: [SpecialEvent]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weightRecords: [WeightRecord]
    @Query private var profiles: [DogProfile]
    @Query(sort: \DailyNote.date, order: .reverse) private var allDailyNotes: [DailyNote]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var editingRecord: CareRecord?
    @State private var showingProfile = false
    @State private var showingWeightForm = false
    @State private var showingHelp = false
    @State private var showingPremium = false
    @State private var showingMonthlyReport = false
    @State private var todayNoteText: String = ""

    private var profile: DogProfile? { profiles.first }

    private var todayDailyNote: DailyNote? {
        allDailyNotes.first { Calendar.current.isDateInToday($0.date) }
    }

    private var todayWeightRecord: WeightRecord? {
        return weightRecords.first { Calendar.current.isDateInToday($0.recordedAt) }
    }

    private var previousWeightRecord: WeightRecord? {
        guard let current = todayWeightRecord else { return nil }
        return weightRecords.first { $0.id != current.id && $0.recordedAt < current.recordedAt }
    }

    private var todayWeightDelta: Double? {
        guard let current = todayWeightRecord, let previous = previousWeightRecord else { return nil }
        return current.weight - previous.weight
    }

    private var todayRecords: [CareRecord] {
        let start = Calendar.current.startOfDay(for: .now)
        return records.filter { $0.recordedAt >= start }
    }

    private var todaySpecialEvents: [SpecialEvent] {
        specialMedSchedules.filter { Calendar.current.isDateInToday($0.scheduledDate) }
    }

    private var reminderSyncID: String {
        let mealSignature = mealSchedules
            .map { "\($0.id.uuidString)-\($0.time)-\($0.name)-\($0.notificationEnabled)" }
            .sorted()
            .joined(separator: "|")
        let medicationSignature = medSchedules
            .map { "\($0.id.uuidString)-\($0.time)-\($0.name)-\($0.notificationEnabled)" }
            .sorted()
            .joined(separator: "|")
        return "\(purchaseManager.isFullUnlocked)-\(mealSignature)-\(medicationSignature)"
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Profile header
                Section {
                    HStack(spacing: 16) {

                        Group {
                            if let data = profile?.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.brown.opacity(0.3), lineWidth: 2))
                            } else {
                                Image(systemName: "pawprint.circle.fill")
                                    .resizable()
                                    .frame(width: 64, height: 64)
                                    .foregroundStyle(.brown.opacity(0.8))
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = profile?.name, !name.isEmpty {
                                Text(name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            } else {
                                Text("名前未設定")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }
                            Text("今日もいい子！🐾")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)

                if !todaySpecialEvents.isEmpty {
                    Section("今日のイベント") {
                        ForEach(todaySpecialEvents) { event in
                            HStack(spacing: 10) {
                                Image(systemName: SpecialEventFormView.icon(for: event.title))
                                    .foregroundStyle(.purple)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title).font(.headline)
                                    if !event.note.isEmpty {
                                        Text(event.note).font(.caption).foregroundStyle(.secondary)
                                            .lineLimit(1).truncationMode(.tail)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    if let weight = todayWeightRecord {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "scalemass")
                                    .foregroundStyle(.green)
                                Text(String(format: "%.2f kg", weight.weight))
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let delta = todayWeightDelta {
                                HStack(spacing: 6) {
                                    Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                                    Text(String(format: "前回比 %@%.2f kg", delta >= 0 ? "+" : "", delta))
                                }
                                .font(.caption)
                                .foregroundStyle(delta > 0 ? .orange : (delta < 0 ? .blue : .secondary))
                            }
                            if !weight.note.isEmpty {
                                Text(weight.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingWeightForm = true }
                    } else {
                        Button {
                            showingWeightForm = true
                        } label: {
                            Label("体重を記録", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("今日の体重")
                } footer: {
                    Text("タップして体重を入力・編集できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("今日のごはん") {
                    if mealSchedules.isEmpty {
                        Text("予定がありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(mealSchedules) { meal in
                            HStack {
                                Button {
                                    toggleQuickCheck(type: "meal", title: meal.name, amount: meal.amount)
                                } label: {
                                    if isQuickCheckedToday(type: "meal", title: meal.name) {
                                        Image(systemName: "pawprint.fill")
                                            .foregroundStyle(.brown)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meal.name).font(.headline)
                                    Text(meal.time).font(.subheadline).foregroundStyle(.secondary)
                                    if !meal.content.isEmpty {
                                        Text(meal.content).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(meal.amount).font(.subheadline)
                            }
                        }
                    }
                }

                Section("今日のお薬") {
                    if medSchedules.isEmpty {
                        Text("予定がありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(medSchedules) { medication in
                            HStack {
                                Button {
                                    toggleQuickCheck(type: "medication", title: medication.name, amount: medication.dose)
                                } label: {
                                    if isQuickCheckedToday(type: "medication", title: medication.name) {
                                        Image(systemName: "pawprint.fill")
                                            .foregroundStyle(.brown)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(medication.name).font(.headline)
                                    Text(medication.time).font(.subheadline).foregroundStyle(.secondary)
                                    if !medication.content.isEmpty {
                                        Text(medication.content).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(medication.dose).font(.subheadline)
                            }
                        }
                    }
                }

                if !todayRecords.isEmpty {
                    Section {
                        ForEach(todayRecords) { record in
                            RecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRecord = record
                                }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(todayRecords[$0]) }
                        }
                    } header: {
                        Text("今日の記録")
                    } footer: {
                        Text("タップで編集・左スワイプで削除できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Today Memo
                Section {
                    TextEditor(text: $todayNoteText)
                        .frame(minHeight: 80)
                } header: {
                    Text("今日のメモ")
                } footer: {
                    Text("入力内容は自動的に保存されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: todayNoteText) { _, newValue in
                    saveTodayNote(newValue)
                }

                Section {
                    if purchaseManager.isFullUnlocked {
                        Button {
                            showingMonthlyReport = true
                        } label: {
                            Label("月次レポートをPDF出力", systemImage: "doc.richtext")
                        }
                    } else {
                        Button {
                            showingPremium = true
                        } label: {
                            Label("有料版を購入（広告なし + 追加機能）", systemImage: "lock.open")
                        }
                    }
                } header: {
                    Text("有料版")
                } footer: {
                    Text(purchaseManager.isFullUnlocked ? "購入済みです。広告は表示されません。月次レポートのPDF出力とごはん・お薬通知が使えます。" : "購入すると広告が非表示になり、月次レポートのPDF出力とごはん・お薬通知が使えます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .safeAreaInset(edge: .bottom) {
                if !purchaseManager.isFullUnlocked {
                    BannerAdView(adUnitID: AdUnitID.banner)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("わんケア")
                            .font(.headline)
                        Text("愛犬のごはん・お薬・体重管理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPremium = true
                    } label: {
                        Image(systemName: purchaseManager.isFullUnlocked ? "checkmark.seal.fill" : "crown")
                    }
                }
            }
            .sheet(isPresented: $showingPremium) {
                PremiumPurchaseView()
                    .environmentObject(purchaseManager)
            }
            .sheet(isPresented: $showingMonthlyReport) {
                PremiumMonthlyReportView()
            }
            .sheet(isPresented: $showingHelp) {
                OnboardingView(isHelp: true) {
                    showingHelp = false
                }
            }
            .sheet(isPresented: $showingProfile) {
                DogProfileFormView()
            }
            .sheet(isPresented: $showingWeightForm) {
                WeightRecordFormView(
                    initialWeight: todayWeightRecord.map { String(format: "%.2f", $0.weight) },
                    initialRecordedAt: todayWeightRecord?.recordedAt,
                    initialNote: todayWeightRecord?.note,
                    editingRecord: todayWeightRecord
                )
            }
            .sheet(item: $editingRecord) { record in
                RecordFormView(
                    type: record.type,
                    presetTitles: record.type == "meal" ? mealSchedules.map(\.name) : medSchedules.map(\.name),
                    initialTitle: record.title,
                    initialAmount: record.amount,
                    initialRecordedAt: record.recordedAt,
                    initialNote: record.note,
                    editingRecord: record
                )
            }
            .task(id: reminderSyncID) {
                await NotificationManager.syncDailyReminders(
                    mealSchedules: mealSchedules,
                    medicationSchedules: medSchedules,
                    isPremiumEnabled: purchaseManager.isFullUnlocked
                )
            }
            .onAppear {
                todayNoteText = todayDailyNote?.note ?? ""
            }
            .onChange(of: todayDailyNote?.note) { _, newValue in
                let v = newValue ?? ""
                if v != todayNoteText { todayNoteText = v }
            }
        }
    }

    private func isQuickCheckedToday(type: String, title: String) -> Bool {
        records.contains {
            $0.type == type &&
            $0.title == title &&
            $0.isQuickCheck &&
            Calendar.current.isDateInToday($0.recordedAt)
        }
    }

    private func toggleQuickCheck(type: String, title: String, amount: String) {
        let todayQuickChecks = records.filter {
            $0.type == type &&
            $0.title == title &&
            $0.isQuickCheck &&
            Calendar.current.isDateInToday($0.recordedAt)
        }

        if todayQuickChecks.isEmpty {
            context.insert(CareRecord(type: type, title: title, amount: amount, recordedAt: .now, isQuickCheck: true))
        } else {
            todayQuickChecks.forEach { context.delete($0) }
        }
    }

    private func saveTodayNote(_ text: String) {
        if let existing = todayDailyNote {
            existing.note = text
        } else if !text.isEmpty {
            let newNote = DailyNote(date: .now, note: text)
            context.insert(newNote)
        }
    }
}

// MARK: - Meals

struct MealsView: View {
    @Query(sort: \MealSchedule.sortOrder) private var schedules: [MealSchedule]
    @Query(
        filter: #Predicate<CareRecord> { $0.type == "meal" },
        sort: \CareRecord.recordedAt,
        order: .reverse
    ) private var records: [CareRecord]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showingRecordForm = false
    @State private var showingScheduleForm = false
    @State private var editingSchedule: MealSchedule? = nil
    @State private var editingRecord: CareRecord? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(schedules) { meal in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.name).font(.headline)
                                if !meal.content.isEmpty {
                                    Text(meal.content).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("時間: \(meal.time)  量: \(meal.amount)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: meal.notificationEnabled ? "bell.fill" : "bell.slash")
                                .foregroundStyle(meal.notificationEnabled ? .yellow : .secondary)
                            Button {
                                let copy = MealSchedule(
                                    name: meal.name,
                                    content: meal.content,
                                    time: meal.time,
                                    amount: meal.amount,
                                    notificationEnabled: meal.notificationEnabled,
                                    sortOrder: schedules.count
                                )
                                context.insert(copy)
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingSchedule = meal
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(meal)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        var updated = schedules
                        updated.move(fromOffsets: fromOffsets, toOffset: toOffset)
                        for (index, schedule) in updated.enumerated() {
                            schedule.sortOrder = index
                        }
                    }
                    Button {
                        showingScheduleForm = true
                    } label: {
                        Label("予定を追加", systemImage: "plus.circle")
                    }
                } header: {
                    Text("ごはんスケジュール")
                } footer: {
                    Text(purchaseManager.isFullUnlocked ? "タップで編集・左スワイプで削除・ドラッグで並び替え（通知設定の変更可）" : "タップで編集・左スワイプで削除・ドラッグで並び替え（通知設定は有料版で利用できます）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if records.isEmpty {
                        Text("まだ記録がありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            RecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRecord = record
                                }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(records[$0]) }
                        }
                    }
                } header: {
                    Text("記録一覧")
                } footer: {
                    Text("タップで編集・左スワイプで削除できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("ごはん")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingRecordForm = true } label: {
                        Label("記録する", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                RecordFormView(
                    type: "meal",
                    presetTitles: schedules.map(\.name).isEmpty
                        ? ["朝ごはん", "夜ごはん"]
                        : schedules.map(\.name)
                )
            }
            .sheet(isPresented: $showingScheduleForm) {
                MealScheduleFormView()
            }
            .sheet(item: $editingSchedule) { schedule in
                MealScheduleFormView(editing: schedule)
            }
            .sheet(item: $editingRecord) { record in
                RecordFormView(
                    type: "meal",
                    presetTitles: schedules.map(\.name).isEmpty ? ["朝ごはん", "夜ごはん"] : schedules.map(\.name),
                    initialTitle: record.title,
                    initialAmount: record.amount,
                    initialRecordedAt: record.recordedAt,
                    initialNote: record.note,
                    editingRecord: record
                )
            }
        }
        .onAppear { insertDefaultMealSchedulesIfNeeded(context: context, schedules: schedules) }
    }
}

// MARK: - Weight

struct WeightView: View {
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var records: [WeightRecord]
    @Environment(\.modelContext) private var context

    @State private var showingRecordForm = false
    @State private var editingRecord: WeightRecord? = nil

    var body: some View {
        NavigationStack {
            List {
                if !records.isEmpty {
                    Section("体重の推移") {
                        VStack(alignment: .leading, spacing: 12) {
                            Chart {
                                ForEach(records) { record in
                                    LineMark(
                                        x: .value("日付", record.recordedAt),
                                        y: .value("体重(kg)", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                    PointMark(
                                        x: .value("日付", record.recordedAt),
                                        y: .value("体重(kg)", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                }
                            }
                            .chartYAxisLabel("体重(kg)", position: .leading)
                            .chartXAxisLabel("日付", position: .bottom)
                            .frame(height: 250)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section("記録一覧") {
                    if records.isEmpty {
                        Text("まだ記録がありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            WeightRecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRecord = record
                                }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(records[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("体重")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingRecordForm = true } label: {
                        Label("記録する", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                WeightRecordFormView()
            }
            .sheet(item: $editingRecord) { record in
                WeightRecordFormView(
                    initialWeight: String(format: "%.2f", record.weight),
                    initialRecordedAt: record.recordedAt,
                    initialNote: record.note,
                    editingRecord: record
                )
            }
        }
    }
}

// MARK: - Medications

struct MedicationsView: View {
    @Query(sort: \MedicationSchedule.sortOrder) private var schedules: [MedicationSchedule]
    @Query(
        filter: #Predicate<CareRecord> { $0.type == "medication" },
        sort: \CareRecord.recordedAt,
        order: .reverse
    ) private var records: [CareRecord]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showingRecordForm = false
    @State private var showingScheduleForm = false
    @State private var editingSchedule: MedicationSchedule? = nil
    @State private var editingRecord: CareRecord? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/M/d（E）"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(schedules) { medication in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(medication.name).font(.headline)
                                if !medication.content.isEmpty {
                                    Text(medication.content).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("時間: \(medication.time)  用量: \(medication.dose)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: medication.notificationEnabled ? "bell.fill" : "bell.slash")
                                .foregroundStyle(medication.notificationEnabled ? .yellow : .secondary)
                            Button {
                                let copy = MedicationSchedule(
                                    name: medication.name,
                                    content: medication.content,
                                    time: medication.time,
                                    dose: medication.dose,
                                    notificationEnabled: medication.notificationEnabled,
                                    sortOrder: schedules.count
                                )
                                context.insert(copy)
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingSchedule = medication
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(medication)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        var updated = schedules
                        updated.move(fromOffsets: fromOffsets, toOffset: toOffset)
                        for (index, schedule) in updated.enumerated() {
                            schedule.sortOrder = index
                        }
                    }
                    Button {
                        showingScheduleForm = true
                    } label: {
                        Label("予定を追加", systemImage: "plus.circle")
                    }
                } header: {
                    Text("お薬スケジュール")
                } footer: {
                    Text(purchaseManager.isFullUnlocked ? "タップで編集・左スワイプで削除・ドラッグで並び替え（通知設定の変更可）" : "タップで編集・左スワイプで削除・ドラッグで並び替え（通知設定は有料版で利用できます）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if records.isEmpty {
                        Text("まだ記録がありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            RecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRecord = record
                                }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(records[$0]) }
                        }
                    }
                } header: {
                    Text("記録一覧")
                } footer: {
                    Text("タップで編集・左スワイプで削除できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("お薬")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingRecordForm = true } label: {
                        Label("記録する", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                RecordFormView(
                    type: "medication",
                    presetTitles: schedules.map(\.name).isEmpty
                        ? ["フィラリア予防薬", "皮膚ケアサプリ"]
                        : schedules.map(\.name)
                )
            }
            .sheet(isPresented: $showingScheduleForm) {
                MedicationScheduleFormView()
            }
            .sheet(item: $editingSchedule) { schedule in
                MedicationScheduleFormView(editing: schedule)
            }
            .sheet(item: $editingRecord) { record in
                RecordFormView(
                    type: "medication",
                    presetTitles: schedules.map(\.name).isEmpty ? ["フィラリア予防薬", "皮膚ケアサプリ"] : schedules.map(\.name),
                    initialTitle: record.title,
                    initialAmount: record.amount,
                    initialRecordedAt: record.recordedAt,
                    initialNote: record.note,
                    editingRecord: record
                )
            }
        }
        .onAppear { insertDefaultMedSchedulesIfNeeded(context: context, schedules: schedules) }
    }
}

// MARK: - MealScheduleFormView

struct MealScheduleFormView: View {
    var editing: MealSchedule? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \MealSchedule.sortOrder) private var all: [MealSchedule]

    @State private var name = ""
    @State private var content = ""
    @State private var selectedTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var amount = ""
    @State private var notificationEnabled = false

    private var isValid: Bool { !name.isEmpty }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例: ごはん１", text: $name)
                }
                Section("内容（任意）") {
                    TextField("例: ドッグフード", text: $content)
                }
                Section("時間") {
                    DatePicker("時間を選択", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section("通知") {
                    Toggle("このスケジュールを通知する", isOn: $notificationEnabled)
                        .disabled(!purchaseManager.isFullUnlocked)
                    if !purchaseManager.isFullUnlocked {
                        Text("通知設定は有料版で利用できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("量（任意）") {
                    TextField("例: 80g", text: $amount)
                }
            }
            .navigationTitle(editing == nil ? "予定を追加" : "予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let timeStr = Self.timeFormatter.string(from: selectedTime)
                        if let s = editing {
                            s.name = name
                            s.content = content
                            s.time = timeStr
                            s.amount = amount
                            s.notificationEnabled = notificationEnabled
                        } else {
                            let s = MealSchedule(
                                name: name,
                                content: content,
                                time: timeStr,
                                amount: amount,
                                notificationEnabled: notificationEnabled,
                                sortOrder: all.count
                            )
                            context.insert(s)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let s = editing {
                    name = s.name
                    content = s.content
                    amount = s.amount
                    notificationEnabled = s.notificationEnabled
                    if let date = Self.timeFormatter.date(from: s.time) {
                        selectedTime = Calendar.current.date(
                            bySettingHour: Calendar.current.component(.hour, from: date),
                            minute: Calendar.current.component(.minute, from: date),
                            second: 0, of: .now
                        ) ?? selectedTime
                    }
                }
            }
        }
    }
}

// MARK: - MedicationScheduleFormView

struct MedicationScheduleFormView: View {
    var editing: MedicationSchedule? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \MedicationSchedule.sortOrder) private var all: [MedicationSchedule]

    @State private var name = ""
    @State private var content = ""
    @State private var selectedTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var dose = ""
    @State private var notificationEnabled = false

    private var isValid: Bool { !name.isEmpty }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例: お薬１", text: $name)
                }
                Section("内容（任意）") {
                    TextField("例: フィラリア予防薬", text: $content)
                }
                Section("時間") {
                    DatePicker("時間を選択", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section("通知") {
                    Toggle("このスケジュールを通知する", isOn: $notificationEnabled)
                        .disabled(!purchaseManager.isFullUnlocked)
                    if !purchaseManager.isFullUnlocked {
                        Text("通知設定は有料版で利用できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("用量（任意）") {
                    TextField("例: 1錠", text: $dose)
                }
            }
            .navigationTitle(editing == nil ? "予定を追加" : "予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let timeStr = Self.timeFormatter.string(from: selectedTime)
                        if let s = editing {
                            s.name = name
                            s.content = content
                            s.time = timeStr
                            s.dose = dose
                            s.notificationEnabled = notificationEnabled
                        } else {
                            let s = MedicationSchedule(
                                name: name,
                                content: content,
                                time: timeStr,
                                dose: dose,
                                notificationEnabled: notificationEnabled,
                                sortOrder: all.count
                            )
                            context.insert(s)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let s = editing {
                    name = s.name
                    content = s.content
                    dose = s.dose
                    notificationEnabled = s.notificationEnabled
                    if let date = Self.timeFormatter.date(from: s.time) {
                        selectedTime = Calendar.current.date(
                            bySettingHour: Calendar.current.component(.hour, from: date),
                            minute: Calendar.current.component(.minute, from: date),
                            second: 0, of: .now
                        ) ?? selectedTime
                    }
                }
            }
        }
    }
}

// MARK: - DogProfileFormView

struct DogProfileFormView: View {
    @Query private var profiles: [DogProfile]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var photoData: Data? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil

    private var profile: DogProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Group {
                                if let data = photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.brown.opacity(0.4), lineWidth: 2))
                                } else {
                                    Image(systemName: "pawprint.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundStyle(.brown.opacity(0.7))
                                }
                            }
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("写真を選択", systemImage: "photo")
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("名前") {
                    TextField("わんちゃんの名前", text: $name)
                }
            }
            .navigationTitle("プロフィール設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let p = profile {
                            p.name = name
                            if let data = photoData { p.photoData = data }
                        } else {
                            let p = DogProfile(name: name, photoData: photoData)
                            context.insert(p)
                        }
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                if let p = profile {
                    name = p.name
                    photoData = p.photoData
                }
            }
        }
    }
}

// MARK: - SpecialEventFormView

struct SpecialEventFormView: View {
    var editing: SpecialEvent? = nil
    var initialDate: Date = .now

    static let categories = ["病院", "お薬", "狂犬病", "ノミダニ", "フィラリア", "ワクチン", "トリミング", "誕生日", "その他"]

    static let categoryIcons: [String: String] = [
        "病院": "cross.case.fill",
        "お薬": "pills.fill",
        "狂犬病": "syringe.fill",
        "ノミダニ": "ladybug.fill",
        "フィラリア": "heart.text.square.fill",
        "ワクチン": "syringe",
        "トリミング": "scissors",
        "誕生日": "gift.fill",
        "その他": "ellipsis.circle"
    ]

    static func icon(for title: String) -> String {
        categoryIcons[title] ?? "ellipsis.circle"
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String
    @State private var customTitle: String
    @State private var note: String
    @State private var scheduledDate: Date

    init(editing: SpecialEvent? = nil, initialDate: Date = .now) {
        self.editing = editing
        self.initialDate = initialDate
        let savedTitle = editing?.title ?? ""
        let isPreset = Self.categories.dropLast().contains(savedTitle) // "その他" 以外の候補にあるか
        self._selectedCategory = State(initialValue: isPreset ? savedTitle : "その他")
        self._customTitle = State(initialValue: isPreset ? "" : savedTitle)
        self._note = State(initialValue: editing?.note ?? "")
        self._scheduledDate = State(initialValue: Calendar.current.startOfDay(for: editing?.scheduledDate ?? initialDate))
    }

    private var isCustom: Bool { selectedCategory == "その他" }
    private var resolvedTitle: String { isCustom ? customTitle : selectedCategory }
    private var isValid: Bool { isCustom ? !customTitle.isEmpty : true }

    var body: some View {
        NavigationStack {
            Form {
                Section("種別") {
                    Picker("種別を選択", selection: $selectedCategory) {
                        ForEach(Self.categories, id: \.self) { category in
                            Label(category, systemImage: Self.icon(for: category)).tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if isCustom {
                    Section("タイトル（手入力）") {
                        TextField("例: 爪切り、体重測定など", text: $customTitle)
                    }
                }
                Section("メモ（任意）") {
                    TextEditor(text: $note)
                        .frame(minHeight: 60)
                }
                Section("予定日") {
                    DatePicker("日付を選択", selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
            }
            .navigationTitle(editing == nil ? "イベントを追加" : "イベントを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let event = editing {
                            event.title = resolvedTitle
                            event.note = note
                            event.scheduledDate = scheduledDate
                        } else {
                            let event = SpecialEvent(
                                title: resolvedTitle,
                                note: note,
                                scheduledDate: scheduledDate
                            )
                            context.insert(event)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Default seed helpers

private func insertDefaultMealSchedulesIfNeeded(context: ModelContext, schedules: [MealSchedule]) {
    guard schedules.isEmpty else { return }
    let defaults = [
        MealSchedule(name: "朝ごはん", time: "08:00", amount: "80g", sortOrder: 0),
        MealSchedule(name: "夜ごはん", time: "18:30", amount: "90g", sortOrder: 1),
    ]
    defaults.forEach { context.insert($0) }
}

private func insertDefaultMedSchedulesIfNeeded(context: ModelContext, schedules: [MedicationSchedule]) {
    guard schedules.isEmpty else { return }
    let defaults = [
        MedicationSchedule(name: "フィラリア予防薬", time: "09:00", dose: "1錠", sortOrder: 0),
        MedicationSchedule(name: "皮膚ケアサプリ", time: "20:00", dose: "5mL", sortOrder: 1),
    ]
    defaults.forEach { context.insert($0) }
}

// MARK: - WeightRecordFormView

struct WeightRecordFormView: View {
    let initialWeight: String?
    let initialRecordedAt: Date?
    let initialNote: String?
    let editingRecord: WeightRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weight: String = ""
    @State private var recordedAt: Date = .now
    @State private var note: String = ""

    init(
        initialWeight: String? = nil,
        initialRecordedAt: Date? = nil,
        initialNote: String? = nil,
        editingRecord: WeightRecord? = nil
    ) {
        self.initialWeight = initialWeight
        self.initialRecordedAt = initialRecordedAt
        self.initialNote = initialNote
        self.editingRecord = editingRecord
    }

    private var isValid: Bool { !weight.isEmpty && Double(weight) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("体重（kg）") {
                    TextField("例: 12.5", text: $weight)
                        .keyboardType(.decimalPad)
                }

                Section("日時") {
                    DatePicker("測定日時", selection: $recordedAt, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("メモ（任意）") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(editingRecord == nil ? "体重を記録" : "体重を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let weightDouble = Double(weight) {
                            if let editingRecord {
                                editingRecord.weight = weightDouble
                                editingRecord.recordedAt = recordedAt
                                editingRecord.note = note
                            } else {
                                let record = WeightRecord(
                                    weight: weightDouble,
                                    recordedAt: recordedAt,
                                    note: note
                                )
                                context.insert(record)
                            }
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let initialWeight { weight = initialWeight }
                if let initialRecordedAt { recordedAt = initialRecordedAt }
                if let initialNote { note = initialNote }
            }
        }
    }
}

// MARK: - WeightRecordRow

struct WeightRecordRow: View {
    let record: WeightRecord

    private var normalizedNote: String {
        record.note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundStyle(.green)
                Text(String(format: "%.2f kg", record.weight)).font(.headline)
                Spacer()
            }
            Text(Self.timeFormatter.string(from: record.recordedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !normalizedNote.isEmpty {
                Text(normalizedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RecordRow

struct RecordRow: View {
    let record: CareRecord

    private var normalizedNote: String {
        record.note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: record.type == "meal" ? "fork.knife" : "pills")
                    .foregroundStyle(record.type == "meal" ? .orange : .blue)
                Text(record.title).font(.headline)
                Spacer()
                Text(record.amount).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(Self.timeFormatter.string(from: record.recordedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !normalizedNote.isEmpty {
                Text(normalizedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RecordFormView

struct RecordFormView: View {
    let type: String
    let presetTitles: [String]
    let initialTitle: String?
    let initialAmount: String?
    let initialRecordedAt: Date?
    let initialNote: String?
    let editingRecord: CareRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTitle: String = ""
    @State private var customTitle: String = ""
    @State private var amount: String = ""
    @State private var recordedAt: Date = .now
    @State private var note: String = ""
    @State private var useCustomTitle = false

    init(
        type: String,
        presetTitles: [String],
        initialTitle: String? = nil,
        initialAmount: String? = nil,
        initialRecordedAt: Date? = nil,
        initialNote: String? = nil,
        editingRecord: CareRecord? = nil
    ) {
        self.type = type
        self.presetTitles = presetTitles
        self.initialTitle = initialTitle
        self.initialAmount = initialAmount
        self.initialRecordedAt = initialRecordedAt
        self.initialNote = initialNote
        self.editingRecord = editingRecord
    }

    private var isValid: Bool {
        let title = useCustomTitle ? customTitle : selectedTitle
        return !title.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("種類") {
                    Picker("名前", selection: $selectedTitle) {
                        ForEach(presetTitles, id: \.self) { Text($0) }
                        Text("その他").tag("__custom__")
                    }
                    .onChange(of: selectedTitle) { _, new in
                        useCustomTitle = (new == "__custom__")
                    }
                    if useCustomTitle {
                        TextField("名前を入力", text: $customTitle)
                    }
                }

                Section("与えた量（任意）") {
                    TextField(type == "meal" ? "例: 80g" : "例: 1錠", text: $amount)
                        .keyboardType(.default)
                }

                Section("日時") {
                    DatePicker("与えた日時", selection: $recordedAt, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("メモ（任意）") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(type == "meal" ? "ごはん記録" : "お薬記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let title = useCustomTitle ? customTitle : selectedTitle
                        if let editingRecord {
                            editingRecord.type = type
                            editingRecord.title = title
                            editingRecord.amount = amount
                            editingRecord.recordedAt = recordedAt
                            editingRecord.note = note
                        } else {
                            let record = CareRecord(
                                type: type,
                                title: title,
                                amount: amount,
                                recordedAt: recordedAt,
                                note: note
                            )
                            context.insert(record)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                let title = initialTitle ?? presetTitles.first ?? ""
                if title == "" {
                    selectedTitle = ""
                } else if presetTitles.contains(title) {
                    selectedTitle = title
                    useCustomTitle = false
                } else {
                    selectedTitle = "__custom__"
                    customTitle = title
                    useCustomTitle = true
                }
                if let initialAmount { amount = initialAmount }
                if let initialRecordedAt { recordedAt = initialRecordedAt }
                if let initialNote { note = initialNote }
            }
        }
    }
}

// MARK: - Premium

private struct PremiumPurchaseView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("広告を非表示", systemImage: "nosign")
                    Label("月次レポートをPDF出力", systemImage: "doc.richtext")
                    Label("ごはん・お薬の時間通知", systemImage: "bell.badge")
                } header: {
                    Text("有料版でできること")
                }

                Section {
                    if purchaseManager.isFullUnlocked {
                        Label("購入済み", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        if let product = purchaseManager.products.first(where: { $0.id == PurchaseManager.ProductID.fullUnlock }) {
                            Button {
                                Task { await purchaseManager.purchaseFullUnlock() }
                            } label: {
                                HStack {
                                    Text("有料版を購入")
                                    Spacer()
                                    Text(product.displayPrice)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            ProgressView("商品情報を読み込み中...")
                        }
                    }

                    Button("購入を復元") {
                        Task { await purchaseManager.restorePurchases() }
                    }
                    .disabled(purchaseManager.isLoading)
                }

                #if DEBUG
                Section {
                    Button("有料版をON（ローカルテスト）") {
                        purchaseManager.debugSetUnlocked(true)
                    }
                    Button("有料版をOFF（ローカルテスト）") {
                        purchaseManager.debugSetUnlocked(false)
                    }
                } header: {
                    Text("開発用テスト")
                } footer: {
                    Text("DEBUGビルドでのみ表示されます。広告表示切替と追加機能解放の確認に使えます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif

                if let error = purchaseManager.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } header: {
                        Text("エラー")
                    }
                }
            }
            .navigationTitle("有料版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct PremiumMonthlyReportView: View {
    private enum ReportEntryKind {
        case meal
        case medication
        case weight

        var color: UIColor {
            switch self {
            case .meal: return .systemOrange
            case .medication: return .systemBlue
            case .weight: return .systemGreen
            }
        }
    }

    private struct ReportEntry {
        let recordedAt: Date
        let kind: ReportEntryKind
        let text: String
        let note: String
    }

    @Query(sort: \CareRecord.recordedAt, order: .reverse) private var records: [CareRecord]
    @Query(sort: \WeightRecord.recordedAt, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \DailyNote.date) private var allDailyNotes: [DailyNote]
    @Environment(\.dismiss) private var dismiss

    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var generationError: String?
    @State private var selectedReportMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now

    private var reportMonthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedReportMonth)) ?? .now
    }

    private var reportMonthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: reportMonthStart) ?? .now
    }

    private var monthRecords: [CareRecord] {
        records.filter { $0.recordedAt >= reportMonthStart && $0.recordedAt < reportMonthEnd }
    }

    private var monthWeights: [WeightRecord] {
        weights.filter { $0.recordedAt >= reportMonthStart && $0.recordedAt < reportMonthEnd }
    }

    private var monthDailyNotes: [DailyNote] {
        allDailyNotes.filter { $0.date >= reportMonthStart && $0.date < reportMonthEnd && !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var mealCount: Int { monthRecords.filter { $0.type == "meal" }.count }
    private var medicationCount: Int { monthRecords.filter { $0.type == "medication" }.count }
    private var averageWeight: Double? {
        guard !monthWeights.isEmpty else { return nil }
        let sum = monthWeights.reduce(0) { $0 + $1.weight }
        return sum / Double(monthWeights.count)
    }

    private var detailEntries: [ReportEntry] {
        let careEntries = monthRecords.map { record in
            let kind = record.type == "meal" ? "ごはん" : "お薬"
            let amountText = record.amount.isEmpty ? "" : "（\(record.amount)）"
            return ReportEntry(
                recordedAt: record.recordedAt,
                kind: record.type == "meal" ? .meal : .medication,
                text: "\(kind): \(record.title)\(amountText)",
                note: normalizeNote(record.note)
            )
        }

        let weightEntries = monthWeights.map { record in
            ReportEntry(
                recordedAt: record.recordedAt,
                kind: .weight,
                text: String(format: "体重: %.2f kg", record.weight),
                note: normalizeNote(record.note)
            )
        }

        return (careEntries + weightEntries).sorted { $0.recordedAt < $1.recordedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("対象年月") {
                    DatePicker("年月を選択", selection: $selectedReportMonth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .onChange(of: selectedReportMonth) { _, newValue in
                            selectedReportMonth = Calendar.current.date(
                                from: Calendar.current.dateComponents([.year, .month], from: newValue)
                            ) ?? newValue
                        }
                }

                Section("\(Self.monthFormatter.string(from: reportMonthStart))のサマリー") {
                    LabeledContent("ごはん記録") { Text("\(mealCount)回") }
                    LabeledContent("お薬記録") { Text("\(medicationCount)回") }
                    LabeledContent("体重記録") { Text("\(monthWeights.count)回") }
                    LabeledContent("体重平均") {
                        if let averageWeight {
                            Text(String(format: "%.2f kg", averageWeight))
                        } else {
                            Text("データなし").foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        exportMonthlyPDF()
                    } label: {
                        Label("月次レポートをPDF出力", systemImage: "square.and.arrow.up")
                    }

                    if let generatedPDFURL {
                        Text(generatedPDFURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("今月の記録を1枚のPDFにまとめて共有できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let generationError {
                    Section {
                        Text(generationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } header: {
                        Text("エラー")
                    }
                }
            }
            .navigationTitle("月次レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let generatedPDFURL {
                    ActivityView(activityItems: [generatedPDFURL])
                }
            }
        }
    }

    private func exportMonthlyPDF() {
        do {
            let url = try generatePDF()
            generatedPDFURL = url
            showingShareSheet = true
            generationError = nil
        } catch {
            generationError = "PDF出力に失敗しました: \(error.localizedDescription)"
        }
    }

    private func generatePDF() throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let smallFont = UIFont.systemFont(ofSize: 12)

            var y: CGFloat = 40
            let left: CGFloat = 32
            let lineHeight: CGFloat = 24

            ("WanCare 月次レポート" as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                .font: titleFont
            ])
            y += 40

            let monthText = "対象月: \(Self.monthFormatter.string(from: reportMonthStart))"
            (monthText as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                .font: bodyFont
            ])
            y += lineHeight * 1.5

            let lines = [
                "ごはん記録: \(mealCount)回",
                "お薬記録: \(medicationCount)回",
                "体重記録: \(monthWeights.count)回",
                averageWeight.map { String(format: "体重平均: %.2f kg", $0) } ?? "体重平均: データなし"
            ]

            for line in lines {
                (line as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                    .font: bodyFont
                ])
                y += lineHeight
            }

            y += 20
            ("※ このレポートはWanCareアプリで自動生成されました。" as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                .font: smallFont,
                .foregroundColor: UIColor.secondaryLabel
            ])

            y += 32
            if y > pageRect.height - 80 {
                context.beginPage()
                y = 40
            }

            ("日別明細（時刻つき）" as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
            ])
            y += 28

            ("凡例: ごはん(橙) / お薬(青) / 体重(緑)" as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                .font: smallFont,
                .foregroundColor: UIColor.secondaryLabel
            ])
            y += 22

            let grouped = Dictionary(grouping: detailEntries) {
                Calendar.current.startOfDay(for: $0.recordedAt)
            }
            let sortedDays = grouped.keys.sorted()

            for day in sortedDays {
                if y > pageRect.height - 80 {
                    context.beginPage()
                    y = 40
                }

                let dayTitle = Self.dayFormatter.string(from: day)
                (dayTitle as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold)
                ])
                y += 22

                let dayEntries = (grouped[day] ?? []).sorted { $0.recordedAt < $1.recordedAt }
                for entry in dayEntries {
                    if y > pageRect.height - 60 {
                        context.beginPage()
                        y = 40
                    }
                    let timeText = Self.timeFormatter.string(from: entry.recordedAt)
                    let line = "・\(timeText)  \(entry.text)"
                    (line as NSString).draw(at: CGPoint(x: left + 8, y: y), withAttributes: [
                        .font: smallFont,
                        .foregroundColor: entry.kind.color
                    ])
                    y += 18

                    if !entry.note.isEmpty {
                        let noteAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 11),
                            .foregroundColor: UIColor.secondaryLabel
                        ]
                        let noteMaxWidth = pageRect.width - (left + 8) - 32
                        let noteLineHeight: CGFloat = 16
                        let noteText = "   メモ: \(entry.note)"
                        let wrappedNoteLines = wrappedLines(noteText, maxWidth: noteMaxWidth, attributes: noteAttributes)

                        for noteLine in wrappedNoteLines {
                            if y > pageRect.height - 60 {
                                context.beginPage()
                                y = 40
                            }
                            (noteLine as NSString).draw(at: CGPoint(x: left + 8, y: y), withAttributes: noteAttributes)
                            y += noteLineHeight
                        }
                    }
                }

                y += 10
            }

            // Daily Notes section
            let noteEntries = monthDailyNotes.sorted { $0.date < $1.date }
            if !noteEntries.isEmpty {
                if y > pageRect.height - 80 {
                    context.beginPage()
                    y = 40
                }
                ("メモ一覧" as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
                ])
                y += 28

                for noteEntry in noteEntries {
                    if y > pageRect.height - 80 {
                        context.beginPage()
                        y = 40
                    }
                    let dayLabel = Self.dayFormatter.string(from: noteEntry.date)
                    (dayLabel as NSString).draw(at: CGPoint(x: left, y: y), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14, weight: .bold)
                    ])
                    y += 22

                    let noteAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.label
                    ]
                    let noteMaxWidth = pageRect.width - left - 32
                    let noteWrapped = wrappedLines(noteEntry.note.trimmingCharacters(in: .whitespacesAndNewlines), maxWidth: noteMaxWidth, attributes: noteAttributes)
                    for line in noteWrapped {
                        if y > pageRect.height - 60 {
                            context.beginPage()
                            y = 40
                        }
                        (line as NSString).draw(at: CGPoint(x: left + 8, y: y), withAttributes: noteAttributes)
                        y += 18
                    }
                    y += 8
                }
            }
        }

        let fileName = "WanCare_MonthlyReport_\(Self.fileFormatter.string(from: reportMonthStart)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let fileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMM"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d（E）"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func normalizeNote(_ note: String) -> String {
        note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func wrappedLines(_ text: String, maxWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> [String] {
        guard !text.isEmpty else { return [] }

        var lines: [String] = []
        var current = ""

        for scalar in text {
            let next = current + String(scalar)
            let nextWidth = (next as NSString).size(withAttributes: attributes).width

            if nextWidth <= maxWidth || current.isEmpty {
                current = next
            } else {
                lines.append(current)
                current = String(scalar)
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .modelContainer(for: [CareRecord.self, MealSchedule.self, MedicationSchedule.self, SpecialEvent.self, DogProfile.self, WeightRecord.self], inMemory: true)
}

// 括弧修正用

// 括弧修正用

// 括弧修正用

// 括弧修正用

// 括弧修正用

// 括弧修正用

// 括弧修正用

// 括弧修正用
