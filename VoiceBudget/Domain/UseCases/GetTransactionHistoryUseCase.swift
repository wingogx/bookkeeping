import Foundation

/// 获取交易历史记录用例
public class GetTransactionHistoryUseCase {
    
    // MARK: - Dependencies
    
    private let transactionRepository: TransactionRepository
    
    // MARK: - Initialization
    
    public init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let startDate: Date?
        public let endDate: Date?
        public let categoryID: String?
        public let searchText: String?
        public let source: TransactionEntity.TransactionSource?
        public let limit: Int?
        public let offset: Int
        public let sortOrder: SortOrder
        
        public init(
            startDate: Date? = nil,
            endDate: Date? = nil,
            categoryID: String? = nil,
            searchText: String? = nil,
            source: TransactionEntity.TransactionSource? = nil,
            limit: Int? = nil,
            offset: Int = 0,
            sortOrder: SortOrder = .dateDescending
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.categoryID = categoryID
            self.searchText = searchText
            self.source = source
            self.limit = limit
            self.offset = offset
            self.sortOrder = sortOrder
        }
    }
    
    public enum SortOrder {
        case dateAscending
        case dateDescending
        case amountAscending
        case amountDescending
    }
    
    public struct Response {
        public let success: Bool
        public let transactions: [TransactionEntity]
        public let totalCount: Int
        public let hasMore: Bool
        public let summary: TransactionSummary?
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            transactions: [TransactionEntity] = [],
            totalCount: Int = 0,
            hasMore: Bool = false,
            summary: TransactionSummary? = nil,
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.transactions = transactions
            self.totalCount = totalCount
            self.hasMore = hasMore
            self.summary = summary
            self.error = error
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            var transactions: [TransactionEntity] = []
            
            // Handle search vs regular fetch
            if let searchText = request.searchText, !searchText.isEmpty {
                transactions = try await transactionRepository.searchTransactions(
                    searchText: searchText,
                    limit: request.limit ?? 50
                )
            } else {
                transactions = try await transactionRepository.fetchTransactions(
                    startDate: request.startDate,
                    endDate: request.endDate,
                    categoryID: request.categoryID,
                    source: request.source,
                    limit: request.limit,
                    offset: request.offset
                )
            }
            
            // Apply sorting if needed
            transactions = sortTransactions(transactions, by: request.sortOrder)
            
            // Calculate summary if date range is specified
            var summary: TransactionSummary?
            if let startDate = request.startDate, let endDate = request.endDate {
                summary = try await transactionRepository.getTransactionSummary(
                    startDate: startDate,
                    endDate: endDate,
                    categoryID: request.categoryID
                )
            }
            
            // Calculate pagination info
            let hasMore = calculateHasMore(
                transactions: transactions,
                limit: request.limit,
                offset: request.offset
            )
            
            // Get total count for pagination
            let totalCount = try await getTotalCount(for: request)
            
            return Response(
                success: true,
                transactions: transactions,
                totalCount: totalCount,
                hasMore: hasMore,
                summary: summary
            )
            
        } catch {
            let useCaseError: UseCaseError
            
            if let repoError = error as? RepositoryError {
                useCaseError = .repositoryError(repoError.localizedDescription)
            } else {
                useCaseError = .unexpected(error.localizedDescription)
            }
            
            return Response(success: false, error: useCaseError)
        }
    }
    
    // MARK: - Private Methods
    
    private func sortTransactions(_ transactions: [TransactionEntity], by order: SortOrder) -> [TransactionEntity] {
        switch order {
        case .dateAscending:
            return transactions.sorted { $0.date < $1.date }
        case .dateDescending:
            return transactions.sorted { $0.date > $1.date }
        case .amountAscending:
            return transactions.sorted { $0.amount < $1.amount }
        case .amountDescending:
            return transactions.sorted { $0.amount > $1.amount }
        }
    }
    
    private func calculateHasMore(transactions: [TransactionEntity], limit: Int?, offset: Int) -> Bool {
        guard let limit = limit else { return false }
        return transactions.count == limit
    }
    
    private func getTotalCount(for request: Request) async throws -> Int {
        if request.searchText != nil || request.categoryID != nil || 
           request.startDate != nil || request.endDate != nil || request.source != nil {
            // For filtered queries, we need to count matching records
            // This is a simplified approach - in production, you might want a dedicated count query
            let allMatching = try await transactionRepository.fetchTransactions(
                startDate: request.startDate,
                endDate: request.endDate,
                categoryID: request.categoryID,
                source: request.source,
                limit: nil,
                offset: 0
            )
            return allMatching.count
        } else {
            // For unfiltered queries, get total transaction count
            return try await transactionRepository.getTotalTransactionCount()
        }
    }
}