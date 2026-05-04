//
//  OnboardingView.swift
//  WanCare
//

import SwiftUI

// MARK: - Onboarding Page Model

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

// MARK: - OnboardingView

struct OnboardingView: View {
    let isHelp: Bool
    let onDismiss: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "pawprint.circle.fill",
            iconColor: .brown,
            title: "わんケアへようこそ",
            description: "愛犬のごはん・お薬・体重・イベントをまとめて管理できるアプリです。\n\nまずはプロフィールから愛犬の名前と写真を設定しましょう。"
        ),
        OnboardingPage(
            icon: "sun.max.fill",
            iconColor: .orange,
            title: "今日タブ",
            description: "今日のごはん・お薬・体重・イベントを一覧で確認できます。\n\n・アイコンをタップ → ごはん・お薬を記録済みにする\n・体重欄をタップ → 体重を入力・編集\n・右上のアイコン → プロフィール設定"
        ),
        OnboardingPage(
            icon: "fork.knife",
            iconColor: .orange,
            title: "ごはんタブ",
            description: "ごはんのスケジュールと記録を管理します。\n\n・「予定を追加」→ 給餌スケジュールを登録\n・スケジュールをタップ → 編集\n・左スワイプ → 削除\n・編集モード（左上）でドラッグ並び替え\n・右上「＋」→ 実際の記録を追加"
        ),
        OnboardingPage(
            icon: "pills.fill",
            iconColor: .blue,
            title: "お薬タブ",
            description: "お薬のスケジュールと記録を管理します。\n\n・「予定を追加」→ 投薬スケジュールを登録\n・スケジュールをタップ → 編集\n・左スワイプ → 削除\n・編集モード（左上）でドラッグ並び替え\n・右上「＋」→ 実際の記録を追加"
        ),
        OnboardingPage(
            icon: "scalemass.fill",
            iconColor: .green,
            title: "体重タブ",
            description: "体重の記録とグラフで推移を確認できます。\n\n・右上「＋」→ 体重を記録\n・記録をタップ → 編集\n・左スワイプ → 削除\n・今日タブの体重欄からも記録できます"
        ),
        OnboardingPage(
            icon: "calendar",
            iconColor: .purple,
            title: "カレンダータブ",
            description: "月単位でごはん・お薬・イベントの記録を確認できます。\n\n・日付をタップ → その日の記録を表示\n・「詳細・編集」→ 詳細画面へ\n・左右スワイプ → 月の切り替え\n・詳細画面でイベントの追加・編集もできます"
        ),
    ]

    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 12)

                // Buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            Text("戻る")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("次へ")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button {
                            onDismiss()
                        } label: {
                            Text(isHelp ? "閉じる" : "はじめる")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle(isHelp ? "使い方" : "ようこそ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isHelp {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { onDismiss() }
                    }
                }
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(page.iconColor)
                    .padding(.top, 40)

                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 32)

                Spacer(minLength: 20)
            }
        }
    }
}

#Preview {
    OnboardingView(isHelp: false) {}
}
