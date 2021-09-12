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
    @EnvironmentObject() var manager: NoiseEntryManager
    @EnvironmentObject() var viewState: ViewState
    
    @State private var keyIsPresented = false
    @State private var presentNoiseLevel = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if keyIsPresented {
                    HStack {
                        SecureField("Key", text: $key, prompt: Text("Key"))
                        Button("🤫") {
                            withAnimation {
                                keyIsPresented = false
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                ForEach(manager.groupedNoiseEntries.sorted(by: \.key), id: \.key) { date, noiseEntries in
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
            HStack {
                Spacer()
                Button {
                    viewState.presentNoiseLevel = true
                } label: {
                    Label("Add New", systemImage: "speaker.wave.2.fill")
                    .font(.body.bold())
                }
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(radius: 2)
                )
                .buttonStyle(.bordered)
                .confirmationDialog("How is the road noise?", isPresented: $viewState.presentNoiseLevel, titleVisibility: .visible) {
                    ForEach(NoiseLevel.allCases) { level in
                        Button(level.label) {
                            Task {
                                await manager.postNewNoiseEntry(level: level.rawValue)
                            }
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.bottom)
            .onLongPressGesture {
                withAnimation {
                    keyIsPresented = true
                }
            }
        }
        .task {
            await manager.loadNoiseEntries()
        }
        .refreshable {
            await manager.loadNoiseEntries()
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
