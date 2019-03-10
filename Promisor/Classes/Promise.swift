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
    
    private var settlementHandlers = [SettlementHandler]()
    
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
    public convenience init(on queue: DispatchQueue = .global(qos: .background), _ executor: @escaping (_ resolve: @escaping FulfillHandler, _ reject: @escaping RejectHandler) throws -> ()) {
        self.init()
        queue.async {
            do {
                try executor(self.resolve, self.reject)
            } catch {
                self.reject(error)
            }
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
    public func then(on queue: DispatchQueue = .main, _ onFulfilled: @escaping FulfillHandler, _ onRejected: @escaping RejectHandler = { _ in }) -> Self {
        addOrExecuteHandlers(queue: queue, fulfillmentHandler: onFulfilled, rejectionHandler: onRejected)
        return self
    }
    
    @discardableResult
    public func then<NewValue>(on queue: DispatchQueue = .main, _ onFulfilled: @escaping (Value) throws -> Promise<NewValue>) -> Promise<NewValue> {
        return Promise<NewValue> { resolve, reject in
            self.addOrExecuteHandlers(
                queue: queue,
                fulfillmentHandler: { value in
                    do {
                        try onFulfilled(value).then(on: queue, resolve, reject)
                    } catch {
                        reject(error)
                    }
                },
                rejectionHandler: reject
            )
        }
    }
    
    @discardableResult
    public func then<NewValue>(on queue: DispatchQueue = .main, _ onFulfilled: @escaping (Value) throws -> NewValue) -> Promise<NewValue> {
        return then(on: queue) { value -> Promise<NewValue> in
            do {
                return Promise<NewValue>(value: try onFulfilled(value))
            } catch {
                return Promise<NewValue>(reason: error)
            }
        }
    }
    
    @discardableResult
    public func `catch`(on queue: DispatchQueue = .main, _ onRejected: @escaping RejectHandler) -> Self {
        return then(on: queue, { _ in }, onRejected)
    }
    
    @discardableResult
    public func `catch`<NewValue>(on queue: DispatchQueue = .main, _ onRejected: @escaping (Error) throws -> Promise<NewValue>) -> Promise<NewValue> {
        return Promise<NewValue> { resolve, reject in
            self.addOrExecuteHandlers(
                queue: queue,
                fulfillmentHandler: { _ in },
                rejectionHandler: { reason in
                    do {
                        try onRejected(reason).then(on: queue, resolve, reject)
                    } catch {
                        reject(error)
                    }
                }
            )
        }
    }
    
    @discardableResult
    public func `catch`<NewValue>(on queue: DispatchQueue = .main, _ onRejected: @escaping (Error) throws -> NewValue) -> Promise<NewValue> {
        return self.catch(on: queue) { reason in
            do {
                return Promise<NewValue>(value: try onRejected(reason))
            } catch {
                return Promise<NewValue>(reason: error)
            }
        }
    }
    
    @discardableResult
    public func finally(on queue: DispatchQueue = .main, _ onFinally: @escaping () -> ()) -> Self {
        return then(on: queue, { _ in onFinally() }, { _ in onFinally() }
        )
    }
    
    private func resolve(_ value: Value) {
        guard case .pending = state else { return }
        
        state = .fulfilled(value: value)
        handleSettlement()
    }
    
    private func reject(_ reason: Error) {
        guard case .pending = state else { return }
        
        state = .rejected(reason: reason)
        handleSettlement()
    }
    
    private func handleSettlement() {
        lockQueue.sync {
            for handler in settlementHandlers {
                handler.execute(for: state)
            }
        }
        lockQueue.async(flags: .barrier) {
            self.settlementHandlers.removeAll()
        }
    }
    
    private func addOrExecuteHandlers(queue: DispatchQueue, fulfillmentHandler: @escaping FulfillHandler, rejectionHandler: @escaping RejectHandler) {
        // If the promise has already been fulfilled or rejected when a corresponding handler is attached, the handler will be called, so there is no race condition between an asynchronous operation completing and its handlers being attached.
        switch state {
        case .fulfilled(let value):
            queue.async { fulfillmentHandler(value) }
        case .rejected(let reason):
            queue.async { rejectionHandler(reason) }
        default:
            lockQueue.async(flags: .barrier) {
                let handler = SettlementHandler(queue: queue, fulfillmentHandler: fulfillmentHandler, rejectionHandler: rejectionHandler)
                self.settlementHandlers.append(handler)
            }
        }
    }
    
}
