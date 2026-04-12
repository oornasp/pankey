// main.swift — Manual NSApplication entry point for Pankey
// Must NOT use @main — manual bootstrap required to set delegate before run()
import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
