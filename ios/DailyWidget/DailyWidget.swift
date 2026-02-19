//
//  DailyWidget.swift
//  DailyWidget
//
//  iOS WidgetKit widget for displaying daily content
//

import WidgetKit
import SwiftUI

struct DailyWidget: Widget {
    let kind: String = "DailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
            DailyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Günlük İçerik")
        .description("Günlük içerikleri ana ekranda görüntüleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let body: String
    let updatedAt: String?
}

struct DailyWidgetProvider: TimelineProvider {
    typealias Entry = DailyWidgetEntry
    
    func placeholder(in context: Context) -> DailyWidgetEntry {
        DailyWidgetEntry(
            date: Date(),
            title: "Günün İçeriği",
            body: "Örnek içerik metni burada görünecek...",
            updatedAt: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyWidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadWidgetData()
        
        // Refresh every hour (best-effort)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWidgetData() -> DailyWidgetEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.siyazilim.periodicallynotification")
        
        let title = userDefaults?.string(forKey: "widget_title") ?? "Günün İçeriği"
        let body = userDefaults?.string(forKey: "widget_body") ?? "İçerik yükleniyor..."
        let updatedAt = userDefaults?.string(forKey: "widget_updatedAt")
        
        return DailyWidgetEntry(
            date: Date(),
            title: title,
            body: body,
            updatedAt: updatedAt
        )
    }
}

struct DailyWidgetEntryView: View {
    var entry: DailyWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0)) // #FFFFFF white
                .lineLimit(2)
            
            Text(entry.body)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.878, green: 0.878, blue: 0.878)) // #E0E0E0
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            
            Spacer(minLength: 0)
            
            if let updatedAt = entry.updatedAt {
                HStack {
                    Spacer()
                    Text(formatDate(updatedAt))
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.69, green: 0.69, blue: 0.69)) // #B0B0B0
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(red: 0.38, green: 0.0, blue: 0.93) // #6200EE
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd/MM/yyyy HH:mm"
            return "Son güncelleme: \(displayFormatter.string(from: date))"
        }
        
        return ""
    }
}

struct DailyWidget_Previews: PreviewProvider {
    static var previews: some View {
        DailyWidgetEntryView(
            entry: DailyWidgetEntry(
                date: Date(),
                title: "Günün İçeriği",
                body: "Bu bir örnek içerik metnidir. Widget'ta görüntülenecek içerik burada yer alacak.",
                updatedAt: "2024-01-15T09:00:00.000Z"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
