//
//  TextEmbedding.swift
//  IOSAppTesting
//
//  Created by Jerry Huang on 2025-02-01.
//

import Foundation
import NaturalLanguage

class TextEmbedding {
    private let embedder: NLEmbedding?
    private let embeddingDimension: Int = 300  // Standard dimension for word embeddings
    
    init() {
        // Use Apple's built-in word embedding model
        self.embedder = NLEmbedding.wordEmbedding(for: .english)
    }
    
    func getEmbedding(for text: String) -> [Double] {
        guard let embedder = embedder else {
            return Array(repeating: 0.0, count: embeddingDimension)
        }
        
        // Preprocess text
        let processedText = text.lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
        
        // Split into words and get embeddings
        let words = processedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var embeddings: [[Double]] = []
        
        for word in words {
            if let vector = embedder.vector(for: word) {
                embeddings.append(vector.map { Double($0) })
            }
        }
        
        // If no embeddings were found, return zero vector
        guard !embeddings.isEmpty else {
            return Array(repeating: 0.0, count: embeddingDimension)
        }
        
        // Average the word embeddings
        let summed = embeddings.reduce(into: Array(repeating: 0.0, count: embeddingDimension)) { result, vector in
            for (i, value) in vector.enumerated() {
                result[i] += value
            }
        }
        
        return summed.map { $0 / Double(embeddings.count) }
    }
}
