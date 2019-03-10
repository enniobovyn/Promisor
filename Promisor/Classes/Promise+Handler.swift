//
//  Promise+Handler.swift
//  Promisor
//
//  Created by Ennio Bovyn on 10/03/2019.
//

extension Promise {
    
    struct SettlementHandler {
        
        let queue: DispatchQueue
        let fulfillmentHandler: Promise.FulfillHandler
        let rejectionHandler: Promise.RejectHandler
        
        func execute(for state: Promise.State<Value>) {
            var workItem: DispatchWorkItem
            switch state {
            case .fulfilled(let value):
                workItem = DispatchWorkItem { self.fulfillmentHandler(value) }
            case .rejected(let reason):
                workItem = DispatchWorkItem { self.rejectionHandler(reason) }
            default: return
            }
            queue.async(execute: workItem)
            workItem.wait()
        }
        
    }
    
}
