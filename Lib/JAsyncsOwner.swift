//
//  JAsyncsOwner.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 19.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import Result

public class JAsyncsOwner {
    
    private class ActiveLoaderData {
        
        var handler: JAsyncHandler?
        
        func clear() {
            handler = nil
        }
    }
    
    private var loaders = [ActiveLoaderData]()
    
    let task: JAsyncHandlerTask
    
    public init(task: JAsyncHandlerTask) {
        self.task = task
    }
    
    public func ownedAsync<T>(loader: JAsyncTypes<T>.JAsync) -> JAsyncTypes<T>.JAsync {
        
        return { [weak self] (
            progressCallback: JAsyncProgressCallback?,
            stateCallback   : JAsyncChangeStateCallback?,
            finishCallback  : JAsyncTypes<T>.JDidFinishAsyncCallback?) -> JAsyncHandler in
            
            if let self_ = self {
                
                let loaderData = ActiveLoaderData()
                self_.loaders.append(loaderData)
                
                let finishCallbackWrapper = { (result: Result<T, NSError>) -> () in
                    
                    if let self_ = self {
                        
                        for (index, _) in self_.loaders.enumerate() {
                            if self_.loaders[index] === loaderData {
                                self_.loaders.removeAtIndex(index)
                                break
                            }
                        }
                    }
                    
                    finishCallback?(result: result)
                    loaderData.clear()
                }
                
                loaderData.handler = loader(
                    progressCallback: progressCallback,
                    stateCallback   : stateCallback,
                    finishCallback  : finishCallbackWrapper)
                
                return { (task: JAsyncHandlerTask) -> () in
                    
                    if let self_ = self {
                        
                        var loaderIndex = Int.max
                        
                        for (index, _) in self_.loaders.enumerate() {
                            if self_.loaders[index] === loaderData {
                                loaderIndex = index
                                break
                            }
                        }
                        
                        if loaderIndex == Int.max {
                            return
                        }
                        
                        self_.loaders.removeAtIndex(loaderIndex)
                        loaderData.handler?(task: task)
                        loaderData.clear()
                    }
                }
            } else {
                
                let error = JAsyncFinishedByCancellationError()
                finishCallback?(result: Result.failure(error))
                return jStubHandlerAsyncBlock
            }
        }
    }
    
    public func handleAll(task: JAsyncHandlerTask) {
        
        let tmpLoaders = loaders
        loaders.removeAll(keepCapacity: false)
        for (_, element) in tmpLoaders.enumerate() {
            element.handler?(task: task)
        }
    }
    
    deinit {
        
        handleAll(self.task)
    }
}
