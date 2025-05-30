//
//  chimetimeApp.swift
//  chimetime
//
//  Created by Liam McShane on 30/5/2025.
//

import SwiftUI
import AppKit
import AVFoundation

@main
struct BeepyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var timer: Timer?
    var audioPlayer: AVAudioPlayer?
    
    // Settings with @Published for SwiftUI compatibility
    @Published var startHour: Int = 9 {
        didSet { saveSettings(); scheduleNextChime() }
    }
    @Published var endHour: Int = 17 {
        didSet { saveSettings(); scheduleNextChime() }
    }
    @Published var chimeMode: ChimeMode = .hourly {
        didSet { saveSettings(); scheduleNextChime() }
    }
    @Published var selectedSound: ChimeSound = .frog {
        didSet { saveSettings() }
    }
    @Published var customSounds: [String] = [] {
        didSet { saveSettings() }
    }
    @Published var selectedCustomSoundPath: String? = nil {
        didSet { saveSettings() }
    }
    @Published var isEnabled: Bool = true {
        didSet {
            saveSettings()
            if isEnabled {
                scheduleNextChime()
            } else {
                timer?.invalidate()
                timer = nil
            }
            updateMenuBarIcon()
        }
    }
    
    enum ChimeMode: String, CaseIterable {
        case hourly = "Hourly"
        case halfHourly = "Half-Hourly"
        
        var displayName: String { rawValue }
    }
    
    enum ChimeSound: String, CaseIterable {
        case basso = "Basso"
        case blow = "Blow"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case glass = "Glass"
        case hero = "Hero"
        case morse = "Morse"
        case ping = "Ping"
        case pop = "Pop"
        case purr = "Purr"
        case sosumi = "Sosumi"
        case submarine = "Submarine"
        case tink = "Tink"
        case beep = "System Beep"
        case custom = "Custom Sound"
        
        var displayName: String { rawValue }
        
        var systemSoundName: String? {
            switch self {
            case .basso: return "Basso"
            case .blow: return "Blow"
            case .bottle: return "Bottle"
            case .frog: return "Frog"
            case .funk: return "Funk"
            case .glass: return "Glass"
            case .hero: return "Hero"
            case .morse: return "Morse"
            case .ping: return "Ping"
            case .pop: return "Pop"
            case .purr: return "Purr"
            case .sosumi: return "Sosumi"
            case .submarine: return "Submarine"
            case .tink: return "Tink"
            case .beep: return nil // Use NSSound.beep() for system beep
            case .custom: return nil // Custom sounds handled separately
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide main window and dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        loadSettings()
        scheduleNextChime()
        setupLoginItem()
    }
    
    func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // App title
        let titleItem = NSMenuItem(title: "BeepyApp", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Enable/Disable toggle
        let enableItem = NSMenuItem(
            title: isEnabled ? "Disable Chimes" : "Enable Chimes",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        menu.addItem(enableItem)
        menu.addItem(NSMenuItem.separator())
        
        // Current status
        let statusText = isEnabled ? "Status: Active (\(startHour):00 - \(endHour):00)" : "Status: Disabled"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        
        // Active Hours submenu
        let hoursMenu = NSMenu()
        
        // Start hour submenu
        let startHourMenu = NSMenu()
        for hour in 0...23 {
            let item = NSMenuItem(
                title: String(format: "%02d:00", hour),
                action: #selector(setStartHour(_:)),
                keyEquivalent: ""
            )
            item.tag = hour
            item.state = (hour == startHour) ? .on : .off
            startHourMenu.addItem(item)
        }
        let startHourItem = NSMenuItem(title: "Start Hour", action: nil, keyEquivalent: "")
        startHourItem.submenu = startHourMenu
        hoursMenu.addItem(startHourItem)
        
        // End hour submenu
        let endHourMenu = NSMenu()
        for hour in 0...23 {
            let item = NSMenuItem(
                title: String(format: "%02d:00", hour),
                action: #selector(setEndHour(_:)),
                keyEquivalent: ""
            )
            item.tag = hour
            item.state = (hour == endHour) ? .on : .off
            endHourMenu.addItem(item)
        }
        let endHourItem = NSMenuItem(title: "End Hour", action: nil, keyEquivalent: "")
        endHourItem.submenu = endHourMenu
        hoursMenu.addItem(endHourItem)
        
        let activeHoursItem = NSMenuItem(title: "Active Hours", action: nil, keyEquivalent: "")
        activeHoursItem.submenu = hoursMenu
        menu.addItem(activeHoursItem)
        
        // Chime Mode submenu
        let chimeModeMenu = NSMenu()
        for mode in ChimeMode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(setChimeMode(_:)),
                keyEquivalent: ""
            )
            item.representedObject = mode
            item.state = (mode == chimeMode) ? .on : .off
            chimeModeMenu.addItem(item)
        }
        let chimeModeItem = NSMenuItem(title: "Chime Frequency", action: nil, keyEquivalent: "")
        chimeModeItem.submenu = chimeModeMenu
        menu.addItem(chimeModeItem)
        
        // Sound submenu
        let soundMenu = NSMenu()
        
        // System sounds
        for sound in ChimeSound.allCases {
            if sound != .custom {
                let item = NSMenuItem(
                    title: sound.displayName,
                    action: #selector(setChimeSound(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = sound
                item.state = (sound == selectedSound && selectedCustomSoundPath == nil) ? .on : .off
                soundMenu.addItem(item)
            }
        }
        
        // Separator before custom sounds
        if !customSounds.isEmpty {
            soundMenu.addItem(NSMenuItem.separator())
            
            // Custom sounds
            for customSoundPath in customSounds {
                let soundName = URL(fileURLWithPath: customSoundPath).deletingPathExtension().lastPathComponent
                let item = NSMenuItem(
                    title: "🎵 \(soundName)",
                    action: #selector(setCustomChimeSound(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = customSoundPath
                item.state = (selectedCustomSoundPath == customSoundPath) ? .on : .off
                soundMenu.addItem(item)
            }
            
            if !customSounds.isEmpty {
                soundMenu.addItem(NSMenuItem.separator())
            }
        }
        
        // Add custom sound option
        let addCustomItem = NSMenuItem(title: "Add Custom Sound...", action: #selector(addCustomSound), keyEquivalent: "")
        soundMenu.addItem(addCustomItem)
        
        // Remove custom sounds option (if any exist)
        if !customSounds.isEmpty {
            let removeCustomItem = NSMenuItem(title: "Remove Custom Sounds...", action: #selector(removeCustomSounds), keyEquivalent: "")
            soundMenu.addItem(removeCustomItem)
        }
        
        let soundItem = NSMenuItem(title: "Chime Sound", action: nil, keyEquivalent: "")
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Test chime
        let testItem = NSMenuItem(title: "Test Chime", action: #selector(testChime), keyEquivalent: "t")
        menu.addItem(testItem)
        
        // Login item help
        let loginHelpItem = NSMenuItem(title: "Setup Auto-Start...", action: #selector(showLoginItemHelp), keyEquivalent: "")
        menu.addItem(loginHelpItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit BeepyApp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
    }
    
    func updateMenuBarIcon() {
        let icon = isEnabled ? "🔔" : "🔕"
        statusBarItem.button?.title = icon
        statusBarItem.button?.toolTip = isEnabled ? "BeepyApp - Chimes Active" : "BeepyApp - Chimes Disabled"
    }
    
    @objc func toggleEnabled() {
        isEnabled.toggle()
        setupMenuBar() // Refresh menu
    }
    
    @objc func setStartHour(_ sender: NSMenuItem) {
        startHour = sender.tag
        setupMenuBar()
    }
    
    @objc func setEndHour(_ sender: NSMenuItem) {
        endHour = sender.tag
        setupMenuBar()
    }
    
    @objc func setChimeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? ChimeMode {
            chimeMode = mode
            setupMenuBar()
        }
    }
    
    @objc func setChimeSound(_ sender: NSMenuItem) {
        if let sound = sender.representedObject as? ChimeSound {
            selectedSound = sound
            selectedCustomSoundPath = nil // Clear custom sound selection
            setupMenuBar()
            
            // Play the selected sound immediately as preview
            playSelectedSound(sound)
        }
    }
    
    @objc func setCustomChimeSound(_ sender: NSMenuItem) {
        if let soundPath = sender.representedObject as? String {
            selectedCustomSoundPath = soundPath
            setupMenuBar()
            
            // Play the custom sound immediately as preview
            playCustomSound(at: soundPath)
        }
    }
    
    @objc func addCustomSound() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Custom Chime Sound"
        openPanel.allowedContentTypes = [.audio]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                let soundPath = url.path
                if !customSounds.contains(soundPath) {
                    customSounds.append(soundPath)
                    selectedCustomSoundPath = soundPath
                    setupMenuBar()
                    
                    // Play the newly added sound as preview
                    playCustomSound(at: soundPath)
                }
            }
        }
    }
    
    @objc func removeCustomSounds() {
        let alert = NSAlert()
        alert.messageText = "Remove Custom Sounds"
        alert.informativeText = "Which custom sounds would you like to remove?"
        alert.alertStyle = .informational
        
        // Create a view with checkboxes for each custom sound
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: min(customSounds.count * 25 + 40, 200)))
        var checkboxes: [NSButton] = []
        
        for (index, soundPath) in customSounds.enumerated() {
            let soundName = URL(fileURLWithPath: soundPath).deletingPathExtension().lastPathComponent
            let checkbox = NSButton(checkboxWithTitle: soundName, target: nil, action: nil)
            checkbox.frame = NSRect(x: 10, y: containerView.frame.height - CGFloat((index + 1) * 25), width: 280, height: 20)
            containerView.addSubview(checkbox)
            checkboxes.append(checkbox)
        }
        
        alert.accessoryView = containerView
        alert.addButton(withTitle: "Remove Selected")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Remove selected sounds (in reverse order to maintain indices)
            for (index, checkbox) in checkboxes.enumerated().reversed() {
                if checkbox.state == .on {
                    let removedPath = customSounds[index]
                    customSounds.remove(at: index)
                    
                    // If the removed sound was selected, clear the selection
                    if selectedCustomSoundPath == removedPath {
                        selectedCustomSoundPath = nil
                    }
                }
            }
            setupMenuBar()
        }
    }
    
    @objc func testChime() {
        playChime()
        print("Test chime played")
    }
    
    @objc func showLoginItemHelp() {
        let alert = NSAlert()
        alert.messageText = "Setup Auto-Start"
        alert.informativeText = """
        To make BeepyApp start automatically when you log in:
        
        1. Open System Preferences
        2. Go to Users & Groups
        3. Click on your user account
        4. Click the "Login Items" tab
        5. Click the "+" button
        6. Find and select BeepyApp
        7. Click "Add"
        
        BeepyApp will then start automatically each time you log in.
        """
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Users & Groups
            if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.users") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func scheduleNextChime() {
        timer?.invalidate()
        timer = nil
        
        guard isEnabled else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        let nextChimeDate = calculateNextChimeDate(from: now, calendar: calendar)
        
        guard let chimeDate = nextChimeDate else { return }
        
        let timeInterval = chimeDate.timeIntervalSinceNow
        if timeInterval > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.handleChime()
            }
            
            // Debug: Print next chime time
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            print("Next chime scheduled for: \(formatter.string(from: chimeDate))")
        }
    }
    
    func calculateNextChimeDate(from date: Date, calendar: Calendar) -> Date? {
        if chimeMode == .hourly {
            // Next hour on the hour (XX:00)
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            guard let baseDate = calendar.date(from: components) else { return nil }
            return calendar.date(byAdding: .hour, value: 1, to: baseDate)
        } else {
            // Half-hourly chimes (XX:00 and XX:30)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            guard let currentMinute = components.minute,
                  let currentHour = components.hour else { return nil }
            
            var nextMinute: Int
            var nextHour = currentHour
            
            if currentMinute < 30 {
                nextMinute = 30
            } else {
                nextMinute = 0
                nextHour += 1
            }
            
            var nextComponents = components
            nextComponents.hour = nextHour
            nextComponents.minute = nextMinute
            nextComponents.second = 0
            nextComponents.nanosecond = 0
            
            return calendar.date(from: nextComponents)
        }
    }
    
    func handleChime() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Check if we're within active hours
        let withinActiveHours: Bool
        if startHour <= endHour {
            // Normal range (e.g., 9 to 17)
            withinActiveHours = hour >= startHour && hour < endHour
        } else {
            // Overnight range (e.g., 22 to 6)
            withinActiveHours = hour >= startHour || hour < endHour
        }
        
        if withinActiveHours {
            playChime()
        }
        
        // Schedule the next chime
        scheduleNextChime()
    }
    
    func playChime() {
        if let customPath = selectedCustomSoundPath {
            playCustomSound(at: customPath)
        } else {
            playSelectedSound(selectedSound)
        }
        print("Chime played at \(Date())")
    }
    
    func playSelectedSound(_ sound: ChimeSound) {
        if let soundName = sound.systemSoundName {
            if let nsSound = NSSound(named: soundName) {
                nsSound.play()
            } else {
                // Fallback to system beep if sound not found
                NSSound.beep()
                print("Warning: Sound '\(soundName)' not found, using system beep")
            }
        } else {
            // For system beep case
            NSSound.beep()
        }
    }
    
    func playCustomSound(at path: String) {
        let url = URL(fileURLWithPath: path)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing custom sound: \(error.localizedDescription)")
            // Fallback to system beep
            NSSound.beep()
        }
    }
    
    func setupLoginItem() {
        // For modern macOS, we'll skip automatic login item setup
        // Users can manually add the app to Login Items in System Preferences > Users & Groups > Login Items
        // Or we could implement ServiceManagement framework for macOS 13+
        print("Note: To run BeepyApp at login, add it manually in System Preferences > Users & Groups > Login Items")
    }
    
    // MARK: - Settings Persistence
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(startHour, forKey: "BeepyApp_startHour")
        defaults.set(endHour, forKey: "BeepyApp_endHour")
        defaults.set(chimeMode.rawValue, forKey: "BeepyApp_chimeMode")
        defaults.set(selectedSound.rawValue, forKey: "BeepyApp_selectedSound")
        defaults.set(customSounds, forKey: "BeepyApp_customSounds")
        defaults.set(selectedCustomSoundPath, forKey: "BeepyApp_selectedCustomSoundPath")
        defaults.set(isEnabled, forKey: "BeepyApp_isEnabled")
        defaults.synchronize()
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        startHour = defaults.object(forKey: "BeepyApp_startHour") as? Int ?? 9
        endHour = defaults.object(forKey: "BeepyApp_endHour") as? Int ?? 17
        isEnabled = defaults.object(forKey: "BeepyApp_isEnabled") as? Bool ?? true
        customSounds = defaults.stringArray(forKey: "BeepyApp_customSounds") ?? []
        selectedCustomSoundPath = defaults.string(forKey: "BeepyApp_selectedCustomSoundPath")
        
        if let chimeModeString = defaults.string(forKey: "BeepyApp_chimeMode"),
           let mode = ChimeMode(rawValue: chimeModeString) {
            chimeMode = mode
        }
        
        if let soundString = defaults.string(forKey: "BeepyApp_selectedSound"),
           let sound = ChimeSound(rawValue: soundString) {
            selectedSound = sound
        }
        
        updateMenuBarIcon()
    }
}

