//
//  ContentView.swift
//  Road Noise
//
//  Created by Sam Warnick on 9/11/21.
//

import SwiftUI

enum NoiseLevel: Int, CaseIterable, Identifiable, Codable {
    case zero = 0, one, two, three
    
    var id: Int {
        self.rawValue
    }
    var label: String {
        switch self {
            case .zero:
                return "What noise?"
            case .one:
                return "It's fine"
            case .two:
                return "Need headphones"
            case .three:
                return "Just awful"
        }
    }
    var color: Color {
        switch self {
            case .zero:
                return .green
            case .one:
                return .blue
            case .two:
                return .orange
            case .three:
                return .red
        }
    }
}

struct Weather: Codable {
    var temp: Double
    var feelsLike: Double
    var tempMin: Double
    var tempMax: Double
    var pressure: Double
    var humidity: Double
    var clouds: Double
    var wind: Wind
    var rain: Rain?
    var condition: Condition
}

struct Wind: Codable {
    var speed: Double
    var deg: Double
}

struct Rain: Codable {
    var lastHour: Double
    var last3Hours: Double?
}

struct Condition: Codable {
    var category: String
    var description: String
}

struct NoiseEntry: Identifiable, Codable {
    var id: String
    var date: Date
    var noiseLevel: NoiseLevel
    var weather: Weather
}

struct ContentView: View {
    @EnvironmentObject() var manager: NoiseEntryManager
    @EnvironmentObject() var viewState: ViewState
    
    @State private var keyIsPresented = false
    @State private var presentNoiseLevel = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.groupedNoiseEntries.sorted(by: \.key), id: \.key) { date, noiseEntries in
                    Section(date.formatted(date: .long, time: .omitted)) {
                        ForEach(noiseEntries) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    ZStack(alignment: .leading) {
                                        Text("00:00 PM")
                                            .opacity(0)
                                            .accessibility(hidden: true)
                                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    }
                                    Image(systemName: getWeatherSystemName(category: entry.weather.condition.category, clouds: entry.weather.clouds))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(entry.noiseLevel.rawValue.formatted())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(entry.noiseLevel.color))
                                }
                                .font(.system(.title2, design: .rounded).monospacedDigit())
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.red)
                                    Text("\(entry.weather.temp.formatted(.number.rounded(rule: .toNearestOrEven, increment: 1)))°F")
                                    Image(systemName: "wind")
                                        .foregroundColor(.green)
                                    Text("\(entry.weather.wind.speed.formatted(.number.rounded(rule: .toNearestOrEven, increment: 1))) mph")
                                    Image(systemName: "drop.fill")
                                        .foregroundColor(.cyan)
                                    Text(entry.weather.humidity.formatted(.percent.scale(1)))
                                    Image(systemName: "gauge")
                                        .foregroundColor(.purple)
                                    Text("\(entry.weather.pressure.formatted()) mbar")
                                }
                                .padding(.bottom, 4)
                                .foregroundStyle(.secondary)
                                .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        viewState.presentSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        viewState.presentNoiseLevel = true
                    } label: {
                        Label("Add New", systemImage: "speaker.wave.2.fill")
                            .font(.body.bold())
                            .labelStyle(.titleAndIcon)
                    }
                    .confirmationDialog("How is the road noise?", isPresented: $viewState.presentNoiseLevel, titleVisibility: .visible) {
                        ForEach(NoiseLevel.allCases) { level in
                            Button(level.label) {
                                Task {
                                    await manager.postNewNoiseEntry(level: level.rawValue)
                                }
                            }
                        }
                    }
                    .onLongPressGesture {
                        withAnimation {
                            keyIsPresented = true
                        }
                    }
                }
            }
            .navigationTitle("Road Noise")
            .sheet(isPresented: $viewState.presentSettings) {
                Settings()
            }
        }
        .task {
            await manager.loadNoiseEntries()
        }
        .refreshable {
            await manager.loadNoiseEntries()
        }
    }
    
    private func getWeatherSystemName(category: String, clouds: Double) -> String {
        switch category {
            case "Thunderstorm":
                return "cloud.bolt.rain"
            case "Drizzle":
                return "cloud.drizzle"
            case "Rain":
                if clouds < 50.0 {
                    return "cloud.sun.rain"
                } else {
                    return "cloud.rain"
                }
            case "Snow":
                return "cloud.snow"
            case "Clouds":
                if clouds < 50.0 {
                    return "cloud.sun"
                } else {
                    return "cloud"
                }
            case "Mist", "Fog":
                return "cloud.fog"
            case "Haze":
                return "sun.haze"
            default:
                return "sun.max"
        }
    }
}

struct Settings: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("key") var key: String = ""
    
    @State private var notifications: [UNNotificationRequest] = []
    @State private var newNotificationTime = Date()
    
    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Label("Notifications", systemImage: "app.badge")) {
                    ForEach(notifications, id: \.identifier) { notification in
                        Text(format((notification.trigger as! UNCalendarNotificationTrigger).dateComponents))
                            .padding(.leading)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            let notification = notifications[index]
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.identifier])
                            notifications.remove(at: index)
                        }
                    }
                    HStack {
                        DatePicker("Notification time", selection: $newNotificationTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                        Button {
                            let center = UNUserNotificationCenter.current()
                            let actions = NoiseLevel.allCases.map {
                                UNNotificationAction(identifier: $0.rawValue.formatted(), title: $0.label, options: [])
                            }
                            let category = UNNotificationCategory(identifier: "REQUEST_NOISE_LEVEL", actions: actions, intentIdentifiers: [], options: [])
                            center.setNotificationCategories([category])
                            let content = UNMutableNotificationContent()
                            content.title = "How's the road noise?"
                            content.sound = UNNotificationSound.default
                            content.categoryIdentifier = "REQUEST_NOISE_LEVEL"
                            
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newNotificationTime)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                            
                            let request = UNNotificationRequest(identifier: "com.samwarnick.Road_Noise.id.\(UUID().uuidString)", content: content, trigger: trigger)
                            center.add(request)
                        } label: {
                            Text("Add")
                        }
                    }
                }
                Section(header: Label("API Key", systemImage: "key")) {
                    SecureField("Key", text: $key, prompt: Text("Key"))
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            let center = UNUserNotificationCenter.current()
            notifications = await center.pendingNotificationRequests()
        }
    }
    
    private func format(_ dateComponents: DateComponents) -> String {
        let date = Calendar.current.date(from: dateComponents)!
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        sorted { a, b in
            a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }
}
