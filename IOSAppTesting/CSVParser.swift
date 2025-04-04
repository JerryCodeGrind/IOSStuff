//
//  CSVParser.swift
//  IOSAppTesting
//
//  Created by Jerry Huang on 2025-02-01.
//

import Foundation

enum CSVParserError: Error {
    case fileNotFound
    case invalidFormat
    case invalidNumberFormat
}

class CSVParser {
    static func parse(filename: String) throws -> [[String]] {
        guard let path = Bundle.main.path(forResource: filename, ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw CSVParserError.fileNotFound
        }
        
        // Split into rows and handle quoted values correctly
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        for char in content {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    currentValue.append(char)
                } else {
                    currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
                    currentValue = ""
                }
            case "\n", "\r":
                if !insideQuotes {
                    if !currentValue.isEmpty {
                        currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
                        currentValue = ""
                    }
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                        currentRow = []
                    }
                } else {
                    currentValue.append(char)
                }
            default:
                currentValue.append(char)
            }
        }
        
        // Add the last row if needed
        if !currentValue.isEmpty {
            currentRow.append(currentValue.trimmingCharacters(in: .whitespaces))
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
} 
