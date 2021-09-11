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
    var last3Hours: Double
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
    @Environment(\.dismiss) var dismiss
    @AppStorage("key") var key: String = ""
    
    @State private var noiseEntries: [NoiseEntry] = []
    private var groupedNoiseEntries: [Date: [NoiseEntry]] {
        let grouped = Dictionary(grouping: noiseEntries) { (noiseEntry) -> Date in
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: noiseEntry.date)
            let date = calendar.date(from: dateComponents)!
            return date
        }
        return grouped
    }
    @State private var keyIsPresented = false
    @State private var presentNoiseLevel = false
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }
    
    var body: some View {
        TabView {
            List {
                if keyIsPresented {
                    HStack {
                        SecureField("Key", text: $key, prompt: Text("Key"))
                        Button("🤫") {
                            withAnimation {
                                keyIsPresented = false
                            }
                        }
                    }
                }
                
                ForEach(groupedNoiseEntries.sorted(by: \.key), id: \.key) { date, noiseEntries in
                    Section(date.formatted(date: .long, time: .omitted)) {
                        ForEach(noiseEntries) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    Image(systemName: getWeatherSystemName(category: entry.weather.condition.category))
                                        .renderingMode(.original)
                                    Spacer()
                                    Text(entry.noiseLevel.rawValue.formatted())
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
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
                                .foregroundStyle(.secondary)
                                .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                HStack {
                    Spacer()
                    Button {
                        presentNoiseLevel = true
                    } label: {
                        Label("Add New", systemImage: "plus.square")
                    }
                    .confirmationDialog("How is the road noise?", isPresented: $presentNoiseLevel, titleVisibility: .visible) {
                        ForEach(NoiseLevel.allCases) { level in
                            Button(level.label) {
                                Task {
                                    await postNewNoiseEntry(level: level.rawValue)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onLongPressGesture {
                    withAnimation {
                        keyIsPresented = true
                    }
                }
            }
        }
        .task {
            noiseEntries = (try? await loadNoiseEntries()) ?? []
        }
        .refreshable {
            noiseEntries = (try? await loadNoiseEntries()) ?? []
        }
    }
    
    private func loadNoiseEntries() async throws -> [NoiseEntry] {
        let url = URL(string: "https://road-noise.samwarnick.com")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([NoiseEntry].self, from: data).sorted(by: \.date)
    }
    
    private func postNewNoiseEntry(level: Int) async {
        let url = URL(string: "https://road-noise.samwarnick.com")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = level.formatted().data(using: .utf8)
        request.httpMethod = "POST"
        
        
        if let (data, _) = try? await URLSession.shared.data(for: request) {
            if let newNoiseEntry = try? decoder.decode(NoiseEntry.self, from: data) {
                withAnimation {
                    noiseEntries.insert(newNoiseEntry, at: 0)
                }
            }
        }
    }
    
    private func getWeatherSystemName(category: String) -> String {
        switch category {
            case "Thunderstorm":
                return "cloud.bolt.rain.fill"
            case "Drizzle":
                return "cloud.drizzle.fill"
            case "Rain":
                return "cloud.rain.fill"
            case "Snow":
                return "cloud.snow.fill"
            case "Clouds":
                return "cloud.fill"
            default:
                return "sun.max.fill"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        sorted { a, b in
            a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }
}
