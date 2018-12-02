//
//  Promise.swift
//  Promisor
//
//  Created by Ennio Bovyn on 25/11/2018.
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
}

public final class Promise<Value> {
    
    public typealias FulfillHandler = (Value) -> ()
    public typealias RejectHandler = (Error) -> ()
    
    private(set) var state: PromiseState<Value> = .pending
    
    private var fulfillmentHandlers = [FulfillHandler]()
    private var rejectionHandlers = [RejectHandler]()
    
    /**
     Initializes a new Promise.
     
     - Parameter executor: A function that is passed with the parameters `resolve` and `reject`. The executor function is executed immediately by the Promise implementation, passing `resolve` and `reject` functions. The `resolve` and `reject` functions, when called, resolve or reject the promise, respectively. The executor normally initiates some asynchronous work, and then, once that completes, either calls the `resolve` function to resolve the promise or else rejects it if an error occurred.
     - Parameter resolve: A function that resolves the promise when called.
     - Parameter reject: A function that rejects the promise when called.
     */
    public convenience init(_ executor: (_ resolve: @escaping FulfillHandler, _ reject: @escaping RejectHandler) -> ()) {
        self.init()
        executor(self.resolve, self.reject)
    }
    
    private init() {
        state = .pending
    }
    
    private init(value: Value) {
        state = .fulfilled(value: value)
    }
    
    private init(reason: Error) {
        state = .rejected(reason: reason)
    }
    
    @discardableResult
    public func then(_ onFulfilled: @escaping FulfillHandler, _ onRejected: @escaping RejectHandler = { _ in }) -> Self {
        
        // If the promise has already been fulfilled or rejected when a corresponding handler is attached, the handler will be called, so there is no race condition between an asynchronous operation completing and its handlers being attached.
        switch state {
        case .fulfilled(let value):
            onFulfilled(value)
        case .rejected(let reason):
            onRejected(reason)
        default:
            fulfillmentHandlers.append(onFulfilled)
            rejectionHandlers.append(onRejected)
        }
        
        return self
    }
    
    @discardableResult
    public func then<NewValue>(_ onFulfilled: @escaping (Value) -> Promise<NewValue>) -> Promise<NewValue> {
        
        return Promise<NewValue> { resolve, reject in
            
            fulfillmentHandlers.append({ value in
                onFulfilled(value).then(resolve, reject)
            })
            
            rejectionHandlers.append(reject)
            
        }
    }
    
    @discardableResult
    public func then<NewValue>(_ onFulfilled: @escaping (Value) -> NewValue) -> Promise<NewValue> {
        
        return then({ value -> Promise<NewValue> in
            return Promise<NewValue>(value: onFulfilled(value))
        })
    }
    
    @discardableResult
    public func `catch`(_ onRejected: @escaping RejectHandler) -> Self {
        
        return then({ _ in }, onRejected)
    }
    
    @discardableResult
    public func finally(_ onFinally: @escaping () -> ()) -> Self {
        
        return then({ _ in
            onFinally()
        }, { _ in
            onFinally()
        })
    }
    
    private func resolve(_ value: Value) {
        guard case .pending = state else { return }
        
        state = .fulfilled(value: value)
        handleFulfillment(with: value)
    }
    
    private func reject(_ reason: Error) {
        guard case .pending = state else { return }
        
        state = .rejected(reason: reason)
        handleRejection(with: reason)
    }
    
    private func handleFulfillment(with value: Value) {
        
        for handler in fulfillmentHandlers {
            handler(value)
        }
        
        fulfillmentHandlers.removeAll()
    }
    
    private func handleRejection(with reason: Error) {
        
        for handler in rejectionHandlers {
            handler(reason)
        }
        
        rejectionHandlers.removeAll()
    }
    
}
