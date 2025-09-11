import Foundation
import CloudKit
import Combine
import CoreData

/// CloudKit同步服务
/// 负责本地Core Data与iCloud CloudKit之间的数据同步
public class CloudKitSyncService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var syncStatus: SyncStatus = .idle
    @Published public var lastSyncDate: Date?
    @Published public var syncProgress: Double = 0.0
    @Published public var errorMessage: String?
    @Published public var isCloudKitAvailable: Bool = false
    
    // MARK: - Sync Status
    public enum SyncStatus {
        case idle           // 空闲
        case syncing        // 同步中
        case completed      // 同步完成
        case failed         // 同步失败
        case accountUnavailable  // iCloud账户不可用
        
        public var description: String {
            switch self {
            case .idle: return "就绪"
            case .syncing: return "同步中..."
            case .completed: return "同步完成"
            case .failed: return "同步失败"
            case .accountUnavailable: return "iCloud不可用"
            }
        }
    }
    
    // MARK: - Dependencies
    private let container: CKContainer
    private let database: CKDatabase
    private let coreDataStack: CoreDataStack
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let recordZone = CKRecordZone(zoneName: "VoiceBudgetZone")
    private let subscriptionID = "VoiceBudgetSubscription"
    
    // MARK: - Initialization
    public init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
        self.container = CKContainer(identifier: "iCloud.com.voicebudget.app")
        self.database = container.privateCloudDatabase
        
        setupCloudKitAvailability()
        setupNotificationHandlers()
    }
    
    // MARK: - Public Methods
    
    /// 开始完整同步
    public func startSync() {
        guard isCloudKitAvailable else {
            updateSyncStatus(.accountUnavailable, error: "iCloud账户不可用")
            return
        }
        
        guard syncStatus != .syncing else { return }
        
        updateSyncStatus(.syncing)
        
        // 创建同步任务链
        setupCustomZone()
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail(error: SyncError.serviceUnavailable).eraseToAnyPublisher()
                }
                return self.setupSubscription()
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail(error: SyncError.serviceUnavailable).eraseToAnyPublisher()
                }
                return self.syncLocalChangesToCloud()
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail(error: SyncError.serviceUnavailable).eraseToAnyPublisher()
                }
                return self.fetchCloudChanges()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.updateSyncStatus(.completed)
                        self?.lastSyncDate = Date()
                    case .failure(let error):
                        self?.updateSyncStatus(.failed, error: error.localizedDescription)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    /// 手动触发同步
    public func forcSync() {
        lastSyncDate = nil
        startSync()
    }
    
    /// 重置CloudKit数据
    public func resetCloudData() {
        guard isCloudKitAvailable else { return }
        
        updateSyncStatus(.syncing)
        
        // 删除所有云端记录
        deleteAllCloudRecords()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.updateSyncStatus(.completed)
                        self?.startSync()
                    case .failure(let error):
                        self?.updateSyncStatus(.failed, error: error.localizedDescription)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupCloudKitAvailability() {
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    self?.isCloudKitAvailable = true
                case .noAccount, .restricted, .couldNotDetermine:
                    self?.isCloudKitAvailable = false
                    self?.updateSyncStatus(.accountUnavailable, error: "iCloud账户不可用")
                @unknown default:
                    self?.isCloudKitAvailable = false
                }
            }
        }
    }
    
    private func setupNotificationHandlers() {
        // 监听网络变化
        NotificationCenter.default.publisher(for: .init("NetworkReachabilityChanged"))
            .sink { [weak self] _ in
                if self?.isCloudKitAvailable == true {
                    self?.startSync()
                }
            }
            .store(in: &cancellables)
        
        // 监听应用进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                if self?.isCloudKitAvailable == true {
                    self?.startSync()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CloudKit Setup
    
    private func setupCustomZone() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncError.serviceUnavailable))
                return
            }
            
            // 检查区域是否已存在
            let operation = CKFetchRecordZonesOperation(recordZoneIDs: [self.recordZone.zoneID])
            operation.fetchRecordZonesResultBlock = { result in
                switch result {
                case .success(let zones):
                    if zones[self.recordZone.zoneID] != nil {
                        // 区域已存在
                        promise(.success(()))
                    } else {
                        // 创建新区域
                        self.createRecordZone(promise: promise)
                    }
                case .failure:
                    // 创建新区域
                    self.createRecordZone(promise: promise)
                }
            }
            
            self.database.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    private func createRecordZone(promise: @escaping (Result<Void, Error>) -> Void) {
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: nil)
        operation.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                promise(.success(()))
            case .failure(let error):
                promise(.failure(error))
            }
        }
        database.add(operation)
    }
    
    private func setupSubscription() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncError.serviceUnavailable))
                return
            }
            
            // 检查订阅是否已存在
            let operation = CKFetchSubscriptionsOperation(subscriptionIDs: [self.subscriptionID])
            operation.fetchSubscriptionsResultBlock = { result in
                switch result {
                case .success(let subscriptions):
                    if subscriptions[self.subscriptionID] != nil {
                        // 订阅已存在
                        promise(.success(()))
                    } else {
                        // 创建新订阅
                        self.createSubscription(promise: promise)
                    }
                case .failure:
                    // 创建新订阅
                    self.createSubscription(promise: promise)
                }
            }
            
            self.database.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    private func createSubscription(promise: @escaping (Result<Void, Error>) -> Void) {
        let subscription = CKRecordZoneSubscription(zoneID: recordZone.zoneID, subscriptionID: subscriptionID)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                promise(.success(()))
            case .failure(let error):
                promise(.failure(error))
            }
        }
        database.add(operation)
    }
    
    // MARK: - Sync Operations
    
    private func syncLocalChangesToCloud() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncError.serviceUnavailable))
                return
            }
            
            // 获取本地未同步的记录
            self.fetchUnsyncedTransactions { transactions in
                guard !transactions.isEmpty else {
                    promise(.success(()))
                    return
                }
                
                // 转换为CloudKit记录
                let records = transactions.compactMap { self.createCloudKitRecord(from: $0) }
                
                // 上传到CloudKit
                let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success(let savedRecords):
                        // 更新本地同步状态
                        self.markTransactionsAsSynced(Array(savedRecords.keys.compactMap { $0.recordName }))
                        promise(.success(()))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
                
                self.database.add(operation)
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func fetchCloudChanges() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncError.serviceUnavailable))
                return
            }
            
            // 获取服务器更改令牌
            let serverChangeToken = self.getServerChangeToken()
            
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [self.recordZone.zoneID], configurationsByRecordZoneID: [
                self.recordZone.zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                    previousServerChangeToken: serverChangeToken,
                    resultsLimit: nil,
                    desiredKeys: nil
                )
            ])
            
            var changedRecords: [CKRecord] = []
            var deletedRecordIDs: [CKRecord.ID] = []
            
            operation.recordChangedBlock = { record in
                changedRecords.append(record)
            }
            
            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }
            
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success(let zonesToTokens):
                    // 保存新的令牌
                    if let newToken = zonesToTokens[self.recordZone.zoneID] {
                        self.saveServerChangeToken(newToken)
                    }
                    
                    // 处理更改的记录
                    self.processCloudChanges(changed: changedRecords, deleted: deletedRecordIDs)
                    promise(.success(()))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
            
            self.database.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Data Processing
    
    private func createCloudKitRecord(from transaction: Transaction) -> CKRecord? {
        guard let transactionID = transaction.id else { return nil }
        
        let recordID = CKRecord.ID(recordName: transactionID.uuidString, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: "Transaction", recordID: recordID)
        
        record["amount"] = transaction.amount
        record["categoryID"] = transaction.categoryID
        record["categoryName"] = transaction.categoryName
        record["note"] = transaction.note
        record["date"] = transaction.date
        record["source"] = transaction.source
        record["createdAt"] = transaction.createdAt
        record["updatedAt"] = transaction.updatedAt
        record["isDeleted"] = transaction.isDeleted
        
        return record
    }
    
    private func processCloudChanges(changed: [CKRecord], deleted: [CKRecord.ID]) {
        let context = coreDataStack.backgroundContext
        
        context.perform {
            // 处理更新的记录
            for record in changed {
                self.updateLocalTransaction(from: record, in: context)
            }
            
            // 处理删除的记录
            for recordID in deleted {
                self.deleteLocalTransaction(with: recordID.recordName, in: context)
            }
            
            do {
                try context.save()
            } catch {
                print("Failed to save cloud changes: \(error)")
            }
        }
    }
    
    private func updateLocalTransaction(from record: CKRecord, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: record.recordID.recordName) ?? UUID() as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            let transaction = results.first ?? Transaction(context: context)
            
            transaction.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
            transaction.amount = record["amount"] as? NSDecimalNumber
            transaction.categoryID = record["categoryID"] as? String
            transaction.categoryName = record["categoryName"] as? String
            transaction.note = record["note"] as? String
            transaction.date = record["date"] as? Date
            transaction.source = record["source"] as? String
            transaction.createdAt = record["createdAt"] as? Date
            transaction.updatedAt = record["updatedAt"] as? Date
            transaction.isDeleted = record["isDeleted"] as? Bool ?? false
            transaction.syncStatus = "synced"
            
        } catch {
            print("Failed to update local transaction: \(error)")
        }
    }
    
    private func deleteLocalTransaction(with recordName: String, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: recordName) ?? UUID() as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let transaction = results.first {
                context.delete(transaction)
            }
        } catch {
            print("Failed to delete local transaction: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchUnsyncedTransactions(completion: @escaping ([Transaction]) -> Void) {
        let context = coreDataStack.backgroundContext
        
        context.perform {
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "syncStatus != %@ OR syncStatus == nil", "synced")
            
            do {
                let transactions = try context.fetch(request)
                completion(transactions)
            } catch {
                print("Failed to fetch unsynced transactions: \(error)")
                completion([])
            }
        }
    }
    
    private func markTransactionsAsSynced(_ recordNames: [String]) {
        let context = coreDataStack.backgroundContext
        
        context.perform {
            for recordName in recordNames {
                guard let transactionID = UUID(uuidString: recordName) else { continue }
                
                let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", transactionID as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let results = try context.fetch(request)
                    if let transaction = results.first {
                        transaction.syncStatus = "synced"
                    }
                } catch {
                    print("Failed to mark transaction as synced: \(error)")
                }
            }
            
            do {
                try context.save()
            } catch {
                print("Failed to save sync status: \(error)")
            }
        }
    }
    
    private func deleteAllCloudRecords() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncError.serviceUnavailable))
                return
            }
            
            // 获取所有记录ID
            let query = CKQuery(recordType: "Transaction", predicate: NSPredicate(value: true))
            
            self.database.perform(query, inZoneWith: self.recordZone.zoneID) { records, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let records = records else {
                    promise(.success(()))
                    return
                }
                
                let recordIDs = records.map { $0.recordID }
                
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                deleteOperation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        promise(.success(()))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
                
                self.database.add(deleteOperation)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Token Management
    
    private func getServerChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: "ServerChangeToken") else { return nil }
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? CKServerChangeToken
    }
    
    private func saveServerChangeToken(_ token: CKServerChangeToken) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "ServerChangeToken")
        }
    }
    
    // MARK: - Status Updates
    
    private func updateSyncStatus(_ status: SyncStatus, error: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.syncStatus = status
            self?.errorMessage = error
            
            if status == .completed {
                self?.syncProgress = 1.0
            } else if status == .syncing {
                self?.syncProgress = 0.5
            } else {
                self?.syncProgress = 0.0
            }
        }
    }
}

// MARK: - Sync Errors
public enum SyncError: LocalizedError {
    case serviceUnavailable
    case networkUnavailable
    case accountUnavailable
    case quotaExceeded
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "同步服务不可用"
        case .networkUnavailable:
            return "网络不可用"
        case .accountUnavailable:
            return "iCloud账户不可用"
        case .quotaExceeded:
            return "iCloud存储空间不足"
        }
    }
}

// MARK: - Notification Extension
extension CloudKitSyncService {
    
    /// 处理远程通知
    public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else { return }
        
        switch notification {
        case let recordZoneNotification as CKRecordZoneNotification:
            if recordZoneNotification.recordZoneID == recordZone.zoneID {
                // 收到记录区域变更通知，触发同步
                startSync()
            }
        default:
            break
        }
    }
}