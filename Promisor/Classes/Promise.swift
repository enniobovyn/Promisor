//
//  Promise.swift
//  Promisor
//
//  Created by Ennio Bovyn on 25/11/2018.
//

public final class Promise<Value> {
    
    public typealias FulfillHandler = (Value) -> ()
    public typealias RejectHandler = (Error) -> ()
    
    private(set) var state: State<Value> = .pending
    
    private let lockQueue = DispatchQueue(label: "promise-lock_queue")
    
    private var settlementHandlers = [SettlementHandler]()
    
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
        lockQueue.async {
            guard case .pending = self.state else { return }
            
            self.state = .fulfilled(value: value)
            self.handleSettlement(with: self.settlementHandlers)
        }
    }
    
    private func reject(_ reason: Error) {
        lockQueue.async {
            guard case .pending = self.state else { return }
            
            self.state = .rejected(reason: reason)
            self.handleSettlement(with: self.settlementHandlers)
        }
    }
    
    private func handleSettlement(with handlers: [SettlementHandler]) {
        guard !handlers.isEmpty else { return }
        
        lockQueue.async {
            var mutableHandlers = handlers
            let handler = mutableHandlers.removeFirst()
            handler.execute(for: self.state) {
                self.handleSettlement(with: mutableHandlers)
            }
        }
    }
    
    private func addOrExecuteHandlers(queue: DispatchQueue, fulfillmentHandler: @escaping FulfillHandler, rejectionHandler: @escaping RejectHandler) {
        let handler = SettlementHandler(queue: queue, fulfillmentHandler: fulfillmentHandler, rejectionHandler: rejectionHandler)
        lockQueue.async(flags: .barrier) {
            // If the promise has already been fulfilled or rejected when a corresponding handler is attached, the handler will be called, so there is no race condition between an asynchronous operation completing and its handlers being attached.
            if self.state.isSettled {
                handler.execute(for: self.state)
                return
            }
            self.settlementHandlers.append(handler)
        }
    }
    
}
