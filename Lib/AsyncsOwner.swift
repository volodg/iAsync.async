//
//  AsyncsOwner.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 19.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class AsyncsOwner {
    
    private final class ActiveLoaderData {

        var handler: AsyncHandler?

        func clear() {
            handler = nil
        }
    }

    private var loaders = [ActiveLoaderData]()

    let task: AsyncHandlerTask

    public init(task: AsyncHandlerTask) {
        self.task = task
    }

    public func ownedAsync<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async) -> AsyncTypes<Value, Error>.Async {
        
        return { [weak self] (
            progressCallback: AsyncProgressCallback?,
            stateCallback   : AsyncChangeStateCallback?,
            finishCallback  : AsyncTypes<Value, Error>.DidFinishAsyncCallback?) -> AsyncHandler in
            
            if let self_ = self {
                
                let loaderData = ActiveLoaderData()
                self_.loaders.append(loaderData)
                
                let finishCallbackWrapper = { (result: AsyncResult<Value, Error>) -> () in
                    
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
                
                return { (task: AsyncHandlerTask) -> () in
                    
                    guard let self_ = self else { return }
                        
                    if let loaderIndex = self_.loaders.indexOf( { $0 === loaderData } ) {
                        
                        self_.loaders.removeAtIndex(loaderIndex)
                        loaderData.handler?(task: task)
                        loaderData.clear()
                    }
                }
            } else {
                
                finishCallback?(result: .Interrupted)
                return jStubHandlerAsyncBlock
            }
        }
    }
    
    public func handleAll(task: AsyncHandlerTask) {
        
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
