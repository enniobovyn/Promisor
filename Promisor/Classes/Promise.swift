//
//  Promise.swift
//  Promisor
//
//  Created by Ennio Bovyn on 25/11/2018.
//

public enum PromiseError: Error {
    case cancelled
}

public final class Promise<Value> {
    
    public typealias Executor = (_ resolve: @escaping FulfillmentHandler, _ reject: @escaping RejectionHandler) throws -> ()
    public typealias ExtendedExecutor = (_ config: Configuration, _ resolve: @escaping FulfillmentHandler, _ reject: @escaping RejectionHandler) throws -> ()
    
    public internal(set) var cancelContext: CancelContext? {
        didSet {
            cancelContext?.onCancel { [weak self] in
                guard let self = self, self.state.isPending else { return }
                
                self.reject(PromiseError.cancelled)
                self.configuration.onCancel?()
            }
        }
    }
    
    private(set) var state: State<Value> = .pending
    
    private let lockQueue = DispatchQueue(label: "promise-lock_queue")
    private let configuration = Configuration()
    
    private var settlementHandlers = [SettlementHandler]()
    
    /**
     Initializes a new Promise.
     
     - Parameter executor: A function that is passed with the parameters `resolve` and `reject`. The executor function is executed immediately by the Promise implementation, passing `resolve` and `reject` functions. The `resolve` and `reject` functions, when called, resolve or reject the promise, respectively. The executor normally initiates some asynchronous work, and then, once that completes, either calls the `resolve` function to resolve the promise or else rejects it if an error occurred.
     - Parameter resolve: A function that resolves the promise when called.
     - Parameter reject: A function that rejects the promise when called.
     */
    public convenience init(on queue: DispatchQueue = .global(qos: .background), _ executor: @escaping Executor) {
        self.init()
        queue.async {
            do {
                try executor(self.resolve, self.reject)
            } catch {
                self.reject(error)
            }
        }
    }
    
    public convenience init(on queue: DispatchQueue = .global(qos: .background), _ executor: @escaping ExtendedExecutor) {
        self.init()
        queue.async {
            do {
                try executor(self.configuration, self.resolve, self.reject)
            } catch {
                self.reject(error)
            }
        }
    }
    
    private init() {
        state = .pending
        defer {
            cancelContext = CancelContext()
        }
    }
    
    private init(value: Value) {
        state = .fulfilled(value: value)
    }
    
    private init(reason: Error) {
        state = .rejected(reason: reason)
    }
    
    @discardableResult
    public func then(on queue: DispatchQueue = .main, _ onFulfilled: @escaping FulfillmentHandler, _ onRejected: @escaping RejectionHandler = { _ in }) -> Self {
        addOrExecuteHandlers(queue: queue, fulfillmentHandler: onFulfilled, rejectionHandler: onRejected)
        return self
    }
    
    @discardableResult
    public func then<NewValue>(on queue: DispatchQueue = .main, _ onFulfilled: @escaping (Value) throws -> Promise<NewValue>) -> Promise<NewValue> {
        let promise = Promise<NewValue> { resolve, reject in
            self.addOrExecuteHandlers(
                queue: queue,
                fulfillmentHandler: { value in
                    do {
                        let p = try onFulfilled(value)
                        p.cancelContext = self.cancelContext
                        p.then(on: queue, resolve, reject)
                    } catch {
                        reject(error)
                    }
                },
                rejectionHandler: reject
            )
        }
        promise.cancelContext = cancelContext
        return promise
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
    public func `catch`(on queue: DispatchQueue = .main, _ onRejected: @escaping RejectionHandler) -> Self {
        return then(on: queue, { _ in }, onRejected)
    }
    
    @discardableResult
    public func recover(on queue: DispatchQueue = .main, _ onRejected: @escaping (Error) throws -> Promise) -> Promise {
        let promise = Promise { resolve, reject in
            self.addOrExecuteHandlers(
                queue: queue,
                fulfillmentHandler: resolve,
                rejectionHandler: { reason in
                    do {
                        let p = try onRejected(reason)
                        p.cancelContext = self.cancelContext
                        p.then(on: queue, resolve, reject)
                    } catch {
                        reject(error)
                    }
                }
            )
        }
        promise.cancelContext = cancelContext
        return promise
    }
    
    @discardableResult
    public func recover(on queue: DispatchQueue = .main, _ onRejected: @escaping (Error) throws -> Value) -> Promise {
        return recover(on: queue) { reason -> Promise in
            do {
                return Promise(value: try onRejected(reason))
            } catch {
                return Promise(reason: error)
            }
        }
    }
    
    @discardableResult
    public func finally(on queue: DispatchQueue = .main, _ onFinally: @escaping () -> ()) -> Self {
        return then(on: queue, { _ in onFinally() }, { _ in onFinally() })
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
    
    private func addOrExecuteHandlers(queue: DispatchQueue, fulfillmentHandler: @escaping FulfillmentHandler, rejectionHandler: @escaping RejectionHandler) {
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
