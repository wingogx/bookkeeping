import Foundation
import Combine

@MainActor
class TransactionListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var transactions: [TransactionEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: TransactionCategory?
    @Published var selectedDateRange: DateRange = .all
    @Published var editingTransaction: TransactionEntity?
    
    // MARK: - Dependencies
    private let getTransactionHistoryUseCase: GetTransactionHistoryUseCase
    private let deleteTransactionUseCase: DeleteTransactionUseCase
    private let updateTransactionUseCase: UpdateTransactionUseCase
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        getTransactionHistoryUseCase: GetTransactionHistoryUseCase = DIContainer.shared.resolve(),
        deleteTransactionUseCase: DeleteTransactionUseCase = DIContainer.shared.resolve(),
        updateTransactionUseCase: UpdateTransactionUseCase = DIContainer.shared.resolve()
    ) {
        self.getTransactionHistoryUseCase = getTransactionHistoryUseCase
        self.deleteTransactionUseCase = deleteTransactionUseCase
        self.updateTransactionUseCase = updateTransactionUseCase
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (startDate, endDate) = getDateRange()
            
            transactions = try await getTransactionHistoryUseCase.execute(
                startDate: startDate,
                endDate: endDate,
                category: selectedCategory,
                limit: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteTransaction(_ transaction: TransactionEntity) {
        Task {
            do {
                try await deleteTransactionUseCase.execute(transactionId: transaction.id)
                await loadTransactions()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func editTransaction(_ transaction: TransactionEntity) {
        editingTransaction = transaction
    }
    
    func updateTransaction(_ transaction: TransactionEntity) {
        Task {
            do {
                try await updateTransactionUseCase.execute(transaction: transaction)
                await loadTransactions()
                editingTransaction = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // 当筛选条件改变时，重新加载数据
        Publishers.CombineLatest($selectedCategory, $selectedDateRange)
            .dropFirst() // 忽略初始值
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task { [weak self] in
                    await self?.loadTransactions()
                }
            }
            .store(in: &cancellables)
    }
    
    private func getDateRange() -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedDateRange {
        case .all:
            return (nil, nil)
            
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            return (startOfDay, endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek ?? now)
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth ?? now)
            return (startOfMonth, endOfMonth)
            
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start
            let endOfLastMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth ?? now)
            return (startOfLastMonth, endOfLastMonth)
            
        case .custom:
            // 自定义日期范围需要额外的UI支持
            return (nil, nil)
        }
    }
}

// MARK: - Additional Use Cases (需要实现)
protocol DeleteTransactionUseCase {
    func execute(transactionId: UUID) async throws
}

protocol UpdateTransactionUseCase {
    func execute(transaction: TransactionEntity) async throws
}

class DeleteTransactionUseCaseImpl: DeleteTransactionUseCase {
    private let transactionRepository: TransactionRepository
    
    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
    }
    
    func execute(transactionId: UUID) async throws {
        try await transactionRepository.delete(transactionId: transactionId)
    }
}

class UpdateTransactionUseCaseImpl: UpdateTransactionUseCase {
    private let transactionRepository: TransactionRepository
    
    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
    }
    
    func execute(transaction: TransactionEntity) async throws {
        try await transactionRepository.update(transaction: transaction)
    }
}

// MARK: - Simple Dependency Injection Container
class DIContainer {
    static let shared = DIContainer()
    private var services: [String: Any] = [:]
    
    private init() {
        // 注册默认实现
        register(GetTransactionHistoryUseCase(transactionRepository: CoreDataTransactionRepository()))
        register(DeleteTransactionUseCaseImpl(transactionRepository: CoreDataTransactionRepository()) as DeleteTransactionUseCase)
        register(UpdateTransactionUseCaseImpl(transactionRepository: CoreDataTransactionRepository()) as UpdateTransactionUseCase)
    }
    
    func register<T>(_ service: T) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    func resolve<T>() -> T {
        let key = String(describing: T.self)
        return services[key] as! T
    }
}