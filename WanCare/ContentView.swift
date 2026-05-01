//
//  ContentView.swift
//  sample
//
//  Created by shirai on 2026/04/29.
//

import SwiftUI
import SwiftData
import PhotosUI

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
    @Query private var profiles: [DogProfile]
    @Environment(\.modelContext) private var context
    @State private var editingRecord: CareRecord?
    @State private var showingProfile = false

    private var profile: DogProfile? { profiles.first }

    private var todayRecords: [CareRecord] {
        let start = Calendar.current.startOfDay(for: .now)
        return records.filter { $0.recordedAt >= start }
    }

    private var todaySpecialEvents: [SpecialEvent] {
        specialMedSchedules.filter { Calendar.current.isDateInToday($0.scheduledDate) }
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
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
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

                if !todaySpecialEvents.isEmpty {
                    Section("今日のその他イベント") {
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

                if !todayRecords.isEmpty {
                    Section("今日の記録") {
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
                    }
                }
            }
            .navigationTitle("わんちゃん管理")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                DogProfileFormView()
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

    @State private var showingRecordForm = false
    @State private var showingScheduleForm = false
    @State private var editingSchedule: MealSchedule? = nil
    @State private var deletingSchedule: MealSchedule? = nil
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
                            Button {
                                let copy = MealSchedule(name: meal.name + "のコピー", content: meal.content, time: meal.time, amount: meal.amount, sortOrder: schedules.count)
                                context.insert(copy)
                                editingSchedule = copy
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            Button {
                                editingSchedule = meal
                            } label: {
                                Image(systemName: "pencil").foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            Button {
                                deletingSchedule = meal
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    Button {
                        showingScheduleForm = true
                    } label: {
                        Label("予定を追加", systemImage: "plus.circle")
                    }
                } header: {
                    Text("ごはんスケジュール")
                }

                Section("記録一覧") {
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
            .confirmationDialog(
                "この予定を削除しますか？",
                isPresented: Binding(
                    get: { deletingSchedule != nil },
                    set: { if !$0 { deletingSchedule = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let schedule = deletingSchedule {
                        context.delete(schedule)
                    }
                    deletingSchedule = nil
                }
                Button("キャンセル", role: .cancel) {
                    deletingSchedule = nil
                }
            } message: {
                Text("\(deletingSchedule?.name ?? "この予定")を削除します。")
            }
        }
        .onAppear { insertDefaultMealSchedulesIfNeeded(context: context, schedules: schedules) }
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

    @State private var showingRecordForm = false
    @State private var showingScheduleForm = false
    @State private var editingSchedule: MedicationSchedule? = nil
    @State private var deletingSchedule: MedicationSchedule? = nil
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
                            Button {
                                let copy = MedicationSchedule(name: medication.name + "のコピー", content: medication.content, time: medication.time, dose: medication.dose, sortOrder: schedules.count)
                                context.insert(copy)
                                editingSchedule = copy
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            Button {
                                editingSchedule = medication
                            } label: {
                                Image(systemName: "pencil").foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            Button {
                                deletingSchedule = medication
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    Button {
                        showingScheduleForm = true
                    } label: {
                        Label("予定を追加", systemImage: "plus.circle")
                    }
                } header: {
                    Text("お薬スケジュール")
                }

                Section("記録一覧") {
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
            .confirmationDialog(
                "この予定を削除しますか？",
                isPresented: Binding(
                    get: { deletingSchedule != nil },
                    set: { if !$0 { deletingSchedule = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let schedule = deletingSchedule {
                        context.delete(schedule)
                    }
                    deletingSchedule = nil
                }
                Button("キャンセル", role: .cancel) {
                    deletingSchedule = nil
                }
            } message: {
                Text("\(deletingSchedule?.name ?? "この予定")を削除します。")
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
    @Query(sort: \MealSchedule.sortOrder) private var all: [MealSchedule]

    @State private var name = ""
    @State private var content = ""
    @State private var selectedTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var amount = ""

    private var isValid: Bool { !name.isEmpty && !amount.isEmpty }

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
                Section("量") {
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
                            s.name = name; s.content = content; s.time = timeStr; s.amount = amount
                        } else {
                            let s = MealSchedule(name: name, content: content, time: timeStr, amount: amount, sortOrder: all.count)
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
    @Query(sort: \MedicationSchedule.sortOrder) private var all: [MedicationSchedule]

    @State private var name = ""
    @State private var content = ""
    @State private var selectedTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var dose = ""

    private var isValid: Bool { !name.isEmpty && !dose.isEmpty }

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
                Section("用量") {
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
                            s.name = name; s.content = content; s.time = timeStr; s.dose = dose
                        } else {
                            let s = MedicationSchedule(name: name, content: content, time: timeStr, dose: dose, sortOrder: all.count)
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
        return !title.isEmpty && !amount.isEmpty
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

                Section("与えた量") {
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

// MARK: - Static models (legacy – kept only for RecordFormView fallback)

struct MealPlan: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let amount: String

    static let samples: [MealPlan] = [
        MealPlan(name: "朝ごはん", time: "08:00", amount: "80g"),
        MealPlan(name: "夜ごはん", time: "18:30", amount: "90g")
    ]
}

struct MedicationPlan: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let dose: String

    static let samples: [MedicationPlan] = [
        MedicationPlan(name: "フィラリア予防薬", time: "09:00", dose: "1錠"),
        MedicationPlan(name: "皮膚ケアサプリ", time: "20:00", dose: "5mL")
    ]
}

#Preview {
    ContentView()
        .modelContainer(for: [CareRecord.self, MealSchedule.self, MedicationSchedule.self, SpecialEvent.self, DogProfile.self], inMemory: true)
}
