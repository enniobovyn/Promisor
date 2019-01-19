//
//  PromiseState.swift
//  Promisor
//
//  Created by Ennio Bovyn on 19/01/2019.
//

enum PromiseState<Value> {

    /// Initial state, neither fulfilled nor rejected.
    case pending
    
    /// Meaning that the operation completed successfully.
    case fulfilled(value: Value)
    
    /// Meaning that the operation failed.
    case rejected(reason: Error)
    
    var value: Value? {
        if case .fulfilled(let value) = self {
            return value
        }
        return nil
    }
    
    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }
    
    var isFulfilled: Bool {
        if case .fulfilled = self { return true }
        return false
    }
    
    var isRejected: Bool {
        if case .rejected = self { return true }
        return false
    }
    
    var isSettled: Bool {
        if !isPending { return true }
        return false
    }
    
}
