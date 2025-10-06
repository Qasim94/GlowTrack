//
//  ContentView.swift
//  GlowTrack
//
//  Created by Qasim on 28.09.25.
//

import SwiftUI
import Foundation
import Combine
#if DEBUG
import Darwin
#endif

// Data Models
struct IngredientAnalysis: Identifiable, Codable {
    let id: UUID
    let name: String
    let acneRisk: String // "low", "medium", "high"
    let explanation: String
    
    init(name: String, acneRisk: String, explanation: String) {
        self.id = UUID()
        self.name = name
        self.acneRisk = acneRisk
        self.explanation = explanation
    }
}

struct ChatGPTResponse: Codable {
    let meals: [MealAnalysis]
}

struct MealAnalysis: Codable {
    let dish: String
    let ingredients: [IngredientAnalysis]
}

struct MealLog: Identifiable, Codable {
    let id: UUID
    var foods: [String] // List of foods eaten
    var selectedIngredients: [IngredientAnalysis] // Selected ingredients with analysis
    var date: Date
    var mealType: String // breakfast, lunch, dinner, snack
    
    init(foods: [String], selectedIngredients: [IngredientAnalysis] = [], date: Date, mealType: String) {
        self.id = UUID()
        self.foods = foods
        self.selectedIngredients = selectedIngredients
        self.date = date
        self.mealType = mealType
    }
}

// Data Manager
class DataManager: ObservableObject {
    @Published var meals: [MealLog] = []
    
    func addMeal(_ meal: MealLog) {
        meals.append(meal)
    }
    
    func getEntriesForDate(_ date: Date) -> [MealLog] {
        let calendar = Calendar.current
        return meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func updateMeal(_ updated: MealLog) {
        if let idx = meals.firstIndex(where: { $0.id == updated.id }) {
            meals[idx] = updated
        }
    }
    
    func deleteMeal(id: UUID) {
        meals.removeAll { $0.id == id }
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
                    
                    Text("Track your meals and discover acne triggers")
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
                            title: "Log Your Meal",
                            icon: "fork.knife",
                            color: .blue
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// F-001: Meal Logging Feature
struct MealLogView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var selectedMealType = "breakfast"
    @State private var selectedTime = Date()
    @State private var currentFoodText = ""
    @State private var foods: [String] = [] // For food list option
    @State private var selectedInputMethod: MealInputMethod? = nil
    @State private var mealsAnalysis: [MealAnalysis] = [] // Store meals with dish names
    @State private var ingredientAnalysis: [IngredientAnalysis] = [] // Flattened for backward compatibility
    @State private var manualIngredients: [IngredientAnalysis] = [] // Manually added ingredients
    @State private var manualIngredientText = "" // Text for manual ingredient input
    @State private var selectedIngredients: [String: Set<UUID>] = [:] // Track selected ingredients by dish name
    @State private var isAnalyzing = false
    @State private var isAnalyzingManualIngredient = false
    @State private var analysisError: String?
    
    enum MealInputMethod: String, CaseIterable {
        case foodList = "foodList"
        case description = "description"
        
        var title: String {
            switch self {
            case .foodList: return "Add Food/Dish"
            case .description: return "Describe What You Eat"
            }
        }
        
        var subtitle: String {
            switch self {
            case .foodList: return "You can add food list we breakdown into ingredients"
            case .description: return "Short description of what you ate and we breakdown"
            }
        }
        
        var icon: String {
            switch self {
            case .foodList: return "list.bullet"
            case .description: return "text.bubble"
            }
        }
    }
    
    private let mealTypes = [
        ("breakfast", "🌅", "Breakfast"),
        ("lunch", "☀️", "Lunch"),
        ("dinner", "🌙", "Dinner"),
        ("snack", "🍿", "Snack")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress indicator - positioned properly
                HStack {
                    ForEach(1...4, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                        
                        if step < 4 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Step content with proper spacing
                ScrollView {
                    VStack(spacing: 20) {
                        if currentStep == 1 {
                            step1Content
                        } else if currentStep == 2 {
                            step2Content
                        } else if currentStep == 3 {
                            step3Content
                        } else if currentStep == 4 {
                            step4Content
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                
                // Navigation buttons - fixed at bottom with proper spacing
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(.systemGray4))
                    
                    HStack {
                        // Always show back button
                        Button("Back") {
                            if currentStep > 1 {
                                withAnimation { currentStep -= 1 }
                            } else {
                                // Go back to main screen (dismiss the view)
                                dismiss()
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        
                        Spacer()
                        
                        if currentStep < 4 {
                            Button("Next") {
                                withAnimation { currentStep += 1 }
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                        } else {
                            Button("Save Meal") {
                                saveMeal()
                            }
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(canSaveMeal() ? Color.green : Color.gray)
                            .cornerRadius(12)
                            .disabled(!canSaveMeal())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Step 1: Choose Meal Type
    private var step1Content: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 80)
            
            VStack(spacing: 24) {
                Text("Choose your meal type")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    ForEach(mealTypes, id: \.0) { type, emoji, label in
                        Button(action: {
                            selectedMealType = type
                        }) {
                            HStack(spacing: 16) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                
                                Text(label)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedMealType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedMealType == type ? Color.blue.opacity(0.1) : Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedMealType == type ? Color.blue : Color(.systemGray4), lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
                .frame(minHeight: 80)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Step 2: Add Time
    private var step2Content: some View {
        VStack(spacing: 20) {
            Text("When did you eat?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            // Calendar for date selection
            VStack(spacing: 12) {
                Text("Select Date")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                DatePicker("", selection: $selectedTime, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // Time selection section
            VStack(spacing: 12) {
                Text("Select Time")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Native iOS Time Picker
                DatePicker("Time", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .frame(height: 200)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Step 3: Choose Input Method
    private var step3Content: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 12) {
                Text("How would you like to log your meal?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Choose the method that works best for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Input method options
            VStack(spacing: 16) {
                ForEach(MealInputMethod.allCases, id: \.self) { method in
                    Button(action: {
                        selectedInputMethod = method
                        withAnimation { currentStep += 1 }
                    }) {
                        HStack(spacing: 16) {
                            // Icon
                            Image(systemName: method.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.title)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(method.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            // Arrow
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 4: Add Meal Content
    private var step4Content: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header based on selected method
                VStack(spacing: 8) {
                    if selectedInputMethod == .foodList {
                        Text("Add Food/Dish")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Add the foods you consumed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Describe what you ate")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Tell us about your meal in your own words")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 8)
                
                // Content based on selected input method
                if selectedInputMethod == .foodList {
                    // Food List Input Method
                    VStack(spacing: 16) {
                        // Food input
                        HStack {
                            TextField("Enter dish name (e.g., Pizza, Salad)", text: $currentFoodText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: addFood) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .disabled(currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        // Added foods display
                        if !foods.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Added foods:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                                    ForEach(Array(foods.enumerated()), id: \.offset) { index, item in
                                        HStack(spacing: 4) {
                                            Text(item)
                                                .font(.caption)
                                                .lineLimit(1)
                                            
                                            Button(action: { removeFood(at: index) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption2)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        // Analyze button for food list
                        if !foods.isEmpty && !isAnalyzing {
                            Button(action: analyzeIngredients) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Analyze Ingredients")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Description Input Method
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Your meal description")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        ZStack(alignment: .topLeading) {
                            if currentFoodText.isEmpty {
                                Text("e.g., I had a large pepperoni pizza with extra cheese, a Caesar salad with grilled chicken, and a can of Coca-Cola")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .font(.body)
                            }
                            
                            TextEditor(text: $currentFoodText)
                                .frame(minHeight: 120)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(currentFoodText.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Analyze button for description
                    if !currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: analyzeIngredients) {
                            HStack(spacing: 10) {
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                Text(isAnalyzing ? "Analyzing your meal..." : "Analyze Ingredients")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isAnalyzing ? [Color.gray, Color.gray] : [Color.purple, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: isAnalyzing ? Color.clear : Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isAnalyzing)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.2), value: isAnalyzing)
                    }
                }
                
                // Loading state
                if isAnalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing ingredients...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                // Error display
                if let error = analysisError {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Analysis Error")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                // Analysis results
                if !mealsAnalysis.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                Text("Ingredient Analysis")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(mealsAnalysis.count) dishes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            
                            Text("Tap ingredients to select which ones you actually consumed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        }
                        
                        VStack(spacing: 24) {
                            ForEach(mealsAnalysis, id: \.dish) { meal in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Dish header
                                    HStack {
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        Text(meal.dish)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(meal.ingredients.count) ingredients")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    // Ingredients for this dish
                                    VStack(spacing: 8) {
                                        ForEach(meal.ingredients) { ingredient in
                                            IngredientAnalysisCard(
                                                ingredient: ingredient,
                                                isSelected: isIngredientSelected(ingredient, dishName: meal.dish),
                                                onTap: {
                                                    toggleIngredientSelection(ingredient, dishName: meal.dish)
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        // Manually added ingredients section
                        if !manualIngredients.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "hand.point.up")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                    Text("Manually Added Ingredients")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(manualIngredients.count) ingredients")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .padding(.horizontal, 4)
                                
                                VStack(spacing: 8) {
                                    ForEach(manualIngredients) { ingredient in
                                        IngredientAnalysisCard(
                                            ingredient: ingredient,
                                            isSelected: isIngredientSelected(ingredient, dishName: "Manual Ingredients"),
                                            onTap: {
                                                toggleIngredientSelection(ingredient, dishName: "Manual Ingredients")
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                }
                
                // Manual ingredient addition section
                if !mealsAnalysis.isEmpty || !manualIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text("Add Missing Ingredients")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        Text("Did the AI miss any ingredients? Add them manually:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Manual ingredient input
                        VStack(spacing: 12) {
                            HStack {
                                TextField("Enter ingredient name (e.g., tomatoes, onions)", text: $manualIngredientText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: addManualIngredient) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                                .disabled(manualIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            // Manually added ingredients display
                            if !manualIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Manually Added Ingredients:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(spacing: 6) {
                                        ForEach(Array(manualIngredients.enumerated()), id: \.offset) { index, ingredient in
                                            HStack {
                                                Image(systemName: "hand.point.up")
                                                    .foregroundColor(.orange)
                                                    .font(.caption)
                                                Text(ingredient.name)
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Button(action: { removeManualIngredient(at: index) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundColor(.orange)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Helper Functions
    private func saveMeal() {
        // Collect all selected ingredients
        var allSelectedIngredients: [IngredientAnalysis] = []
        
        // Get selected ingredients from meals analysis
        for meal in mealsAnalysis {
            allSelectedIngredients.append(contentsOf: getSelectedIngredientsForDish(meal.dish))
        }
        
        // Get selected manual ingredients
        allSelectedIngredients.append(contentsOf: getSelectedIngredientsForDish("Manual Ingredients"))
        
        let meal: MealLog
        if selectedInputMethod == .foodList {
            meal = MealLog(foods: foods, selectedIngredients: allSelectedIngredients, date: selectedTime, mealType: selectedMealType)
        } else {
            meal = MealLog(foods: [currentFoodText], selectedIngredients: allSelectedIngredients, date: selectedTime, mealType: selectedMealType)
        }
        dataManager.addMeal(meal)
        
        // Reset form
        currentStep = 1
        selectedMealType = "breakfast"
        selectedTime = Date()
        currentFoodText = ""
        foods = []
        selectedInputMethod = nil
        mealsAnalysis = []
        ingredientAnalysis = []
        manualIngredients = []
        manualIngredientText = ""
        selectedIngredients = [:]
        analysisError = nil
    }
    
    private func addFood() {
        let trimmedFood = currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFood.isEmpty else { return }
        
        foods.append(trimmedFood)
        currentFoodText = ""
    }
    
    private func removeFood(at index: Int) {
        foods.remove(at: index)
    }
    
    private func canSaveMeal() -> Bool {
        if selectedInputMethod == .foodList {
            return !foods.isEmpty
        } else {
            return !currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func addManualIngredient() {
        let trimmedIngredient = manualIngredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIngredient.isEmpty else { return }
        
        // Check if ingredient already exists (case insensitive)
        let exists = manualIngredients.contains { ingredient in
            ingredient.name.lowercased() == trimmedIngredient.lowercased()
        }
        
        if !exists {
            // Create a temporary ingredient with loading state
            let tempIngredient = IngredientAnalysis(
                name: trimmedIngredient,
                acneRisk: "analyzing",
                explanation: "Analyzing ingredient..."
            )
            
            manualIngredients.append(tempIngredient)
            manualIngredientText = ""
            
            // Analyze the ingredient with ChatGPT
            Task {
                do {
                    let analyzedIngredient = try await analyzeSingleIngredient(trimmedIngredient)
                    await MainActor.run {
                        // Update the ingredient with the analysis result
                        if let index = self.manualIngredients.firstIndex(where: { $0.name == trimmedIngredient && $0.acneRisk == "analyzing" }) {
                            self.manualIngredients[index] = analyzedIngredient
                        }
                        self.isAnalyzingManualIngredient = false
                    }
                } catch {
                    await MainActor.run {
                        print("Manual Ingredient Analysis Error: \(error)")
                        // Update with error state
                        if let index = self.manualIngredients.firstIndex(where: { $0.name == trimmedIngredient && $0.acneRisk == "analyzing" }) {
                            self.manualIngredients[index] = IngredientAnalysis(
                                name: trimmedIngredient,
                                acneRisk: "medium",
                                explanation: "Analysis failed - using default risk level"
                            )
                        }
                        self.isAnalyzingManualIngredient = false
                    }
                }
            }
        }
    }
    
    private func removeManualIngredient(at index: Int) {
        guard index < manualIngredients.count else { return }
        manualIngredients.remove(at: index)
    }
    
    private func toggleIngredientSelection(_ ingredient: IngredientAnalysis, dishName: String) {
        if selectedIngredients[dishName] == nil {
            selectedIngredients[dishName] = Set<UUID>()
        }
        
        if let isSelected = selectedIngredients[dishName]?.contains(ingredient.id) {
            if isSelected {
                selectedIngredients[dishName]?.remove(ingredient.id)
            } else {
                selectedIngredients[dishName]?.insert(ingredient.id)
            }
        } else {
            selectedIngredients[dishName]?.insert(ingredient.id)
        }
    }
    
    private func isIngredientSelected(_ ingredient: IngredientAnalysis, dishName: String) -> Bool {
        return selectedIngredients[dishName]?.contains(ingredient.id) ?? false
    }
    
    private func getSelectedIngredientsForDish(_ dishName: String) -> [IngredientAnalysis] {
        guard let selectedIds = selectedIngredients[dishName] else { return [] }
        
        // Get ingredients from meals analysis
        var selectedIngredients: [IngredientAnalysis] = []
        for meal in mealsAnalysis {
            if meal.dish == dishName {
                selectedIngredients.append(contentsOf: meal.ingredients.filter { selectedIds.contains($0.id) })
            }
        }
        
        // Add manually added ingredients if they're selected
        selectedIngredients.append(contentsOf: manualIngredients.filter { selectedIds.contains($0.id) })
        
        return selectedIngredients
    }
    
    // MARK: - ChatGPT Analysis
    private func analyzeIngredients() {
        let mealDescription: String
        if selectedInputMethod == .foodList {
            guard !foods.isEmpty else { return }
            mealDescription = foods.joined(separator: ", ")
        } else {
            let trimmedDescription = currentFoodText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDescription.isEmpty else { return }
            mealDescription = trimmedDescription
        }
        
        isAnalyzing = true
        analysisError = nil
        mealsAnalysis = []
        ingredientAnalysis = []
        
        let prompt = """
        You are an expert nutrition and skin health analyst.

        The user will describe what they ate — it could be a single dish (e.g., "pizza") or multiple dishes (e.g., "biryani with raita and a coke").

        Your task is to:
        1. Identify and separate each dish or drink mentioned.
        2. If the dish can exist in multiple variations (for example, biryani can be chicken, mutton, beef, or prawn), provide ingredient breakdowns for each common variation.
        3. Break down each variation into all its detailed ingredients — including base components, meats, oils, dairy, spices, herbs, and condiments.
        3a. For meat-containing dishes, always break down the specific meat type/cut as individual ingredients (e.g., "chicken breast", "ground beef", "lamb shoulder") rather than generic terms like "chicken" or "beef".
        4. Give atleast 10 ingredients for each dish.
        5. For each ingredient, assess its potential acne risk level (low, medium, or high) and include a short explanation of how it affects acne or skin health.

        Return ONLY valid JSON in this exact format (no markdown, no extra text):
        {
            "meals": [
                {
                    "dish": "dish name (variation)",
                    "ingredients": [
                        {
                            "name": "ingredient name",
                            "acneRisk": "low",
                            "explanation": "brief explanation"
                        }
                    ]
                }
            ]
        }

        Be as specific and comprehensive as possible with ingredients (list oils, spices, sauces, and garnishes).

        Now analyze the following meal description:
        "\(mealDescription)"
        """
        
        Task {
            do {
                let meals = try await callChatGPT(prompt: prompt)
                await MainActor.run {
                    self.mealsAnalysis = meals
                    // Also flatten for backward compatibility
                    self.ingredientAnalysis = meals.flatMap { $0.ingredients }
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    print("ChatGPT Analysis Error: \(error)")
                    self.analysisError = "Failed to analyze ingredients: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func callChatGPT(prompt: String) async throws -> [MealAnalysis] {
        guard let apiKey = Config.getOpenAIAPIKey() else {
            throw NSError(domain: "ConfigError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": Config.maxTokens,
            "temperature": Config.temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        let chatResponse = try JSONDecoder().decode(ChatGPTAPIResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "APIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        print("ChatGPT Response: \(content)")
        
        // Clean the content first
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Cleaned Content: \(cleanedContent)")
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "ParseError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not convert content to data"])
        }
        
        // Try to parse as generic JSON first to see the structure
        do {
            let genericJSON = try JSONSerialization.jsonObject(with: jsonData, options: [])
            print("Generic JSON structure: \(genericJSON)")
            
            // Now try to parse as our specific structure
            let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: jsonData)
            print("Successfully parsed meals: \(chatGPTResponse.meals)")
            
            // Return the meals with their dish names
            return chatGPTResponse.meals
            
        } catch {
            print("JSON Parse Error: \(error)")
            
            // If the structure is different, try to extract meals manually
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                var meals: [MealAnalysis] = []
                
                // Try new structure first (meals -> ingredients)
                if let mealsArray = jsonObject["meals"] as? [[String: Any]] {
                    for mealDict in mealsArray {
                        if let dishName = mealDict["dish"] as? String,
                           let ingredientsArray = mealDict["ingredients"] as? [[String: Any]] {
                            
                            var ingredients: [IngredientAnalysis] = []
                            for ingredientDict in ingredientsArray {
                                if let name = ingredientDict["name"] as? String,
                                   let acneRisk = ingredientDict["acneRisk"] as? String,
                                   let explanation = ingredientDict["explanation"] as? String {
                                    
                                    let ingredient = IngredientAnalysis(
                                        name: name,
                                        acneRisk: acneRisk,
                                        explanation: explanation
                                    )
                                    ingredients.append(ingredient)
                                }
                            }
                            
                            if !ingredients.isEmpty {
                                let meal = MealAnalysis(dish: dishName, ingredients: ingredients)
                                meals.append(meal)
                            }
                        }
                    }
                }
                // Fallback to old structure (direct ingredients) - create a generic meal
                else if let ingredientsArray = jsonObject["ingredients"] as? [[String: Any]] {
                    var ingredients: [IngredientAnalysis] = []
                    for ingredientDict in ingredientsArray {
                        if let name = ingredientDict["name"] as? String,
                           let acneRisk = ingredientDict["acneRisk"] as? String,
                           let explanation = ingredientDict["explanation"] as? String {
                            
                            let ingredient = IngredientAnalysis(
                                name: name,
                                acneRisk: acneRisk,
                                explanation: explanation
                            )
                            ingredients.append(ingredient)
                        }
                    }
                    
                    if !ingredients.isEmpty {
                        let meal = MealAnalysis(dish: "Meal", ingredients: ingredients)
                        meals.append(meal)
                    }
                }
                
                if !meals.isEmpty {
                    print("Successfully parsed \(meals.count) meals manually")
                    return meals
                }
            }
            
            throw NSError(domain: "ParseError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not parse JSON response: \(cleanedContent)"])
        }
    }
    
    private func analyzeSingleIngredient(_ ingredientName: String) async throws -> IngredientAnalysis {
        guard let apiKey = Config.getOpenAIAPIKey() else {
            throw NSError(domain: "ConfigError", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        You are an expert nutrition and skin health analyst.

        Analyze the following single ingredient for its potential acne risk level and skin health impact.

        Your task is to:
        1. Assess the ingredient's potential acne risk level (low, medium, or high)
        2. Provide a brief explanation of how it affects acne or skin health

        Return ONLY valid JSON in this exact format (no markdown, no extra text):
        {
            "name": "ingredient name",
            "acneRisk": "low",
            "explanation": "brief explanation"
        }

        Now analyze this ingredient:
        "\(ingredientName)"
        """
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": Config.maxTokens,
            "temperature": Config.temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let chatResponse = try JSONDecoder().decode(ChatGPTAPIResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "APIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        print("Single Ingredient Analysis Response: \(content)")
        
        // Clean the content first
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "ParseError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not convert content to data"])
        }
        
        // Try to parse the single ingredient response
        do {
            let ingredient = try JSONDecoder().decode(IngredientAnalysis.self, from: jsonData)
            return ingredient
        } catch {
            // Fallback to manual parsing
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
               let name = jsonObject["name"] as? String,
               let acneRisk = jsonObject["acneRisk"] as? String,
               let explanation = jsonObject["explanation"] as? String {
                return IngredientAnalysis(name: name, acneRisk: acneRisk, explanation: explanation)
            }
            
            throw NSError(domain: "ParseError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not parse single ingredient response: \(cleanedContent)"])
        }
    }
}

// MARK: - ChatGPT API Response Models
struct ChatGPTAPIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - Ingredient Analysis Card
struct IngredientAnalysisCard: View {
    let ingredient: IngredientAnalysis
    let isSelected: Bool
    let onTap: () -> Void
    
    private var riskColor: Color {
        switch ingredient.acneRisk.lowercased() {
        case "low":
            return .green
        case "medium":
            return .orange
        case "high":
            return .red
        case "analyzing":
            return .blue
        default:
            return .gray
        }
    }
    
    private var riskIcon: String {
        switch ingredient.acneRisk.lowercased() {
        case "low":
            return "checkmark.circle.fill"
        case "medium":
            return "exclamationmark.triangle.fill"
        case "high":
            return "xmark.circle.fill"
        case "analyzing":
            return "clock.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator and risk icon
                HStack(spacing: 8) {
                    // Selection checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.system(size: 18, weight: .medium))
                    
                    // Risk icon or loading indicator
                    if ingredient.acneRisk.lowercased() == "analyzing" {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: riskIcon)
                            .foregroundColor(riskColor)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 24, height: 24)
                            .background(riskColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Name and risk badge
                HStack {
                    Text(ingredient.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(ingredient.acneRisk.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(riskColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(riskColor.opacity(0.15))
                        .cornerRadius(8)
                }
                
                // Explanation
                Text(ingredient.explanation)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.3) : riskColor.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
