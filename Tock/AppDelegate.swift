import AppKit
import SwiftUI
import Combine
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let popover = NSPopover()
  private let model = TockModel()
  private var cancellables = Set<AnyCancellable>()
  private var hotKeyRef: EventHotKeyRef?
  private var trashHotKeyRef: EventHotKeyRef?
  private var hotKeyHandlerRef: EventHandlerRef?
  private let hotKeyId: UInt32 = 1
  private let trashHotKeyId: UInt32 = 2
  private var contextMenu: NSMenu?
  private var stopwatchItem: NSMenuItem?
  private var pauseItem: NSMenuItem?
  private var clearItem: NSMenuItem?
  private var eventMonitor: Any?
  private var keyMonitor: Any?


  private static let statusBarImage: NSImage = {
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)?
      .withSymbolConfiguration(config) ?? NSImage()
    image.isTemplate = true
    image.size = NSSize(width: 18, height: 18)
    return image
  }()

  private static let popoverWillShowNotification = Notification.Name("TockPopoverWillShow")

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    #if DEBUG
    terminateOtherInstances()
    #endif
    configurePopover()
    configureStatusItem()
    bindModel()
    updateStatusItem()
    registerHotKey()
  }

  private func terminateOtherInstances() {
    guard let bundleId = Bundle.main.bundleIdentifier else { return }
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    let current = NSRunningApplication.current
    for app in runningApps where app.processIdentifier != current.processIdentifier {
      app.terminate()
    }
  }

  private func configurePopover() {
    let view = TockMenuView()
      .environmentObject(model)
      .environment(\.menuDismiss, MenuDismissAction { [weak self] in
        self?.popover.performClose(nil)
      })
    popover.contentViewController = NSHostingController(rootView: view)
    popover.behavior = .applicationDefined
    popover.animates = false
    popover.delegate = self
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(statusItemClicked(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  private func bindModel() {
    Publishers.Merge3(
      model.$remaining.map { _ in () },
      model.$elapsed.map { _ in () },
      model.$isRunning.map { _ in () }
    )
      .sink { [weak self] _ in
        DispatchQueue.main.async {
          self?.updateStatusItem()
        }
      }
      .store(in: &cancellables)
  }

  private func updateStatusItem() {
    guard let button = statusItem.button else { return }
    if model.isRunning {
      let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
      let attributes: [NSAttributedString.Key: Any] = [.font: font]
      button.attributedTitle = NSAttributedString(string: model.formattedRemaining, attributes: attributes)
      button.image = nil
    } else {
      button.title = ""
      button.attributedTitle = NSAttributedString(string: "")
      button.image = Self.statusBarImage
    }
    updateContextMenuItems()
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      NSApp.activate(ignoringOtherApps: true)
      togglePopover(sender)
      return
    }
    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      NSApp.activate(ignoringOtherApps: true)
      togglePopover(sender)
    }
  }

  private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
    } else {
      NotificationCenter.default.post(name: Self.popoverWillShowNotification, object: nil)
      popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
      startEventMonitors()
    }
  }

  private func togglePopoverFromHotKey() {
    guard let button = statusItem.button else { return }
    togglePopover(button)
  }

  private func trashFromHotKey() {
    model.stop()
    popover.performClose(nil)
  }

  private func showContextMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    let openItem = NSMenuItem(title: "Open", action: #selector(openTimerFromMenu), keyEquivalent: "t")
    openItem.keyEquivalentModifierMask = [.control, .option, .command]
    openItem.target = self
    menu.addItem(openItem)

    let startStopwatchItem = NSMenuItem(title: "Stopwatch", action: #selector(startStopwatchFromMenu), keyEquivalent: "")
    startStopwatchItem.target = self
    menu.addItem(startStopwatchItem)
    stopwatchItem = startStopwatchItem

    let newPauseItem = NSMenuItem(title: "Pause", action: #selector(pauseTimerFromMenu), keyEquivalent: "")
    newPauseItem.target = self
    menu.addItem(newPauseItem)
    pauseItem = newPauseItem

    let stopItem = NSMenuItem(title: "Clear", action: #selector(stopTimerFromMenu), keyEquivalent: "x")
    stopItem.keyEquivalentModifierMask = [.control, .option, .command]
    stopItem.target = self
    menu.addItem(stopItem)
    clearItem = stopItem

    menu.addItem(.separator())

    let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
    settingsItem.keyEquivalentModifierMask = [.command]
    settingsItem.target = self
    menu.addItem(settingsItem)

    let quitItem = NSMenuItem(title: "Quit Tock", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    contextMenu = menu
    updateContextMenuItems()
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  private func updateContextMenuItems() {
    guard contextMenu != nil else { return }
    stopwatchItem?.isEnabled = !model.isRunning || model.isCountdownFinished
    pauseItem?.isEnabled = model.isRunning && !model.isCountdownFinished
    clearItem?.isEnabled = model.isRunning

    if model.isPaused {
      pauseItem?.title = "Restart"
      pauseItem?.action = #selector(restartTimerFromMenu)
    } else {
      pauseItem?.title = "Pause"
      pauseItem?.action = #selector(pauseTimerFromMenu)
    }
  }

  func menuDidClose(_ menu: NSMenu) {
    if menu == contextMenu {
      contextMenu = nil
      stopwatchItem = nil
      pauseItem = nil
      clearItem = nil
    }
  }

  func popoverDidClose(_ notification: Notification) {
    stopEventMonitors()
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  @objc private func openTimerFromMenu() {
    togglePopoverFromHotKey()
  }

  @objc private func startStopwatchFromMenu() {
    model.startStopwatch()
  }

  @objc private func pauseTimerFromMenu() {
    model.pause()
  }

  @objc private func restartTimerFromMenu() {
    model.resume()
  }

  @objc private func stopTimerFromMenu() {
    model.stop()
    popover.performClose(nil)
  }

  @objc private func openSettingsFromMenu() {
    popover.performClose(nil)
    SettingsWindowController.shared.show()
  }

  private func registerHotKey() {
    let modifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)
    let signature = OSType(bitPattern: 0x544F434B)
    let hotKeyID = EventHotKeyID(signature: signature, id: hotKeyId)
    RegisterEventHotKey(UInt32(kVK_ANSI_T), modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    let trashHotKeyID = EventHotKeyID(signature: signature, id: trashHotKeyId)
    RegisterEventHotKey(UInt32(kVK_ANSI_X), modifiers, trashHotKeyID, GetEventDispatcherTarget(), 0, &trashHotKeyRef)

    if hotKeyHandlerRef == nil {
      var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
        guard let event, let userData else { return noErr }
        var hkID = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
        guard status == noErr else { return status }
        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
          if hkID.id == appDelegate.hotKeyId {
            appDelegate.togglePopoverFromHotKey()
          } else if hkID.id == appDelegate.trashHotKeyId {
            appDelegate.trashFromHotKey()
          }
        }
        return noErr
      }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &hotKeyHandlerRef)
    }
  }

  private func startEventMonitors() {
    stopEventMonitors()
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      self?.handleGlobalMouseDown(event)
    }
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
      guard let self else { return event }
      if self.popover.isShown && event.keyCode == 53 {
        self.popover.performClose(nil)
        return nil
      }
      return event
    }
  }

  private func stopEventMonitors() {
    if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }
  }

  private func handleGlobalMouseDown(_ event: NSEvent) {
    guard popover.isShown else { return }
    let inPopover = isEventInPopover(event)
    let inStatusItem = isEventInStatusItem(event)
    if inPopover || inStatusItem {
      return
    }
    popover.performClose(nil)
  }

  private func isEventInPopover(_ event: NSEvent) -> Bool {
    guard let popoverWindow = popover.contentViewController?.view.window else { return false }
    return popoverWindow.frame.contains(event.locationInWindow)
  }

  private func isEventInStatusItem(_ event: NSEvent) -> Bool {
    guard let button = statusItem.button, let window = button.window else { return false }
    let buttonFrame = window.convertToScreen(button.frame)
    return buttonFrame.contains(event.locationInWindow)
  }
}
