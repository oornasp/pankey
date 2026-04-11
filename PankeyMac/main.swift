// main.swift — Manual NSApplication entry point for Pankey IME
// Must NOT use @main — input methods require manual NSApplication setup
import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
