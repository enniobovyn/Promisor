//
//  Promise+Cancel.swift
//  Promisor
//
//  Created by Ennio Bovyn on 10/06/2019.
//

public class CancelContext {
    
    private let lockQueue = DispatchQueue(label: "cancel_context-lock_queue")
    
    private var isCancelled = false
    private var cancelHandlers = [() -> ()]()
    
    public func cancel() {
        lockQueue.sync {
            guard !isCancelled else { return }
            
            isCancelled = true
            cancelHandlers.forEach { $0() }
            cancelHandlers.removeAll()
        }
    }
    
    func onCancel(_ cancelHandler: @escaping () -> ()) {
        lockQueue.async {
            if self.isCancelled {
                cancelHandler()
            } else {
                self.cancelHandlers.append(cancelHandler)
            }
        }
    }
    
}

extension Promise {
    
    public func cancel() {
        cancelContext?.cancel()
    }
    
}
