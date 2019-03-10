//
//  Promise.swift
//  Promisor
//
//  Created by Ennio Bovyn on 25/11/2018.
//

public final class Promise<Value> {
    
    public typealias FulfillHandler = (Value) -> ()
    public typealias RejectHandler = (Error) -> ()
    
    private let lockQueue = DispatchQueue(label: "promise-lock_queue", attributes: .concurrent)
    
    private var fulfillmentHandlers = [FulfillHandler]()
    private var rejectionHandlers = [RejectHandler]()
    
    private var _state: State<Value> = .pending
    
    private(set) var state: State<Value> {
        get {
            return lockQueue.sync { _state }
        }
        set {
            lockQueue.async(flags: .barrier) {
                self._state = newValue
            }
        }
    }
    
    /**
     Initializes a new Promise.
     
     - Parameter executor: A function that is passed with the parameters `resolve` and `reject`. The executor function is executed immediately by the Promise implementation, passing `resolve` and `reject` functions. The `resolve` and `reject` functions, when called, resolve or reject the promise, respectively. The executor normally initiates some asynchronous work, and then, once that completes, either calls the `resolve` function to resolve the promise or else rejects it if an error occurred.
     - Parameter resolve: A function that resolves the promise when called.
     - Parameter reject: A function that rejects the promise when called.
     */
    public convenience init(_ executor: (_ resolve: @escaping FulfillHandler, _ reject: @escaping RejectHandler) throws -> ()) {
        self.init()
        do {
            try executor(self.resolve, self.reject)
        } catch {
            self.reject(error)
        }
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
        addOrExecuteHandlers(
            fulfillmentHandler: onFulfilled,
            rejectionHandler: onRejected
        )
        return self
    }
    
    @discardableResult
    public func then<NewValue>(_ onFulfilled: @escaping (Value) throws -> Promise<NewValue>) -> Promise<NewValue> {
        return Promise<NewValue> { resolve, reject in
            addOrExecuteHandlers(
                fulfillmentHandler: { value in
                    do {
                        try onFulfilled(value).then(resolve, reject)
                    } catch {
                        reject(error)
                    }
                },
                rejectionHandler: reject
            )
        }
    }
    
    @discardableResult
    public func then<NewValue>(_ onFulfilled: @escaping (Value) throws -> NewValue) -> Promise<NewValue> {
        return then { value -> Promise<NewValue> in
            do {
                return Promise<NewValue>(value: try onFulfilled(value))
            } catch {
                return Promise<NewValue>(reason: error)
            }
        }
    }
    
    @discardableResult
    public func `catch`(_ onRejected: @escaping RejectHandler) -> Self {
        return then({ _ in }, onRejected)
    }
    
    @discardableResult
    public func `catch`<NewValue>(_ onRejected: @escaping (Error) throws -> Promise<NewValue>) -> Promise<NewValue> {
        return Promise<NewValue> { resolve, reject in
            addOrExecuteHandlers(
                fulfillmentHandler: { _ in },
                rejectionHandler: { reason in
                    do {
                        try onRejected(reason).then(resolve, reject)
                    } catch {
                        reject(error)
                    }
                }
            )
        }
    }
    
    @discardableResult
    public func `catch`<NewValue>(_ onRejected: @escaping (Error) throws -> NewValue) -> Promise<NewValue> {
        return self.catch { reason in
            do {
                return Promise<NewValue>(value: try onRejected(reason))
            } catch {
                return Promise<NewValue>(reason: error)
            }
        }
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
        lockQueue.sync {
            for handler in fulfillmentHandlers {
                handler(value)
            }
        }
        lockQueue.async(flags: .barrier) {
            self.fulfillmentHandlers.removeAll()
        }
    }
    
    private func handleRejection(with reason: Error) {
        lockQueue.sync {
            for handler in rejectionHandlers {
                handler(reason)
            }
        }
        lockQueue.async(flags: .barrier) {
            self.rejectionHandlers.removeAll()
        }
    }
    
    private func addOrExecuteHandlers(fulfillmentHandler: @escaping FulfillHandler, rejectionHandler: @escaping RejectHandler) {
        // If the promise has already been fulfilled or rejected when a corresponding handler is attached, the handler will be called, so there is no race condition between an asynchronous operation completing and its handlers being attached.
        switch state {
        case .fulfilled(let value):
            fulfillmentHandler(value)
        case .rejected(let reason):
            rejectionHandler(reason)
        default:
            lockQueue.async(flags: .barrier) {
                self.fulfillmentHandlers.append(fulfillmentHandler)
                self.rejectionHandlers.append(rejectionHandler)
            }
        }
    }
    
}
