//
//  Promise+TypeMethods.swift
//  Promisor
//
//  Created by Ennio Bovyn on 19/01/2019.
//

public extension Promise {
    
    public static func resolve(_ value: Value) -> Promise<Value> {
        return Promise<Value> { resolve, reject in
            resolve(value)
        }
    }
    
    public static func reject(_ reason: Error) -> Promise<Value> {
        return Promise<Value> { resolve, reject in
            reject(reason)
        }
    }
    
    public static func all(_ promises: [Promise<Value>]) -> Promise<[Value]> {
        return Promise<[Value]> { resolve, reject in
            guard !promises.isEmpty else { resolve([]); return }

            for promise in promises {
                promise
                    .then { _ in
                        if !promises.contains(where: { $0.state.isPending || $0.state.isRejected }) {
                            resolve(promises.compactMap { $0.state.value })
                        }
                    }
                    .catch { reject($0) }
            }
        }
    }
    
    public static func race(_ promises: [Promise<Value>]) -> Promise<Value> {
        return Promise<Value> { resolve, reject in
            for promise in promises {
                promise.then(resolve, reject)
            }
        }
    }
    
}
