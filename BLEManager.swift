//  BLEManager.swift
//  compartmentSyndrome
//
//  Created by Sophia Torrellas on 5/2/26.
//

import Foundation
import Combine
import CoreBluetooth
import SwiftUI
import AVFoundation
import UserNotifications


struct PressurePoint: Identifiable
{
    let id: Int    // This will be the index (0, 1, 2...)
    let date: Date
    let value: Double
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate
{
    var fileHandle: FileHandle?
    private let fileName = "ICP_Data_Log.csv"
    
    //    let objectWillChange = ObservableObjectPublisher()
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    
    @Published var isConnected = false
    @Published var pressure: Double = 0.0 //rounds pressure value to first decimal point, should be precise enough but can change to second decimal if needed
    @Published var temperature: Double = 0.0 //same rounding as pressure
    @Published var battery: Int = 0
    @Published var pressureHistory: [PressurePoint] = []
    @Published var pressureChangePerHour: Double = 0.0 // The new delta value
    @Published var sessionStartTime = Date() // Track when the app opened
    @Published var alarmThreshold: Double = 30.0  // default 30 mmHg
    @Published var alarmEnabled: Bool = false
    @Published var alarmTriggered: Bool = false
    private var audioPlayer: AVAudioPlayer?
    private var lastNotificationTime: Date = .distantPast
    
    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    let charUUID    = CBUUID(string: "abcd1234-5678-90ab-cdef-123456789abd")
    let cmdUUID     = CBUUID(string: "abcd1234-5678-90ab-cdef-123456789abe")
    private var cmdCharacteristic: CBCharacteristic?
    
    override init()
    {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupCSVFile() // <--- Add this line to create the file on launch
        requestNotificationPermission()  // ← add this line
    }
    
    // MARK: - Bluetooth state
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        print("🔵 BLE State:", central.state.rawValue) // 5 = poweredOn
        if central.state == .poweredOn
        {
            print("🔵 Scanning...")
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    // MARK: - Found device
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
        print("📡 FOUND DEVICE:")
        print("   Name:", peripheral.name ?? "nil")
        print("   ID:", peripheral.identifier)
        print("   RSSI:", RSSI)
        print("   Adv data:", advertisementData)
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }
    
    // MARK: - Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
        print("✅ Connected")
        DispatchQueue.main.async { self.isConnected = true }
        
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        print("📡 Disconnected — attempting reconnect...")
        DispatchQueue.main.async
        {
            self.isConnected = false
        }
        
        // Attempt immediate reconnect if we still have the peripheral reference
        if let peripheral = self.peripheral
        {
            centralManager.connect(peripheral, options: nil)
        }
        else
        {
            // Fall back to scanning if peripheral reference was lost
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    // MARK: - Services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        if let error = error
        {
            print("❌ Service discovery error:", error)
            return
        }
        
        guard let services = peripheral.services else
        {
            print("❌ No services found")
            return
        }
        
        print("📦 Found \(services.count) service(s)")
        
        for service in services
        {
            print("📦 Service:", service.uuid)
            // Pass nil to discover ALL characteristics, not just charUUID
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // MARK: - Characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
        if let error = error
        {
            print("❌ Characteristic discovery error:", error)
            return
        }
        
        guard let chars = service.characteristics else
        {
            print("❌ No characteristics found")
            return
        }

        print("🔍 All characteristics for service \(service.uuid):")
        for c in chars
        {
            print("   UUID: \(c.uuid) | properties: \(c.properties.rawValue)")
        }
        
        print("🔧 Found \(chars.count) characteristic(s):")
        for c in chars
        {
            print("   UUID:", c.uuid)
            print("   Properties:", c.properties.rawValue)
            print("   Can notify:", c.properties.contains(.notify))
            print("   Can read:", c.properties.contains(.read))
            
            // Match by UUID first — don't rely solely on property flags,
            // as a characteristic can have multiple properties and the else-if
            // chain would miss the second branch.
            if c.uuid == cmdUUID
            {
                print("✏️ Command characteristic found:", c.uuid)
                cmdCharacteristic = c
            }

            // Separately handle notify subscription (non-exclusive)
            if c.properties.contains(.notify)
            {
                print("🔔 Subscribing to:", c.uuid)
                peripheral.setNotifyValue(true, for: c)
            }
            else if c.properties.contains(.read)
            {
                print("📖 Reading:", c.uuid)
                peripheral.readValue(for: c)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
        if let error = error //all of the following statements are used for debugging
        {
            print("❌ BLE error:", error)
            return
        }
        
        guard let data = characteristic.value else
        {
            print("❌ No data received")
            return
        }
        
        print("📦 Raw bytes:", data as NSData)
        
        guard let str = String(data: data, encoding: .utf8) else
        {
            print("❌ Could not decode as UTF-8")
            return
        }
        
        print("📨 Raw string: '\(str)'")
        
        let cleanStr = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanStr == "K" { return }  // ignore keepalive packets
        
        let components = cleanStr.components(separatedBy: ",")
        print("🔍 Components:", components)
        
        DispatchQueue.main.async
        {
            if components.count >= 2
            {
                let p = Double(components[0]) ?? 0.0
                let t = Double(components[1]) ?? 0.0
                let b = components.count >= 3 ? (Int(components[2]) ?? 0) : self.battery
                
                print("✅ Parsed — pressure: \(p), temp: \(t), battery: \(b)")
                
                self.pressure = p
                self.temperature = t
                self.battery = b
                self.checkAlarm(pressure: p)
                
                let now = Date()
                let newPoint = PressurePoint(id: self.pressureHistory.count, date: now, value: p)
                self.pressureHistory.append(newPoint)
                self.calculateTrend(currentPressure: p)
                self.logToCSV(timestamp: now, pressure: p, temp: t, battery: b)
            }
            else
            {
                print("❌ Not enough components — got \(components.count), need at least 2")
            }
        }
    }

    // Helper function to handle the actual file writing
    func logToCSV(timestamp: Date, pressure: Double, temp: Double, battery: Int)
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"  // added milliseconds
        let timestampStr = formatter.string(from: timestamp)
        
        // Wrap timestamp in quotes so Excel/Numbers treats it as text, not a date
        //can be changed/deleted if software other than Excel/Numbers is used to open the csv file
        let logLine = "\"\(timestampStr)\",\(pressure),\(temp),\(battery)\n"
        
        if let data = logLine.data(using: .utf8)
        {
            fileHandle?.write(data)
            try? fileHandle?.synchronize()
        }
    }
        
    func setupCSVFile()
    {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent(fileName)
        
        if !fileManager.fileExists(atPath: path.path)
        {
            // Create the file first, THEN open the handle
            fileManager.createFile(atPath: path.path, contents: nil)
            fileHandle = try? FileHandle(forWritingTo: path)
            let header = "\"Timestamp\",Pressure,Temperature,Battery\n"
            if let data = header.data(using: .utf8)
            {
                fileHandle?.write(data)
            }
        }
        else
        {
            fileHandle = try? FileHandle(forWritingTo: path)
            fileHandle?.seekToEndOfFile()
        }
    }
        
    func calculateTrend(currentPressure: Double)
    {
        let now = Date()
        // Try to find a point from 1 hour ago
        let oneHourAgo = now.addingTimeInterval(-3600)
            
        if let oldPoint = self.pressureHistory.first(where: { $0.date >= oneHourAgo })
        {
            self.pressureChangePerHour = currentPressure - oldPoint.value
            }
        else if let firstPoint = self.pressureHistory.first
        {
            // If we have less than an hour, show the trend since the very first reading
            self.pressureChangePerHour = currentPressure - firstPoint.value
        }
    }
    // Zero function zeroing pressure on esp32
    func sendZeroCommand()
    {
        guard let peripheral = peripheral else //following statements used for debugging to figure out what's going wrong with zeroing
        {
            print("❌ Cannot zero: no peripheral")
            return
        }
        guard let cmd = cmdCharacteristic else
        {
            print("❌ Cannot zero: cmdCharacteristic is nil — characteristic not discovered yet")
            return
        }
        guard let data = "ZERO".data(using: .utf8) else
        {
            print("❌ Cannot zero: failed to encode string")
            return
        }
        // Use .withResponse so we get a confirmation callback; fall back to withoutResponse
        let writeType: CBCharacteristicWriteType = cmd.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: cmd, type: writeType)
        print("✏️ Sent ZERO command to firmware")

        // Also reset the local history so the chart starts fresh from zero
        DispatchQueue.main.async
        {
            self.pressureHistory = []
            self.pressureChangePerHour = 0.0
        }
    }

    func requestNotificationPermission()
    {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        {
            granted, _ in
            print("Notifications permission granted:", granted)
        }
    }

    func checkAlarm(pressure: Double) //alarm for when pressure passes alarm pressure value
    {
        guard alarmEnabled, pressure > alarmThreshold else
        {
            DispatchQueue.main.async
            {
                self.alarmTriggered = false
            }
            return
        }
        
        DispatchQueue.main.async
        {
            self.alarmTriggered = true
        }
        
        // Play sound if app is in foreground
        AudioServicesPlaySystemSound(1005) // built-in iOS alert sound
        
        // Fire local notification (rate-limited to once per minute)
        let now = Date()
        guard now.timeIntervalSince(lastNotificationTime) > 60 else
        {
            return
        }
        lastNotificationTime = now
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ ICP Alert"
        content.body = String(format: "Pressure is %.1f mmHg — above threshold of %.1f mmHg", pressure, alarmThreshold)
        content.sound = .defaultCritical  // plays even in silent mode
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
