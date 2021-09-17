//
//  NoiseEntryManager.swift
//  NoiseEntryManager
//
//  Created by Sam Warnick on 9/11/21.
//

import SwiftUI

class NoiseEntryManager: ObservableObject {
    @AppStorage("key") var key: String = ""
    
    private var noiseEntries: [NoiseEntry] = [] {
        didSet {
            let grouped = Dictionary(grouping: noiseEntries) { (noiseEntry) -> Date in
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: noiseEntry.date)
                let date = calendar.date(from: dateComponents)!
                return date
            }
            DispatchQueue.main.async {
                withAnimation {
                    self.groupedNoiseEntries = grouped
                }
            }
        }
    }
    @Published var groupedNoiseEntries: [Date: [NoiseEntry]] = [:]
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }
    
    func loadNoiseEntries() async {
        let url = URL(string: "https://road-noise.samwarnick.com")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            noiseEntries = try decoder.decode([NoiseEntry].self, from: data).sorted(by: \.date)
        } catch {
            print(error)
            noiseEntries = []
        }
    }
    
    func postNewNoiseEntry(level: Int) async {
        let url = URL(string: "https://road-noise.samwarnick.com")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = level.formatted().data(using: .utf8)
        request.httpMethod = "POST"
        
        
        if let (data, _) = try? await URLSession.shared.data(for: request) {
            if let newNoiseEntry = try? decoder.decode(NoiseEntry.self, from: data) {
                noiseEntries.insert(newNoiseEntry, at: 0)
            }
        }
    }
}
