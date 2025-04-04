//
//  ContentView.swift
//  IOSAppTesting
//
//  Created by Jerry Huang on 2025-02-01.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StockViewModel()
    @State private var dragOffset: CGSize = .zero
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "2E3192"), Color(hex: "1BFFFF")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.showingRecommendations {
                    RecommendationsView(recommendations: viewModel.recommendations)
                        .transition(.move(edge: .trailing))
                } else {
                    SwipingView(
                        currentStock: viewModel.currentStock,
                        swipeCount: viewModel.swipeCount,
                        dragOffset: $dragOffset,
                        onSwipe: handleSwipe
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.showingRecommendations ? "Your Matches" : "StockMatch")
                        .font(.custom("Avenir-Heavy", size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await viewModel.loadStocks()
        }
    }
    
    private func handleSwipe(_ gesture: DragGesture.Value) {
        if gesture.translation.width < -100 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.dislikeStock()
                dragOffset = .zero
            }
        } else if gesture.translation.width > 100 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.likeStock()
                dragOffset = .zero
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
        }
    }
}

// Loading View with animation
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 70))
                .foregroundColor(.white)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            Text("Loading stocks...")
                .font(.custom("Avenir-Medium", size: 18))
                .foregroundColor(.white)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Recommendations View
struct RecommendationsView: View {
    let recommendations: [Stock]
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Your Top Matches")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.white)
                    .padding()
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                ForEach(Array(recommendations.enumerated()), id: \.element.ticker) { index, stock in
                    StockCardView(stock: stock)
                        .padding(.horizontal)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 50)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: appearAnimation
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }
}

// Enhanced Stock Card View
struct StockCardView: View {
    let stock: Stock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stock.ticker)
                    .font(.custom("Avenir-Black", size: 28))
                    .foregroundColor(Color(hex: "2E3192"))
                
                Spacer()
                
                Text(stock.sector)
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            StockInfoRow(title: "Price", value: "$\(String(format: "%.2f", stock.price))")
            StockInfoRow(title: "Market Cap", value: "$\(String(format: "%.2fB", stock.marketCap / 1e9))")
            StockInfoRow(title: "P/E Ratio", value: String(format: "%.2f", stock.peRatio))
            
            HStack {
                Text("Volatility")
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.gray)
                
                Text(stock.volatilityCategory)
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(volatilityColor(stock.volatilityCategory))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(volatilityColor(stock.volatilityCategory).opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(stock.summary)
                .font(.custom("Avenir-Book", size: 15))
                .foregroundColor(.gray)
                .lineLimit(3)
                .padding(.top, 5)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func volatilityColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .gray
        }
    }
}

// Helper Views
struct StockInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.custom("Avenir-Heavy", size: 16))
                .foregroundColor(Color(hex: "2E3192"))
        }
    }
}

// Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@MainActor
class StockViewModel: ObservableObject {
    @Published var currentStock: Stock?
    @Published var isLoading = false
    @Published var showingRecommendations = false
    @Published var recommendations: [Stock] = []
    @Published var swipeCount = 0
    
    private var recommender: StockRecommender?
    private var stocks: [Stock] = []
    private var currentIndex = 0
    private let maxSwipes = 10
    
    func loadStocks() async {
        isLoading = true
        
        do {
            let stocks = try await DataLoader.loadStockDataAsync()
            
            // Prepare features (same as before)
            let numericalFeatures = stocks.map { [
                $0.volatility,
                $0.marketCap,
                $0.peRatio,
                $0.price
            ] }
            let numericalFeaturesScaled = FeatureEngineering.normalizeFeatures(numericalFeatures)
            
            let (categoricalEncoded, categoricalFeatureNames) = FeatureEngineering.oneHotEncode(
                sectors: stocks.map { $0.sector }
            )
            
            let summaryFeatures = FeatureEngineering.vectorizeSummaries(stocks.map { $0.summary })
            let summaryFeaturesScaled = FeatureEngineering.normalizeFeatures(summaryFeatures)
            
            let features = zip(zip(numericalFeaturesScaled, categoricalEncoded), summaryFeaturesScaled).map { args, summary in
                let (numerical, categorical) = args
                return numerical.map { $0 * 1.0 } +
                       categorical.map { $0 * 0.8 } +
                       summary.map { $0 * 0.5 }
            }
            
            let summaryFeatureNames = (0..<summaryFeatures[0].count).map { "Summary_\($0)" }
            let featureNames = ["Volatility", "Market Cap", "P/E Ratio", "Price"] +
                             categoricalFeatureNames +
                             summaryFeatureNames
            
            self.stocks = stocks
            self.recommender = StockRecommender(
                stocks: stocks,
                features: features,
                featureNames: featureNames
            )
            self.currentStock = stocks.first
            self.isLoading = false
            
        } catch {
            print("Error loading stocks: \(error)")
            self.isLoading = false
        }
    }
    
    func likeStock() {
        guard let stock = currentStock else { return }
        recommender?.updatePreferences(for: stock, liked: true)
        handleSwipe()
    }
    
    func dislikeStock() {
        guard let stock = currentStock else { return }
        recommender?.updatePreferences(for: stock, liked: false)
        handleSwipe()
    }
    
    private func handleSwipe() {
        swipeCount += 1
        if swipeCount >= maxSwipes {
            // Generate final recommendations
            if let topStocks = recommender?.getTopRecommendations(count: 5) {
                recommendations = topStocks
                showingRecommendations = true
                currentStock = nil
            }
        } else {
            moveToNextStock()
        }
    }
    
    private func moveToNextStock() {
        currentIndex += 1
        if currentIndex < stocks.count {
            currentStock = stocks[currentIndex]
        } else {
            currentStock = nil
        }
    }
}

struct SwipingView: View {
    let currentStock: Stock?
    let swipeCount: Int
    @Binding var dragOffset: CGSize
    let onSwipe: (DragGesture.Value) -> Void
    
    var body: some View {
        VStack {
            if let stock = currentStock {
                Text("\(swipeCount)/10")
                    .font(.custom("Avenir-Medium", size: 18))
                    .foregroundColor(.white)
                    .padding(.top)
                
                StockCardView(stock: stock)
                    .padding(.horizontal)
                    .offset(dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                withAnimation(.spring()) {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                onSwipe(gesture)
                            }
                    )
                    .rotation3DEffect(
                        .degrees(Double(dragOffset.width / 20)),
                        axis: (x: 0, y: 0, z: 1)
                    )
                
                HStack(spacing: 40) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .opacity(dragOffset.width < 0 ? -Double(dragOffset.width) / 100 : 0)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .opacity(dragOffset.width > 0 ? Double(dragOffset.width) / 100 : 0)
                }
                .padding(.top, 30)
            }
        }
    }
}
