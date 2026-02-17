import SwiftUI
import UserNotifications

enum AppearanceMode: String {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance_mode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("daily_reminder_enabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("daily_reminder_hour") private var dailyReminderHour: Int = 9
    @AppStorage("daily_reminder_minute") private var dailyReminderMinute: Int = 0
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
            }

            Section("Haptics") {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            }

            Section("Daily Reminder") {
                Toggle("Remind me to play", isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        if enabled {
                            scheduleDailyReminder()
                        } else {
                            cancelDailyReminder()
                        }
                    }
                if dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: dailyReminderHour) { _, _ in scheduleDailyReminder() }
                    .onChange(of: dailyReminderMinute) { _, _ in scheduleDailyReminder() }
                }
            }

            Section {
                Button("Reset All Tutorials") {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Tutorials?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "tutorial_seen_diagone")
                UserDefaults.standard.set(false, forKey: "tutorial_seen_rhymeagrams")
                UserDefaults.standard.set(false, forKey: "tutorial_seen_tumblepuns")
            }
        } message: {
            Text("Tutorials will show again the next time you open each game.")
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = dailyReminderHour
                comps.minute = dailyReminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                dailyReminderHour = comps.hour ?? 9
                dailyReminderMinute = comps.minute ?? 0
            }
        )
    }

    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { dailyReminderEnabled = false }
                return
            }
            center.removeAllPendingNotificationRequests()
            let content = UNMutableNotificationContent()
            content.title = "Wuzzler"
            content.body = "Your daily puzzles are ready!"
            content.sound = .default
            var dateComponents = DateComponents()
            dateComponents.hour = dailyReminderHour
            dateComponents.minute = dailyReminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }
}
