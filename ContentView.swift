//  ContentView.swift
//  compartmentSyndrome
//
//  Created by Sophia Torrellas on 5/2/26.
//

import SwiftUI
import Charts

struct ContentView: View
{
    @StateObject var ble = BLEManager()
    @State private var showShareSheet = false
    @State private var csvFileURL: URL? = nil
    @State private var showZeroConfirm = false
    @State private var justZeroed = false
    
    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 20)
            {
                // Connection & Battery Header
                HStack
                {
                    StatusPill(isConnected: ble.isConnected)
                    Spacer()
                    Label("\(ble.battery)%", systemImage: "battery.100")
                        .foregroundColor(ble.battery < 20 ? .red : .green)
                }
                .padding(.horizontal)
                
                Text("ICP Monitor")
                    .font(.largeTitle.bold())
                
                VStack(alignment: .leading) {
                    Text("Pressure (mmHg) over Time")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Chart
                    {
                        ForEach(ble.pressureHistory)
                        { point in
                            LineMark(x: .value("Reading", point.id), y: .value("Pressure", point.value))
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXScale(domain: .automatic(includesZero: true))
                    .chartXAxis
                    {
                        AxisMarks(values: .automatic)
                        {
                            value in
                            AxisGridLine()
                            if let index = value.as(Int.self)
                            {
                                let minute = index / 600
                                if index % 600 == 0
                                {
                                    AxisValueLabel("\(minute)m")
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    HStack(spacing: 15)
                    {
                        MetricCard(title: "Pressure", value: String(format: "%.1f", ble.pressure), unit: "mmHg", color: .blue)
                        MetricCard(title: "Temp", value: String(format: "%.1f", ble.temperature), unit: "°C", color: .orange)
                    }
                    
                    MetricCard(title: "1-Hour Trend", value: String(format: "%+.1f", ble.pressureChangePerHour), unit: "mmHg/hr", color: .secondary)

                    // Zero/Tare Button
                    Button
                    {
                        showZeroConfirm = true
                    }
                   
                    label:
                    
                    {
                        HStack
                        {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text(justZeroed ? "Zeroed ✓" : "Zero Pressure")
                            .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(ble.isConnected ? Color.indigo : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    .disabled(!ble.isConnected)
                    .confirmationDialog("Zero the pressure sensor?", isPresented: $showZeroConfirm, titleVisibility: .visible)
                    {
                        Button("Zero Now", role: .destructive)
                        {
                            ble.sendZeroCommand()
                            justZeroed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
                            {
                                justZeroed = false
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    message:
                    {
                        Text("This sets the current reading as 0 mmHg and clears the chart history. Use this to remove the ambient/atmospheric baseline before a measurement.")
                    }
                    // Alarm Control Card
                    VStack(alignment: .leading, spacing: 10)
                    {
                        Text("Pressure Alarm")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        
                        Toggle("Enable Alarm", isOn: $ble.alarmEnabled)
                        
                        if ble.alarmEnabled
                        {
                            HStack
                            {
                                Text("Threshold:")
                                Spacer()
                                TextField("mmHg", value: $ble.alarmThreshold, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                                Text("mmHg")
                            }
                        }
                        
                        if ble.alarmTriggered //pressure too high
                        {
                            Label("PRESSURE THRESHOLD EXCEEDED", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(ble.alarmTriggered ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    //Share the CSV text content directly, not a file URL
                    Button
                    {
                        prepareAndShare()
                    }
                    label:
                    {
                        Label("Export Data to CSV File", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .sheet(isPresented: $showShareSheet)
                    {
                        if let url = csvFileURL
                        {
                            ActivityViewController(activityItems: [url])
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // Read the CSV file content as a String
    func getCSVString() -> String
    {
        // Flush any pending writes first
        try? ble.fileHandle?.synchronize()
        
        let fileURL = getDocumentsDirectory().appendingPathComponent("ICP_Data_Log.csv")
        
        if let content = try? String(contentsOf: fileURL, encoding: .utf8)
        {
            return content
        }
        
        // Fallback: build CSV from in-memory history if file read fails
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var csv = "Timestamp,Pressure,Temperature,Battery\n"
        for point in ble.pressureHistory
        {
            csv += "\(formatter.string(from: point.date)),\(point.value),\(ble.temperature),\(ble.battery)\n"
        }
        return csv
    }
    
    func getDocumentsDirectory() -> URL
    {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    func prepareAndShare()
    {
        // 1. Flush any pending BLE writes
        try? ble.fileHandle?.synchronize()
        
        let sourceURL = getDocumentsDirectory().appendingPathComponent("ICP_Data_Log.csv")
        let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ICP_Export_\(Int(Date().timeIntervalSince1970)).csv")
        
        // 2. Ensure a valid file always exists to share
        if FileManager.default.fileExists(atPath: sourceURL.path)
        {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.copyItem(at: sourceURL, to: tempURL)
        }
        
        else
        {
            // Build from in-memory history as fallback
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            var csv = "Timestamp,Pressure,Temperature,Battery\n"
            for point in ble.pressureHistory
            {
                csv += "\(formatter.string(from: point.date)),\(point.value),\(ble.temperature),\(ble.battery)\n"
            }
            try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        }
        
        csvFileURL = tempURL
        showShareSheet = true
    }
}

struct StatusPill: View
{
    let isConnected: Bool
    var body: some View
    {
        HStack
        {
            Circle().frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Disconnected")
            .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isConnected ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .foregroundColor(isConnected ? .green : .red)
        .clipShape(Capsule())
    }
}

struct MetricCard: View
{
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View
    {
        VStack
        {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2)
            {
                Text(value).font(.system(size: 30, weight: .bold, design: .monospaced))
                Text(unit).font(.caption).bold()
            }
            .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

import UIKit

struct ActivityViewController: UIViewControllerRepresentable
{
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController
    {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

