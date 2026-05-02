//
//  CalendarView.swift
//  WanCare
//

import SwiftUI
import SwiftData

// MARK: - CalendarView

struct CalendarView: View {
    @Query(sort: \CareRecord.recordedAt) private var allRecords: [CareRecord]
    @Query(sort: \SpecialEvent.scheduledDate) private var allSpecialMeds: [SpecialEvent]

    @State private var displayMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate: Date? = nil
    @State private var showingDetail = false

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: displayMonth))
        }
        return days
    }

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: displayMonth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Month navigation
                    HStack {
                        Button {
                            displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                        } label: {
                            Image(systemName: "chevron.left").padding(8)
                        }
                        Spacer()
                        Text(monthTitle).font(.headline)
                        Spacer()
                        Button {
                            displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                        } label: {
                            Image(systemName: "chevron.right").padding(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Weekday headers
                    HStack(spacing: 0) {
                        ForEach(weekdaySymbols, id: \.self) { w in
                            Text(w)
                                .font(.caption)
                                .foregroundStyle(w == "日" ? .red : w == "土" ? .blue : .primary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)

                    Divider()

                    // Calendar grid
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                            if let date {
                                DayCell(
                                    date: date,
                                    isToday: calendar.isDateInToday(date),
                                    isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                                    hasMeal: hasMeal(on: date),
                                    hasMedication: hasMedication(on: date),
                                    hasSpecialMed: hasSpecialMed(on: date)
                                )
                                .onTapGesture {
                                    if let sel = selectedDate, calendar.isDate(sel, inSameDayAs: date) {
                                        // 同じ日を再タップ → 選択解除
                                        selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                            } else {
                                Color.clear.frame(height: 56)
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    Divider().padding(.top, 4)

                    // Legend
                    HStack(spacing: 16) {
                        Label("ごはん", systemImage: "circle.fill").foregroundStyle(.orange).font(.caption)
                        Label("お薬", systemImage: "circle.fill").foregroundStyle(.blue).font(.caption)
                        Label("その他イベント", systemImage: "circle.fill").foregroundStyle(.purple).font(.caption)
                    }
                    .padding(.vertical, 10)

                    // Inline day content
                    if let selected = selectedDate {
                        Divider()
                        DayInlineSummaryView(
                            date: selected,
                            records: recordsOn(date: selected),
                            specialMeds: specialMedsOn(date: selected),
                            onTapDetail: { showingDetail = true }
                        )
                    }
                }
            }
            .navigationTitle("カレンダー")
            .sheet(isPresented: $showingDetail) {
                if let date = selectedDate {
                    DayDetailView(initialDate: date)
                }
            }
        }
    }

    private func recordsOn(date: Date) -> [CareRecord] {
        allRecords.filter { calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    private func specialMedsOn(date: Date) -> [SpecialEvent] {
        allSpecialMeds.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    private func hasMeal(on date: Date) -> Bool {
        allRecords.contains { $0.type == "meal" && calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    private func hasMedication(on date: Date) -> Bool {
        allRecords.contains { $0.type == "medication" && calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    private func hasSpecialMed(on date: Date) -> Bool {
        allSpecialMeds.contains { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
    }
}

// MARK: - DayInlineSummaryView

private struct DayInlineSummaryView: View {
    let date: Date
    let records: [CareRecord]
    let specialMeds: [SpecialEvent]
    let onTapDetail: () -> Void

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var mealRecords: [CareRecord] { records.filter { $0.type == "meal" } }
    private var medRecords: [CareRecord] { records.filter { $0.type == "medication" } }
    private var isEmpty: Bool { records.isEmpty && specialMeds.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text(Self.headerFormatter.string(from: date))
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Spacer()
                Button {
                    onTapDetail()
                } label: {
                    HStack(spacing: 2) {
                        Text("詳細・編集")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.trailing, 16)
            }
            .background(Color(.systemGroupedBackground))

            Divider()

            if isEmpty {
                Text("この日の記録・予定はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    if !mealRecords.isEmpty {
                        inlineSectionHeader("ごはんの記録", color: .orange, icon: "fork.knife")
                        ForEach(mealRecords) { record in
                            inlineRow(record: record)
                        }
                    }
                    if !medRecords.isEmpty {
                        inlineSectionHeader("お薬の記録", color: .blue, icon: "pills")
                        ForEach(medRecords) { record in
                            inlineRow(record: record)
                        }
                    }
                    if !specialMeds.isEmpty {
                        inlineSectionHeader("その他イベント", color: .purple, icon: "calendar.badge.plus")
                        ForEach(specialMeds) { event in
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: SpecialEventFormView.icon(for: event.title))
                                        .foregroundStyle(.purple)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title).font(.subheadline)
                                        if !event.note.isEmpty {
                                            Text(event.note).font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture { onTapDetail() }
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func inlineSectionHeader(_ title: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func inlineRow(record: CareRecord) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title).font(.subheadline)
                    HStack(spacing: 8) {
                        Text(Self.timeFormatter.string(from: record.recordedAt))
                        if !record.amount.isEmpty { Text(record.amount) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { onTapDetail() }
            Divider().padding(.leading, 16)
        }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasMeal: Bool
    let hasMedication: Bool
    let hasSpecialMed: Bool

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var weekday: Int {
        calendar.component(.weekday, from: date)
    }

    private var dayColor: Color {
        if isSelected { return .white }
        if weekday == 1 { return .red }
        if weekday == 7 { return .blue }
        return .primary
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(isSelected ? .accentColor : isToday ? Color.accentColor.opacity(0.15) : .clear)
                    .frame(width: 32, height: 32)
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday ? .bold : .regular))
                    .foregroundStyle(dayColor)
            }
            HStack(spacing: 3) {
                Circle().fill(hasMeal ? Color.orange : .clear).frame(width: 5, height: 5)
                Circle().fill(hasMedication ? Color.blue : .clear).frame(width: 5, height: 5)
                Circle().fill(hasSpecialMed ? Color.purple : .clear).frame(width: 5, height: 5)
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DayDetailView

struct DayDetailView: View {
    @State var currentDate: Date

    @Query(sort: \CareRecord.recordedAt) private var allRecords: [CareRecord]
    @Query(sort: \SpecialEvent.scheduledDate) private var allSpecialEvents: [SpecialEvent]
    @Environment(\.modelContext) private var context
    @State private var showingAddSpecialMed = false
    @State private var editingEvent: SpecialEvent? = nil

    init(initialDate: Date) {
        self._currentDate = State(initialValue: initialDate)
    }

    private let calendar = Calendar.current

    private var records: [CareRecord] {
        allRecords.filter { calendar.isDate($0.recordedAt, inSameDayAs: currentDate) }
    }
    private var specialMeds: [SpecialEvent] {
        allSpecialEvents.filter { calendar.isDate($0.scheduledDate, inSameDayAs: currentDate) }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f
    }()

    private var title: String { Self.dateFormatter.string(from: currentDate) }
    private var mealRecords: [CareRecord] { records.filter { $0.type == "meal" } }
    private var medRecords: [CareRecord] { records.filter { $0.type == "medication" } }

    var body: some View {
        NavigationStack {
            List {
                Section("ごはんの記録") {
                    if mealRecords.isEmpty {
                        Text("記録なし").foregroundStyle(.secondary)
                    } else {
                        ForEach(mealRecords) { record in RecordRow(record: record) }
                    }
                }
                Section("お薬の記録") {
                    if medRecords.isEmpty {
                        Text("記録なし").foregroundStyle(.secondary)
                    } else {
                        ForEach(medRecords) { record in RecordRow(record: record) }
                    }
                }
                Section {
                    if specialMeds.isEmpty {
                        Text("予定なし").foregroundStyle(.secondary)
                    } else {
                        ForEach(specialMeds) { event in
                            HStack(spacing: 10) {
                                Image(systemName: SpecialEventFormView.icon(for: event.title))
                                    .foregroundStyle(.purple)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline)
                                    if !event.note.isEmpty {
                                        Text(event.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture { editingEvent = event }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(event)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                                Button { editingEvent = event } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    Button { showingAddSpecialMed = true } label: {
                        Label("この日にイベントを追加", systemImage: "calendar.badge.plus")
                    }
                } header: {
                    Text("その他イベント")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddSpecialMed = true } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("前日")
                            }
                        }
                        Spacer()
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                        } label: {
                            HStack(spacing: 4) {
                                Text("翌日")
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSpecialMed) {
                SpecialEventFormView(initialDate: currentDate)
            }
            .sheet(item: $editingEvent) { event in
                SpecialEventFormView(editing: event)
            }
        }
    }
}

// MARK: - Calendar extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
