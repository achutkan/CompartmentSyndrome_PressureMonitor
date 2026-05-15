//
//  compartmentSyndromeApp.swift
//  compartmentSyndrome
//
//  Created by Sophia Torrellas on 5/2/26.
//

import SwiftUI
import UserNotifications

@main
struct compartmentSyndromeApp: App
{
    init()
    {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate
{
    static let shared = NotificationDelegate()
    
    // This makes notifications show as banners even when app is foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .sound])
    }
}
