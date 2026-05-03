//
//  ContentView.swift
//  compartmentSyndrome
//
//  Created by Sophia Torrellas on 5/2/26.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject var ble = BLEManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection & Battery Header
                HStack {
                    StatusPill(isConnected: ble.isConnected)
                    Spacer()
                    Label("\(ble.battery)%", systemImage: "battery.100")
                        .foregroundColor(ble.battery < 20 ? .red : .green)
                }
                .padding(.horizontal)
                
                Text("ICP Monitor")
                    .font(.largeTitle.bold())
                
                // 2. Pressure Graph with Time Axis in Minutes
                VStack(alignment: .leading) {
                    Text("Pressure (mmHg) over Time")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(ble.pressureHistory) { point in
                            LineMark(
                                x: .value("Reading", point.id), // Plotted by sequence (0, 1, 2...)
                                y: .value("Pressure", point.value)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXScale(domain: .automatic(includesZero: true)) // Starts at 0 on the left
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            if let index = value.as(Int.self) {
                                // Convert index back to minutes for the label
                                // Assumes 10Hz (600 readings per minute)
                                let minute = index / 600
                                if index % 600 == 0 { // Only label every full minute
                                    AxisValueLabel("\(minute)m")
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    // 3. Numerical Readouts (Consolidated)
                    HStack(spacing: 15) {
                        MetricCard(title: "Pressure",
                                   value: String(format: "%.1f", ble.pressure),
                                   unit: "mmHg",
                                   color: .blue)
                        
                        MetricCard(title: "Temp",
                                   value: String(format: "%.1f", ble.temperature), // Must be ble.temperature
                                   unit: "°C",
                                   color: .orange)
                    }
                    
                    // 1-Hour Trend Card (Now solitary below the main metrics)
                    MetricCard(title: "1-Hour Trend",
                               value: String(format: "%+.1f", ble.pressureChangePerHour),
                               unit: "mmHg/hr",
                               color: .secondary)
                    
                    // Export Button
                    ShareLink(item: getDocumentsDirectory().appendingPathComponent("ICP_Data_Log.csv")) {
                        Label("Export 24hr CSV", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
  
                }
                .padding()
            }
        }
        
    }
    // --- Add these components to the bottom of the file ---
    
    struct StatusPill: View {
        let isConnected: Bool
        var body: some View {
            HStack {
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
    
    struct MetricCard: View {
        let title: String
        let value: String
        let unit: String
        let color: Color
        
        var body: some View {
            VStack {
                Text(title).font(.caption).foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
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
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
