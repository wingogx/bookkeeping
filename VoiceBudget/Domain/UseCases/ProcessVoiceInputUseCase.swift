import Foundation

/// 处理语音输入用例
public class ProcessVoiceInputUseCase {
    
    // MARK: - Dependencies
    
    private let transactionRepository: TransactionRepository
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Initialization
    
    public init(
        transactionRepository: TransactionRepository,
        preferenceRepository: UserPreferenceRepository
    ) {
        self.transactionRepository = transactionRepository
        self.preferenceRepository = preferenceRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let voiceText: String
        public let audioData: Data?
        public let recordingDate: Date
        public let confidence: Float?
        
        public init(
            voiceText: String,
            audioData: Data? = nil,
            recordingDate: Date = Date(),
            confidence: Float? = nil
        ) {
            self.voiceText = voiceText
            self.audioData = audioData
            self.recordingDate = recordingDate
            self.confidence = confidence
        }
    }
    
    public struct Response {
        public let success: Bool
        public let parsedTransaction: ParsedTransaction?
        public let confidence: Float
        public let suggestions: [CategorySuggestion]
        public let needsConfirmation: Bool
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            parsedTransaction: ParsedTransaction? = nil,
            confidence: Float = 0.0,
            suggestions: [CategorySuggestion] = [],
            needsConfirmation: Bool = true,
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.parsedTransaction = parsedTransaction
            self.confidence = confidence
            self.suggestions = suggestions
            self.needsConfirmation = needsConfirmation
            self.error = error
        }
    }
    
    public struct ParsedTransaction {
        public let amount: Decimal
        public let categoryID: String?
        public let categoryName: String?
        public let note: String?
        public let date: Date
        public let extractedKeywords: [String]
        
        public init(
            amount: Decimal,
            categoryID: String? = nil,
            categoryName: String? = nil,
            note: String? = nil,
            date: Date = Date(),
            extractedKeywords: [String] = []
        ) {
            self.amount = amount
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.note = note
            self.date = date
            self.extractedKeywords = extractedKeywords
        }
    }
    
    public struct CategorySuggestion {
        public let categoryID: String
        public let categoryName: String
        public let confidence: Float
        public let matchedKeywords: [String]
        
        public init(categoryID: String, categoryName: String, confidence: Float, matchedKeywords: [String]) {
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.confidence = confidence
            self.matchedKeywords = matchedKeywords
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            // Check if voice recording is enabled
            let voiceEnabled = try await preferenceRepository.getBool(for: .enableVoiceRecording, defaultValue: true)
            guard voiceEnabled else {
                return Response(
                    success: false,
                    error: .invalidInput("语音记账功能已禁用")
                )
            }
            
            // Parse voice text
            let parseResult = parseVoiceText(request.voiceText, recordingDate: request.recordingDate)
            
            guard parseResult.amount > 0 else {
                return Response(
                    success: false,
                    error: .invalidInput("无法从语音中识别出有效金额")
                )
            }
            
            // Get category suggestions
            let suggestions = await getCategorySuggestions(
                text: request.voiceText,
                extractedKeywords: parseResult.extractedKeywords
            )
            
            // Determine best category match
            let bestMatch = suggestions.first
            let parsedTransaction = ParsedTransaction(
                amount: parseResult.amount,
                categoryID: bestMatch?.categoryID,
                categoryName: bestMatch?.categoryName,
                note: parseResult.note,
                date: parseResult.date,
                extractedKeywords: parseResult.extractedKeywords
            )
            
            // Calculate overall confidence
            let overallConfidence = calculateOverallConfidence(
                amountConfidence: parseResult.confidence,
                categoryConfidence: bestMatch?.confidence ?? 0.0,
                voiceConfidence: request.confidence ?? 0.8
            )
            
            // Determine if confirmation is needed
            let needsConfirmation = shouldRequireConfirmation(
                confidence: overallConfidence,
                amount: parseResult.amount,
                hasCategoryMatch: bestMatch != nil
            )
            
            return Response(
                success: true,
                parsedTransaction: parsedTransaction,
                confidence: overallConfidence,
                suggestions: suggestions,
                needsConfirmation: needsConfirmation
            )
            
        } catch {
            return Response(
                success: false,
                error: .unexpected(error.localizedDescription)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func parseVoiceText(_ text: String, recordingDate: Date) -> (amount: Decimal, note: String?, date: Date, extractedKeywords: [String], confidence: Float) {
        
        let normalizedText = text.lowercased()
        var extractedKeywords: [String] = []
        
        // Extract amount using regex patterns
        let amount = extractAmount(from: normalizedText, keywords: &extractedKeywords)
        
        // Extract note (remove amount-related words)
        let note = extractNote(from: text, amount: amount)
        
        // Extract date (default to recording date)
        let date = extractDate(from: normalizedText) ?? recordingDate
        
        // Calculate parsing confidence based on patterns found
        let confidence = calculateParsingConfidence(text: normalizedText, extractedAmount: amount)
        
        return (amount, note, date, extractedKeywords, confidence)
    }
    
    private func extractAmount(from text: String, keywords: inout [String]) -> Decimal {
        // Chinese number conversion
        let chineseNumbers = [
            "零": "0", "一": "1", "二": "2", "三": "3", "四": "4",
            "五": "5", "六": "6", "七": "7", "八": "8", "九": "9",
            "十": "10", "百": "100", "千": "1000",
            "两": "2", "俩": "2"
        ]
        
        var processedText = text
        for (chinese, arabic) in chineseNumbers {
            processedText = processedText.replacingOccurrences(of: chinese, with: arabic)
        }
        
        // Common patterns for amounts
        let patterns = [
            "(?:花了|用了|花费|消费|支付|付了|买了).*?(\\d+(?:\\.\\d+)?)(?:元|块|毛|分)?",
            "(\\d+(?:\\.\\d+)?)(?:元|块|毛|分)",
            "(?:总共|一共|合计).*?(\\d+(?:\\.\\d+)?)",
            "(\\d+(?:\\.\\d+)?)(?:块钱|元钱)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: processedText.utf16.count)
                if let match = regex.firstMatch(in: processedText, options: [], range: range) {
                    let matchRange = match.range(at: 1)
                    if matchRange.location != NSNotFound,
                       let swiftRange = Range(matchRange, in: processedText) {
                        let amountString = String(processedText[swiftRange])
                        keywords.append("amount_pattern")
                        return Decimal(string: amountString) ?? 0
                    }
                }
            }
        }
        
        return 0
    }
    
    private func extractNote(from text: String, amount: Decimal) -> String? {
        var cleanedText = text
        
        // Remove amount-related phrases
        let amountPatterns = [
            "\\d+(?:\\.\\d+)?(?:元|块|毛|分|块钱|元钱)",
            "花了|用了|花费|消费|支付|付了|买了|总共|一共|合计"
        ]
        
        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: cleanedText.utf16.count)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            }
        }
        
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText.isEmpty ? nil : cleanedText
    }
    
    private func extractDate(from text: String) -> Date? {
        // Simple date extraction - could be enhanced
        if text.contains("今天") {
            return Date()
        } else if text.contains("昨天") {
            return Calendar.current.date(byAdding: .day, value: -1, to: Date())
        } else if text.contains("前天") {
            return Calendar.current.date(byAdding: .day, value: -2, to: Date())
        }
        
        return nil
    }
    
    private func calculateParsingConfidence(text: String, extractedAmount: Decimal) -> Float {
        var confidence: Float = 0.0
        
        // Base confidence from amount extraction
        if extractedAmount > 0 {
            confidence += 0.4
        }
        
        // Confidence boost for clear spending indicators
        let spendingIndicators = ["花了", "用了", "买了", "花费", "消费", "支付"]
        for indicator in spendingIndicators {
            if text.contains(indicator) {
                confidence += 0.2
                break
            }
        }
        
        // Confidence boost for currency indicators
        let currencyIndicators = ["元", "块", "毛", "分", "块钱", "元钱"]
        for indicator in currencyIndicators {
            if text.contains(indicator) {
                confidence += 0.2
                break
            }
        }
        
        // Confidence reduction for vague amounts
        if extractedAmount < 1 {
            confidence -= 0.3
        } else if extractedAmount > 10000 {
            confidence -= 0.1
        }
        
        return min(max(confidence, 0.0), 1.0)
    }
    
    private func getCategorySuggestions(text: String, extractedKeywords: [String]) async -> [CategorySuggestion] {
        
        // Get enabled categories based on user preferences
        let enabledMode = try? await preferenceRepository.getString(for: .enabledCategoryMode, defaultValue: "beginner")
        
        let categories: [CategoryEntity]
        switch enabledMode {
        case "advanced":
            categories = CategoryEntity.advancedCategories
        case "beginner":
            categories = CategoryEntity.beginnerCategories
        default:
            categories = CategoryEntity.beginnerCategories
        }
        
        // Score each category based on text matching
        var suggestions: [CategorySuggestion] = []
        
        for category in categories {
            let matchingScore = category.matchingScore(for: text)
            if matchingScore > 0 {
                let matchedKeywords = category.keywords.filter { keyword in
                    text.lowercased().contains(keyword.lowercased())
                }
                
                suggestions.append(CategorySuggestion(
                    categoryID: category.id,
                    categoryName: category.name,
                    confidence: Float(matchingScore),
                    matchedKeywords: matchedKeywords
                ))
            }
        }
        
        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }
        
        return Array(suggestions.prefix(3)) // Return top 3 suggestions
    }
    
    private func calculateOverallConfidence(
        amountConfidence: Float,
        categoryConfidence: Float,
        voiceConfidence: Float
    ) -> Float {
        // Weighted average
        let weights: (amount: Float, category: Float, voice: Float) = (0.4, 0.3, 0.3)
        
        return (amountConfidence * weights.amount) +
               (categoryConfidence * weights.category) +
               (voiceConfidence * weights.voice)
    }
    
    private func shouldRequireConfirmation(
        confidence: Float,
        amount: Decimal,
        hasCategoryMatch: Bool
    ) -> Bool {
        // Require confirmation if confidence is low
        if confidence < 0.6 {
            return true
        }
        
        // Require confirmation for large amounts
        if amount > 1000 {
            return true
        }
        
        // Require confirmation if no category match
        if !hasCategoryMatch {
            return true
        }
        
        // High confidence transactions can be auto-saved
        return confidence < 0.8
    }
}