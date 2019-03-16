//
//  Promise+Handler.swift
//  Promisor
//
//  Created by Ennio Bovyn on 10/03/2019.
//

extension Promise {
    
    public typealias FulfillmentHandler = (Value) -> ()
    public typealias RejectionHandler = (Error) -> ()
    
    struct SettlementHandler {
        
        let queue: DispatchQueue
        let fulfillmentHandler: FulfillmentHandler
        let rejectionHandler: RejectionHandler
        
        func execute(for state: Promise.State<Value>, completionHandler: (() -> ())? = nil) {
            switch state {
            case .fulfilled(let value):
                queue.async {
                    self.fulfillmentHandler(value)
                    completionHandler?()
                }
            case .rejected(let reason):
                queue.async {
                    self.rejectionHandler(reason)
                    completionHandler?()
                }
            default: return
            }
        }
        
    }
    
}
