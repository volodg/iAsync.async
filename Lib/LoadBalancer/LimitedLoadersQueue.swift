//
//  LimitedLoadersQueue.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class LimitedLoadersQueue<Strategy: QueueStrategy> {
    
    private let state = QueueState<Strategy.ValueT, Strategy.ErrorT>()
    
    private let orderStrategy: Strategy
    
    public var limitCount: Int {
        didSet {
            performPendingLoaders()
        }
    }
    
    public convenience init() {
        
        self.init(limitCount: 10)
    }

    public var allLoadersCount: Int {

        return state.activeLoaders.count + state.pendingLoaders.count
    }
    
    public init(limitCount: Int) {

        self.limitCount = limitCount
        orderStrategy = Strategy(queueState: state)
    }
    
    public func cancelAllActiveLoaders() {
        
        for activeLoader in self.state.activeLoaders {
            
            if let handler = activeLoader.loadersHandler {
                handler(task: .Cancel)
            }
        }
    }
    
    private func hasLoadersReadyToStartForPendingLoader(pendingLoader: BaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> Bool {
        
        if pendingLoader.barrier {

            return state.activeLoaders.count == 0
        }

        let result = limitCount > state.activeLoaders.count && state.pendingLoaders.count > 0
        
        if result {
            
            return state.activeLoaders.all { (activeLoader: BaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> Bool in
                return !activeLoader.barrier
            }
        }
        
        return result
    }
    
    private func nextPendingLoader() -> BaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>? {
        
        let result = state.pendingLoaders.count > 0
            ?orderStrategy.firstPendingLoader()
            :nil

        return result
    }

    private func performPendingLoaders() {

        var pendingLoader = nextPendingLoader()

        while pendingLoader != nil && hasLoadersReadyToStartForPendingLoader(pendingLoader!) {

            orderStrategy.executePendingLoader(pendingLoader!)
            pendingLoader = nextPendingLoader()
        }
    }
    
    public func balancedLoaderWithLoader(loader: AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async, barrier: Bool) -> AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async {
        
        return { (progressCallback: AsyncProgressCallback?,
                  stateCallback   : AsyncChangeStateCallback?,
                  finishCallback  : AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.DidFinishAsyncCallback?) -> AsyncHandler in

            let loaderHolder = BaseLoaderOwner(loader:loader, didFinishActiveLoaderCallback: { (loader: BaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> () in

                self.didFinishActiveLoader(loader)
            })
            loaderHolder.barrier = barrier

            loaderHolder.progressCallback = progressCallback
            loaderHolder.stateCallback    = stateCallback
            loaderHolder.doneCallback     = finishCallback

            self.state.pendingLoaders.append(loaderHolder)

            self.performPendingLoaders()

            weak var weakLoaderHolder = loaderHolder
            
            return { (task: AsyncHandlerTask) -> () in
                
                if let loaderHolder = weakLoaderHolder {
                    switch (task) {
                    case .UnSubscribe:
                        loaderHolder.progressCallback = nil
                        loaderHolder.stateCallback    = nil
                        loaderHolder.doneCallback     = nil
                        break
                    case .Cancel:
                        if let handler = loaderHolder.loadersHandler {
                            
                            handler(task: .Cancel)
                        } else {
                            
                            //TODO self owning here fix?
                            let doneCallback = loaderHolder.doneCallback
                            
                            if let index = self.state.pendingLoaders.indexOf( { $0 === loaderHolder } ) {
                                self.state.pendingLoaders.removeAtIndex(index)
                            }
                            
                            doneCallback?(result: .Interrupted)
                        }
                    case .Resume, .Suspend:
                        fatalError("Unsupported type of task: \(task)")
                    }
                }
            }
        }
    }
    
    public func barrierBalancedLoaderWithLoader(loader: AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async) -> AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async {
        
        return balancedLoaderWithLoader(loader, barrier:true)
    }
    
    private func didFinishActiveLoader(activeLoader: BaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) {
        
        var objectIndex = Int.max
        for (index, object) in self.state.activeLoaders.enumerate() {
            if object === activeLoader {
                objectIndex = index
                break
            }
        }
        if objectIndex != Int.max {
            self.state.activeLoaders.removeAtIndex(objectIndex)
        }
        performPendingLoaders()
    }
}
