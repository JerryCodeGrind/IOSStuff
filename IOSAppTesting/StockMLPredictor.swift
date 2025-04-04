//
//  StockMLPredictor.swift
//  IOSAppTesting
//
//  Created by Jerry Huang on 2025-02-01.
//

import CoreML
import Foundation

class StockMLPredictor {
    private var model: MLModel?
    
    init() {
        do {
            // Replace "StockPredictor" with your actual model name
            if let modelURL = Bundle.main.url(forResource: "StockPredictor", withExtension: "mlmodel") {
                model = try MLModel(contentsOf: modelURL)
            }
        } catch {
            print("Error loading ML model: \(error)")
        }
    }
    
    func predictVolatility(for stock: Stock) -> Double? {
        // Implementation depends on your specific model
        // This is just an example structure
        guard let model = model else { return nil }
        
        do {
            // Create feature provider based on your model's inputs
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "price": stock.price as NSNumber,
                "marketCap": stock.marketCap as NSNumber,
                "peRatio": stock.peRatio as NSNumber
            ])
            
            // Make prediction
            let prediction = try model.prediction(from: input)
            
            // Extract result based on your model's output feature name
            return (prediction.featureValue(for: "volatilityPrediction")?.doubleValue)
            
        } catch {
            print("Prediction error: \(error)")
            return nil
        }
    }
}
