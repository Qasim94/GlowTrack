//
//  ContentView.swift
//  GlowTrack
//
//  Created by Qasim on 28.09.25.
//

import SwiftUI
import Combine

// Data Models
struct MealLog: Identifiable, Codable {
    let id: UUID
    var foods: [String] // List of foods eaten
    var date: Date
    var mealType: String // breakfast, lunch, dinner, snack
    
    init(foods: [String], date: Date, mealType: String) {
        self.id = UUID()
        self.foods = foods
        self.date = date
        self.mealType = mealType
    }
}

struct AcneLog: Identifiable, Codable {
    let id: UUID
    var severity: Int // 1-5 scale
    var location: String
    var notes: String
    var date: Date
    
    init(severity: Int, location: String, notes: String, date: Date) {
        self.id = UUID()
        self.severity = severity
        self.location = location
        self.notes = notes
        self.date = date
    }
}

// Data Manager
class DataManager: ObservableObject {
    @Published var meals: [MealLog] = []
    @Published var acneLogs: [AcneLog] = []
    
    func addMeal(_ meal: MealLog) {
        meals.append(meal)
        saveData()
    }
    
    func addAcneLog(_ acneLog: AcneLog) {
        acneLogs.append(acneLog)
        saveData()
    }
    
    func getEntriesForDate(_ date: Date) -> (meals: [MealLog], acneLogs: [AcneLog]) {
        let calendar = Calendar.current
        let mealsForDate = meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let acneForDate = acneLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return (mealsForDate, acneForDate)
    }
    
    private func saveData() {
        // In a real app, you'd save to Core Data or UserDefaults
        // For now, data is kept in memory
    }
}

struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Title
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    
                    Text("GlowTrack")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your meals and skin health")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Main Action Buttons
                VStack(spacing: 20) {
                    NavigationLink(destination: MealLogView(dataManager: dataManager)) {
                        ActionButton(
                            title: "Add Meal",
                            icon: "fork.knife",
                            color: .green
                        )
                    }
                    
                    NavigationLink(destination: AcneLogView(dataManager: dataManager)) {
                        ActionButton(
                            title: "Add Acne Log",
                            icon: "face.smiling",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: CalendarView(dataManager: dataManager)) {
                        ActionButton(
                            title: "View Calendar",
                            icon: "calendar",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// F-001: Meal Logging Feature
struct MealLogView: View {
    @ObservedObject var dataManager: DataManager
    @State private var currentFoodText = ""
    @State private var foods: [String] = []
    @State private var selectedMealType = "breakfast"
    @State private var selectedDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("Log Your Meal")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            Form {
                Section("Meal Details") {
                    // Meal Type Picker
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Date Picker
                    DatePicker("Date & Time", selection: $selectedDate)
                }
                
                Section("Foods Eaten") {
                    // Add Food Section
                    HStack {
                        TextField("Enter a food item...", text: $currentFoodText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: addFood) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        .disabled(currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // List of Foods
                    if !foods.isEmpty {
                        ForEach(Array(foods.enumerated()), id: \.offset) { index, food in
                            HStack {
                                Text(food)
                                    .font(.body)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeFood(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if foods.isEmpty {
                        Text("No foods added yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .formStyle(GroupedFormStyle())
            
            // Save Button
            Button(action: saveMeal) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Meal")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(foods.isEmpty ? Color.gray : Color.green)
                .cornerRadius(12)
            }
            .disabled(foods.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Add Meal")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addFood() {
        let trimmedFood = currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedFood.isEmpty {
            foods.append(trimmedFood)
            currentFoodText = ""
        }
    }
    
    private func removeFood(at index: Int) {
        foods.remove(at: index)
    }
    
    private func saveMeal() {
        // F-001 Error handling: Error if no foods added
        if foods.isEmpty {
            alertMessage = "Please add at least one food item."
            showingAlert = true
            return
        }
        
        let meal = MealLog(
            foods: foods,
            date: selectedDate,
            mealType: selectedMealType
        )
        
        dataManager.addMeal(meal)
        
        // Reset form
        foods = []
        currentFoodText = ""
        selectedDate = Date()
        selectedMealType = "breakfast"
        
        // Go back to home screen
        presentationMode.wrappedValue.dismiss()
    }
}

// F-003: Acne Logging Feature
struct AcneLogView: View {
    @ObservedObject var dataManager: DataManager
    @State private var severity = 1
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    let faceLocations = ["forehead", "cheeks", "chin", "nose", "jawline", "other"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Log Acne Breakout")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            Form {
                Section("Acne Details") {
                    // Severity Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Severity: \(severity)/5")
                            .font(.headline)
                        
                        HStack {
                            Text("1")
                                .foregroundColor(.green)
                            Slider(value: Binding(
                                get: { Double(severity) },
                                set: { severity = Int($0) }
                            ), in: 1...5, step: 1)
                            Text("5")
                                .foregroundColor(.red)
                        }
                        
                        Text(getSeverityDescription(severity))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Location Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        Picker("Face Location", selection: $location) {
                            Text("Select location").tag("")
                            ForEach(faceLocations, id: \.self) { loc in
                                Text(loc.capitalized).tag(loc)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Date Picker
                    DatePicker("Date & Time", selection: $selectedDate)
                    
                    // Notes Entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Notes")
                            .font(.headline)
                        
                        TextField("Any additional details...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
            }
            .formStyle(GroupedFormStyle())
            
            // Save Button
            Button(action: saveAcneLog) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Acne Log")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidEntry() ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isValidEntry())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Add Acne Log")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func getSeverityDescription(_ severity: Int) -> String {
        switch severity {
        case 1: return "Very mild - barely noticeable"
        case 2: return "Mild - small breakout"
        case 3: return "Moderate - noticeable breakout"
        case 4: return "Severe - large breakout"
        case 5: return "Very severe - extensive breakout"
        default: return ""
        }
    }
    
    private func isValidEntry() -> Bool {
        return !location.isEmpty
    }
    
    private func saveAcneLog() {
        // F-003 Error handling: Error if nothing entered
        if location.isEmpty {
            alertMessage = "Please select a location for the acne breakout."
            showingAlert = true
            return
        }
        
        let acneLog = AcneLog(
            severity: severity,
            location: location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            date: selectedDate
        )
        
        dataManager.addAcneLog(acneLog)
        
        // Reset form
        severity = 1
        location = ""
        notes = ""
        selectedDate = Date()
        
        // Go back to home screen
        presentationMode.wrappedValue.dismiss()
    }
}

// F-005: Calendar History Feature
struct CalendarView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedDate = Date()
    @State private var showingDateDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar Header
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Your History")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // Calendar
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding(.horizontal, 20)
            .onChange(of: selectedDate) {
                showingDateDetail = true
            }
            
            // Date Indicators
            VStack(spacing: 12) {
                Text("Legend:")
                    .font(.headline)
                    .padding(.top, 20)
                
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Meals")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Acne Logs")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // View Details Button
            Button(action: {
                showingDateDetail = true
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("View Details for Selected Date")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDateDetail) {
            DateDetailView(
                dataManager: dataManager,
                selectedDate: selectedDate,
                isPresented: $showingDateDetail
            )
        }
    }
}

// Date Detail View - shows entries for selected date
struct DateDetailView: View {
    @ObservedObject var dataManager: DataManager
    let selectedDate: Date
    @Binding var isPresented: Bool
    
    var entries: (meals: [MealLog], acneLogs: [AcneLog]) {
        dataManager.getEntriesForDate(selectedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Date Header
                VStack(spacing: 8) {
                    Text(selectedDate, style: .date)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(entries.meals.count) meals, \(entries.acneLogs.count) acne logs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Meals Section
                        if !entries.meals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "fork.knife")
                                        .foregroundColor(.green)
                                    Text("Meals")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                ForEach(entries.meals) { meal in
                                    MealEntryCard(meal: meal)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Acne Logs Section
                        if !entries.acneLogs.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "face.smiling")
                                        .foregroundColor(.blue)
                                    Text("Acne Logs")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                ForEach(entries.acneLogs) { acneLog in
                                    AcneEntryCard(acneLog: acneLog)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // No Data Message
                        if entries.meals.isEmpty && entries.acneLogs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No data found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("No meals or acne logs recorded for this date.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        }
                    }
                }
            }
            .navigationTitle("Date Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

// Meal Entry Card
struct MealEntryCard: View {
    let meal: MealLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.mealType.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(meal.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(meal.foods, id: \.self) { food in
                    HStack {
                        Text("•")
                            .foregroundColor(.green)
                        Text(food)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// Acne Entry Card
struct AcneEntryCard: View {
    let acneLog: AcneLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(acneLog.location.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("Severity: \(acneLog.severity)/5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(acneLog.notes.isEmpty ? "No additional notes" : acneLog.notes)
                .font(.body)
                .foregroundColor(acneLog.notes.isEmpty ? .secondary : .primary)
            
            Text(acneLog.date, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
