import Foundation
import Combine
import CoreBluetooth
import SwiftUI


struct PressurePoint: Identifiable {
    let id: Int    // This will be the index (0, 1, 2...)
    let date: Date
    let value: Double
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var fileHandle: FileHandle?
    private let fileName = "ICP_Data_Log.csv"
    
    //    let objectWillChange = ObservableObjectPublisher()
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    
    @Published var isConnected = false
    @Published var pressure: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var battery: Int = 0
    @Published var pressureHistory: [PressurePoint] = []
    @Published var pressureChangePerHour: Double = 0.0 // The new delta value
    @Published var sessionStartTime = Date() // Track when the app opened
    
    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    let charUUID = CBUUID(string: "abcd1234-5678-90ab-cdef-123456789abc")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Bluetooth state
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔵 BLE ON - scanning...")
            let services: [CBUUID] = [self.serviceUUID]
            central.scanForPeripherals(withServices: services, options: nil)
        }
    }
    // MARK: - Found device
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
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
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected")
        DispatchQueue.main.async { self.isConnected = true }
        
        peripheral.discoverServices([serviceUUID])
    }
    
    // MARK: - Services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("📦 Service:", service.uuid)
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
    }
    
    // MARK: - Characteristics
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        guard let chars = service.characteristics else { return }
        
        for c in chars {
            print("🔧 CHARACTERISTIC:", c.uuid)
            
            print("   Properties:", c.properties)
            
            if c.properties.contains(.notify) {
                print("🔔 Subscribing to:", c.uuid)
                peripheral.setNotifyValue(true, for: c)
            }
        }
    }
    
    // MARK: - 🔥 THIS IS THE ONLY IMPORTANT PART
    // MARK: - Updated Combined BLE Logic
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let str = String(data: data, encoding: .utf8) else { return }
        
        // Clean the string of any hidden whitespace/newlines from the ESP32
        let cleanStr = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = cleanStr.components(separatedBy: ",")
        
        DispatchQueue.main.async {
            // Parse Pressure (First component)
            if components.count >= 1 {
                self.pressure = Double(components[0]) ?? 0.0
            }
            
            // Parse Temperature (Second component)
            if components.count >= 2 {
                self.temperature = Double(components[1]) ?? 0.0
            }
            
            // Update History and Trend (using current self.pressure)
            let now = Date()
            let newPoint = PressurePoint(id: self.pressureHistory.count,
                                         date: now,
                                         value: self.pressure)
            self.pressureHistory.append(newPoint)
            
            // ... (Trend logic remains the same)
        }
    }
        
        func setupCSVFile() {
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let path = docs.appendingPathComponent(fileName)
            
            // Create the file immediately if it doesn't exist
            if !fileManager.fileExists(atPath: path.path) {
                let header = "Timestamp,Pressure,Temperature,Battery\n"
                try? header.write(to: path, atomically: true, encoding: .utf8)
            }
            
            fileHandle = try? FileHandle(forWritingTo: path)
            fileHandle?.seekToEndOfFile()
        }
        func calculateTrend(currentPressure: Double) {
            let now = Date()
            // Try to find a point from 1 hour ago
            let oneHourAgo = now.addingTimeInterval(-3600)
            
            if let oldPoint = self.pressureHistory.first(where: { $0.date >= oneHourAgo }) {
                self.pressureChangePerHour = currentPressure - oldPoint.value
            } else if let firstPoint = self.pressureHistory.first {
                // If we have less than an hour, show the trend since the very first reading
                self.pressureChangePerHour = currentPressure - firstPoint.value
            }
        }
    }
