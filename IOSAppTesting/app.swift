import Foundation

// MARK: - Error Types
enum StockError: Error {
    case invalidData(String)
    case processingError(String)
    case networkError(String)
}

// MARK: - Data Structures
struct Stock {
    let ticker: String
    let price: Double
    let marketCap: Double
    let peRatio: Double
    let sector: String
    let volatility: Double
    let volatilityCategory: String
    let summary: String
    
    init(ticker: String, price: Double, marketCap: Double, peRatio: Double,
         sector: String, volatility: Double, volatilityCategory: String, summary: String) throws {
        // Validate inputs
        guard !ticker.isEmpty else {
            throw StockError.invalidData("Ticker cannot be empty")
        }
        guard price >= 0 else {
            throw StockError.invalidData("Price must be non-negative")
        }
        guard marketCap >= 0 else {
            throw StockError.invalidData("Market cap must be non-negative")
        }
        guard !sector.isEmpty else {
            throw StockError.invalidData("Sector cannot be empty")
        }
        
        self.ticker = ticker
        self.price = price
        self.marketCap = marketCap
        self.peRatio = peRatio
        self.sector = sector
        self.volatility = volatility
        self.volatilityCategory = volatilityCategory
        self.summary = summary
    }
}

// MARK: - Data Loading
class DataLoader {
    static func loadStockData() throws -> [Stock] {
        let rows = try CSVParser.parse(filename: "sp500")
        guard rows.count > 1 else { return [] }
        
        // Assuming first row is headers
        let headers = rows[0]
        let dataRows = Array(rows.dropFirst())
        
        return try dataRows.compactMap { row -> Stock? in
            guard row.count == headers.count else { return nil }
            
            // Create a dictionary of column names to values
            let dict = Dictionary(uniqueKeysWithValues: zip(headers, row))
            
            return try Stock(
                ticker: dict["ticker"] ?? "",
                price: try parseDouble(dict["price"], fieldName: "price"),
                marketCap: try parseDouble(dict["market_cap"], fieldName: "market cap"),
                peRatio: try parseDouble(dict["pe_ratio"], fieldName: "PE ratio"),
                sector: dict["sector"] ?? "",
                volatility: try parseDouble(dict["volatility"], fieldName: "volatility"),
                volatilityCategory: dict["volatility_category"] ?? "",
                summary: dict["Summary"] ?? ""
            )
        }
    }
    
    static func loadStockDataAsync() async throws -> [Stock] {
        // Simulate network request or heavy computation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let stocks = try loadStockData()
                    continuation.resume(returning: stocks)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private static func parseDouble(_ value: String?, fieldName: String) throws -> Double {
        guard let value = value,
              let number = Double(value.trimmingCharacters(in: .whitespaces)) else {
            throw CSVParserError.invalidNumberFormat
        }
        return number
    }
    
    static func prepareTextFeatures(stocks: [Stock]) -> [[Double]] {
        let embedder = TextEmbedding()
        return stocks.map { stock in
            embedder.getEmbedding(for: stock.summary)
        }
    }
}

// MARK: - Feature Engineering
class FeatureEngineering {
    static func normalizeFeatures(_ values: [[Double]]) -> [[Double]] {
        guard !values.isEmpty else { return [] }
        
        let columns = values[0].count
        var normalized = Array(repeating: Array(repeating: 0.0, count: columns), count: values.count)
        
        for col in 0..<columns {
            let column = values.map { $0[col] }
            let minVal = column.min() ?? 0
            let maxVal = column.max() ?? 1
            let range = maxVal - minVal
            
            for row in 0..<values.count {
                normalized[row][col] = range != 0 ? (values[row][col] - minVal) / range : 0
            }
        }
        
        return normalized
    }
    
    static func oneHotEncode(sectors: [String]) -> ([[Double]], [String]) {
        let uniqueSectors = Array(Set(sectors)).sorted()
        var encoded = Array(repeating: Array(repeating: 0.0, count: uniqueSectors.count), count: sectors.count)
        
        for (i, sector) in sectors.enumerated() {
            if let index = uniqueSectors.firstIndex(of: sector) {
                encoded[i][index] = 1.0
            }
        }
        
        let featureNames = uniqueSectors.map { "Sector_\($0)" }
        return (encoded, featureNames)
    }
    
    static func vectorizeSummaries(_ summaries: [String]) -> [[Double]] {
        let embedder = TextEmbedding()
        return summaries.map { summary in
            embedder.getEmbedding(for: summary)
        }
    }
}

// MARK: - Stock Recommender
class StockRecommender {
    private let stocks: [Stock]
    private var features: [[Double]]
    private let featureNames: [String]
    private var featureWeights: [Double]
    private let maxSwipes: Int
    private var swipeCount: Int = 0
    
    init(stocks: [Stock], features: [[Double]], featureNames: [String], maxSwipes: Int = 10) {
        self.stocks = stocks
        self.features = features
        self.featureNames = featureNames
        self.featureWeights = Array(repeating: 0.0, count: features[0].count)
        self.maxSwipes = maxSwipes
    }
    
    func displayRecommendation(for index: Int, scores: [Double]) {
        let stock = stocks[index]
        print("\n=== Stock Recommendation \(swipeCount + 1)/\(maxSwipes) ===")
        print("Ticker: \(stock.ticker)")
        print("Price: $\(String(format: "%.2f", stock.price))")
        print("Sector: \(stock.sector)")
        print("Market Cap: $\(String(format: "%.2fB", stock.marketCap / 1e9))")
        print("P/E Ratio: \(String(format: "%.2f", stock.peRatio))")
        print("Volatility: \(stock.volatilityCategory)")
    }
    
    func calculateScores() -> [Double] {
        var scores = Array(repeating: 0.0, count: features.count)
        for i in 0..<features.count {
            scores[i] = zip(features[i], featureWeights).map(*).reduce(0, +)
        }
        return scores
    }
    
    func runRecommendationLoop() {
        var currentFeatures = features
        var currentStocks = stocks
        
        while swipeCount < maxSwipes && !currentStocks.isEmpty {
            let scores = calculateScores()
            guard let recommendedIdx = scores.indices.max(by: { scores[$0] < scores[$1] }) else { break }
            
            displayRecommendation(for: recommendedIdx, scores: scores)
            print("Do you like this stock? (y/n): ", terminator: "")
            
            if let feedback = readLine()?.lowercased() {
                switch feedback {
                case "y":
                    featureWeights = zip(featureWeights, currentFeatures[recommendedIdx])
                        .map { $0 + $1 }
                case "n":
                    featureWeights = zip(featureWeights, currentFeatures[recommendedIdx])
                        .map { $0 - $1 }
                default:
                    print("Invalid input. Skipping this recommendation.")
                }
            }
            
            currentFeatures.remove(at: recommendedIdx)
            currentStocks.remove(at: recommendedIdx)
            swipeCount += 1
        }
        
        displayFinalRecommendations(stocks: currentStocks, features: currentFeatures)
    }
    
    private func displayFinalRecommendations(stocks: [Stock], features: [[Double]]) {
        guard !stocks.isEmpty else {
            print("\nNo more stocks to recommend.")
            return
        }
        
        let scores = calculateScores()
        let numRecommendations = min(5, stocks.count)
        let topIndices = scores.indices.sorted { scores[$0] > scores[$1] }.prefix(numRecommendations)
        
        print("\n=== Top Stock Recommendations Based on Your Preferences ===")
        for idx in topIndices {
            let stock = stocks[idx]
            print("\nTicker: \(stock.ticker)")
            print("Price: $\(String(format: "%.2f", stock.price))")
            print("Sector: \(stock.sector)")
            print("Market Cap: $\(String(format: "%.2fB", stock.marketCap / 1e9))")
            print("P/E Ratio: \(String(format: "%.2f", stock.peRatio))")
            print("Volatility: \(stock.volatilityCategory)")
        }
    }
    
    func updatePreferences(for stock: Stock, liked: Bool) {
        // Update feature weights based on user preference
        guard let stockIndex = stocks.firstIndex(where: { $0.ticker == stock.ticker }) else { return }
        let multiplier = liked ? 1.0 : -1.0
        
        for (i, weight) in featureWeights.enumerated() {
            featureWeights[i] = weight + (features[stockIndex][i] * multiplier)
        }
    }
    
    func getTopRecommendations(count: Int) -> [Stock] {
        // Calculate scores for all stocks
        let scores = calculateScores()
        
        // Get indices of top scoring stocks
        let topIndices = scores.indices.sorted { scores[$0] > scores[$1] }.prefix(count)
        
        // Return top stocks
        return topIndices.map { stocks[$0] }
    }
}

// MARK: - Main Execution
func runApp() async throws {
    let stocks = try await DataLoader.loadStockDataAsync()
    
    // Prepare numerical features
    let numericalFeatures = stocks.map { [
        $0.volatility,
        $0.marketCap,
        $0.peRatio,
        $0.price
    ] }
    let numericalFeaturesScaled = FeatureEngineering.normalizeFeatures(numericalFeatures)
    
    // Prepare categorical features
    let (categoricalEncoded, categoricalFeatureNames) = FeatureEngineering.oneHotEncode(
        sectors: stocks.map { $0.sector }
    )
    
    // Add summary vectorization
    let summaryFeatures = FeatureEngineering.vectorizeSummaries(stocks.map { $0.summary })
    let summaryFeaturesScaled = FeatureEngineering.normalizeFeatures(summaryFeatures)
    
    // Combine all features with weights
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
    
    // Run recommendation system
    let recommender = StockRecommender(
        stocks: stocks,
        features: features,
        featureNames: featureNames
    )
    recommender.runRecommendationLoop()
}
