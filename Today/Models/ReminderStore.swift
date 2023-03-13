//
//  ReminderStore.swift
//  Today
//
//  Created by user on 16.02.2023.
//

import EventKit
import Foundation

final class ReminderStore {
    static let shared = ReminderStore()
    
    private let ekStore = EKEventStore()
    
    var isAvailable: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .authorized
    }
    
    func requestAccess() async throws {
        //let status = EKEventStore.authorizationStatus(for: .reminder)
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized:
            return
        case .restricted:
            throw TodayError.accessRestricted
        case .notDetermined:
            let accessGranted = try await ekStore.requestAccess(to: .reminder)
            guard accessGranted else {
                throw TodayError.accessDenied
            }
        case .denied:
            throw TodayError.accessDenied
        @unknown default:
            throw TodayError.unknown
        }
    }
    
    func readAll() async throws -> [Reminder] {
        guard isAvailable else {
            throw TodayError.accessDenied
        }
        
        let predicate = ekStore.predicateForReminders(in: nil)
        let ekReminders = try await ekStore.reminders(matching: predicate)
        let reminders: [Reminder] = ekReminders.compactMap { ekReminder in
            try? Reminder(with: ekReminder)
        }
        
//        let reminders: [Reminder] = try ekReminders.compactMap { ekReminder in
//            do {
//                return try Reminder(with: ekReminder)
//            } catch TodayError.reminderHasNoDueDate {
//                return nil
//            }
//        }
//     return reminders
       return reminders
    }
    
    @discardableResult
    func save(_ reminder: Reminder) throws -> Reminder.ID {
        guard isAvailable else {
            throw TodayError.accessDenied
        }
        let ekReminder: EKReminder
        if let reminder = try? read(with: reminder.id) {
            ekReminder = reminder
        } else {
            ekReminder = EKReminder(eventStore: ekStore)
        }
//        do {
//            ekReminder = try read(with: reminder.id)
//        } catch {
//            ekReminder = EKReminder(eventStore: ekStore)
//        }
        ekReminder.update(using: reminder, in: ekStore)
        try ekStore.save(ekReminder, commit: true)
        return ekReminder.calendarItemIdentifier
    }
    
    func remove(with id: Reminder.ID) throws {
        guard isAvailable else {
            throw TodayError.accessDenied
            }
            let ekReminder = try read(with: id)
            try ekStore.remove(ekReminder, commit: true)
        }
    
    private func read(with id: Reminder.ID) throws -> EKReminder {
        guard let ekReminder = ekStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw TodayError.failedReadingCalendarItem
        }
        return ekReminder
    }
}
