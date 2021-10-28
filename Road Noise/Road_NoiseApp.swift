//
//  Road_NoiseApp.swift
//  Road Noise
//
//  Created by Sam Warnick on 9/11/21.
//

import SwiftUI
import UserNotifications
import UIKit

@main
struct Road_NoiseApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @StateObject private var manager = NoiseEntryManager()
    @StateObject private var viewState = ViewState()
    
    init() {
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .environmentObject(viewState)
                .task {
                    appDelegate.manager = manager
                    appDelegate.viewState = viewState
                }
        }
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = appDelegate
        center.getNotificationSettings() { settings in
            if settings.authorizationStatus != .authorized {
                center.requestAuthorization(options: [.alert]) { granted, error in
                    if granted {
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var manager: NoiseEntryManager!
    var viewState: ViewState!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let noiseLevel = Int(response.actionIdentifier) {
            Task {
                await manager.postNewNoiseEntry(level: noiseLevel)
            }
        } else {
            viewState.presentNoiseLevel = true
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        viewState.presentNoiseLevel = true
        return [.banner]
    }
}
