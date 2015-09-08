//
//  LimitedLoadersQueue.swift
//  iAsync
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class LimitedLoadersQueue<Strategy: JQueueStrategy> {
    
    private let state = JQueueState<Strategy.ValueT, Strategy.ErrorT>()//TODO remove
    
    private let orderStrategy: Strategy
    
    private var _limitCount = 10
    public var limitCount: Int {
        get {
            return _limitCount
        }
        set (newValue) {
            
            _limitCount = newValue
            performPendingLoaders()
        }
    }
    
    public init() {
        
        orderStrategy = Strategy(queueState: state)
    }
    
    public func cancelAllActiveLoaders() {
        
        for activeLoader in self.state.activeLoaders {
            
            if let handler = activeLoader.loadersHandler {
                handler(task: .Cancel)
            }
        }
    }
    
    private func hasLoadersReadyToStartForPendingLoader(pendingLoader: JBaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> Bool {
        
        if pendingLoader.barrier {
            
            return state.activeLoaders.count == 0
        }
        
        let result = limitCount > state.activeLoaders.count && state.pendingLoaders.count > 0
        
        if result {
            
            return state.activeLoaders.all { (activeLoader: JBaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> Bool in
                return !activeLoader.barrier
            }
        }
        
        return result
    }
    
    private func nextPendingLoader() -> JBaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>? {
        
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
                  finishCallback  : AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.DidFinishAsyncCallback?) -> JAsyncHandler in
            
            let loaderHolder = JBaseLoaderOwner(loader:loader, didFinishActiveLoaderCallback: { (loader: JBaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) -> () in
                
                self.didFinishActiveLoader(loader)
            })
            loaderHolder.barrier = barrier
            
            loaderHolder.progressCallback = progressCallback
            loaderHolder.stateCallback    = stateCallback
            loaderHolder.doneCallback     = finishCallback
            
            self.state.pendingLoaders.append(loaderHolder)
            
            self.performPendingLoaders()
            
            weak var weakLoaderHolder = loaderHolder
            
            return { (task: JAsyncHandlerTask) -> () in
                
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
                            //TODO review why doneCallback not used, compare with old version of async
                            let doneCallback = loaderHolder.doneCallback
                            
                            var objectIndex = Int.max
                            for (index, object) in self.state.pendingLoaders.enumerate() {
                                if object === loaderHolder {
                                    objectIndex = index
                                    break
                                }
                            }
                            if objectIndex != Int.max {
                                self.state.pendingLoaders.removeAtIndex(objectIndex)
                            }
                            finishCallback?(result: .Interrupted)
                        }
                    default:
                        assert(false) // "Unsupported type of task: %lu", (unsigned long)task)
                    }
                }
            }
        }
    }
    
    public func barrierBalancedLoaderWithLoader(loader: AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async) -> AsyncTypes<Strategy.ValueT, Strategy.ErrorT>.Async {
        
        return balancedLoaderWithLoader(loader, barrier:true)
    }
    
    private func didFinishActiveLoader(activeLoader: JBaseLoaderOwner<Strategy.ValueT, Strategy.ErrorT>) {
        
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
