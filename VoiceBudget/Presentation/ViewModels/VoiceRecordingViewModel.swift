import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class VoiceRecordingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let voiceRecognitionService = VoiceRecognitionService()
    private let processVoiceInputUseCase: ProcessVoiceInputUseCase
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var parsedTransaction: ProcessVoiceInputUseCase.ParsedTransaction?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        let coreDataStack = CoreDataStack.shared
        let transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        let preferenceRepository = UserDefaultsPreferenceRepository()
        
        self.processVoiceInputUseCase = ProcessVoiceInputUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        
        setupVoiceRecognition()
    }
    
    // MARK: - Public Methods
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func confirmTransaction() {
        guard let parsed = parsedTransaction else { return }
        
        // TODO: 实际创建交易记录
        showConfirmation = false
        resetState()
    }
    
    func cancelTransaction() {
        showConfirmation = false
        resetState()
    }
    
    // MARK: - Private Methods
    
    private func setupVoiceRecognition() {
        voiceRecognitionService.recognizedTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.recognizedText = text
            }
            .store(in: &cancellables)
        
        voiceRecognitionService.recordingStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
                if !isRecording && !self?.recognizedText.isEmpty == true {
                    self?.processVoiceInput()
                }
            }
            .store(in: &cancellables)
        
        voiceRecognitionService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error?.localizedDescription
                self?.isRecording = false
            }
            .store(in: &cancellables)
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        
        resetState()
        voiceRecognitionService.startRecording()
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        voiceRecognitionService.stopRecording()
    }
    
    private func processVoiceInput() {
        guard !recognizedText.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let request = ProcessVoiceInputUseCase.Request(voiceText: recognizedText)
                let response = try await processVoiceInputUseCase.execute(request)
                
                await MainActor.run {
                    isProcessing = false
                    
                    if response.success, let parsed = response.parsedTransaction {
                        parsedTransaction = parsed
                        if response.needsConfirmation {
                            showConfirmation = true
                        } else {
                            confirmTransaction()
                        }
                    } else {
                        errorMessage = response.error?.localizedDescription ?? "语音识别处理失败"
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func resetState() {
        recognizedText = ""
        parsedTransaction = nil
        errorMessage = nil
        isProcessing = false
        showConfirmation = false
    }
}