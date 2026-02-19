//
//  DailyWidget.swift
//  DailyWidget
//
//  iOS WidgetKit widget for displaying daily content
//

import WidgetKit
import SwiftUI
import UIKit

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
    let imageUrl: String?
    let imagePath: String?  // App Group içindeki yerel dosya yolu (AsyncImage WidgetKit'ta çalışmaz)
    let updatedAt: String?
}

struct DailyWidgetProvider: TimelineProvider {
    typealias Entry = DailyWidgetEntry
    
    func placeholder(in context: Context) -> DailyWidgetEntry {
        DailyWidgetEntry(
            date: Date(),
            title: "Günün İçeriği",
            body: "Örnek içerik metni burada görünecek...",
            imageUrl: nil,
            imagePath: nil,
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
        // 1. Önce App Group'taki JSON dosyasından oku (UserDefaults sync sorunlarını aşar)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.siyazilim.periodicallynotification") {
            let jsonURL = containerURL.appendingPathComponent("widget_cache/widget_data.json")
            if FileManager.default.fileExists(atPath: jsonURL.path),
               let data = try? Data(contentsOf: jsonURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let title = json["title"] as? String ?? "Günün İçeriği"
                let body = json["body"] as? String ?? "İçerik yükleniyor..."
                let imagePath = (json["imagePath"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let imagePathValid = (imagePath?.isEmpty == false) ? imagePath : nil
                let containerImagePath = containerURL.appendingPathComponent("widget_cache/widget_image.jpg").path
                return DailyWidgetEntry(
                    date: Date(),
                    title: title,
                    body: body,
                    imageUrl: nil,
                    imagePath: imagePathValid ?? containerImagePath,
                    updatedAt: json["updatedAt"] as? String
                )
            }
        }
        
        // 2. Fallback: UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.siyazilim.periodicallynotification")
        let title = userDefaults?.string(forKey: "widget_title") ?? "Günün İçeriği"
        let body = userDefaults?.string(forKey: "widget_body") ?? "İçerik yükleniyor..."
        let imageUrl = userDefaults?.string(forKey: "widget_imageUrl")
        let imagePath = userDefaults?.string(forKey: "widget_imagePath")
        let updatedAt = userDefaults?.string(forKey: "widget_updatedAt")
        
        return DailyWidgetEntry(
            date: Date(),
            title: title,
            body: body,
            imageUrl: (imageUrl?.isEmpty == false) ? imageUrl : nil,
            imagePath: (imagePath?.isEmpty == false) ? imagePath : nil,
            updatedAt: updatedAt
        )
    }
}

struct DailyWidgetEntryView: View {
    var entry: DailyWidgetProvider.Entry
    
    private var widgetImage: Image? {
        let fm = FileManager.default
        let pathsToTry: [String] = {
            var list: [String] = []
            if let path = entry.imagePath, !path.isEmpty { list.append(path) }
            if let containerURL = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.siyazilim.periodicallynotification") {
                list.append(containerURL.appendingPathComponent("widget_cache/widget_image.jpg").path)
            }
            return list
        }()
        for path in pathsToTry {
            if fm.fileExists(atPath: path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let img = widgetImage {
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 \(entry.title)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.26, green: 0.65, blue: 0.96))
                    .lineLimit(2)
                
                Text(entry.body)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.9, green: 0.91, blue: 0.92))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
    }
}

/// iOS 17+ containerBackground, iOS 14–16 background
private struct WidgetBackgroundModifier: ViewModifier {
    private let color = Color(red: 0.12, green: 0.12, blue: 0.12)
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) { color }
        } else {
            content
                .background(color)
        }
    }
}

struct DailyWidget_Previews: PreviewProvider {
    static var previews: some View {
        DailyWidgetEntryView(
            entry: DailyWidgetEntry(
                date: Date(),
                title: "Günün İçeriği",
                body: "Karanlık modda bile okunaklı ve şık bir görünüm sunan Material 3 tasarımı ile",
                imageUrl: nil,
                imagePath: nil,
                updatedAt: "2024-01-15T09:00:00.000Z"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
