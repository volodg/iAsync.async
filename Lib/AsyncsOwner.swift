//
//  AsyncsOwner.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 19.06.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

import ReactiveKit

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

    public func ownedAsync<Value>(loader: AsyncTypes<Value, NSError>.Async) -> AsyncTypes<Value, NSError>.Async {

        return { [weak self] (
            progressCallback: AsyncProgressCallback?,
            finishCallback  : AsyncTypes<Value, NSError>.DidFinishAsyncCallback?) -> AsyncHandler in

            guard let self_ = self else {

                finishCallback?(result: .Failure(AsyncInterruptedError()))
                return jStubHandlerAsyncBlock
            }

            let loaderData = ActiveLoaderData()
            self_.loaders.append(loaderData)

            let finishCallbackWrapper = { (result: Result<Value, NSError>) -> () in

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
                finishCallback  : finishCallbackWrapper)

            return { (task: AsyncHandlerTask) -> () in

                guard let self_ = self, loaderIndex = self_.loaders.indexOf( { $0 === loaderData } ) else { return }

                self_.loaders.removeAtIndex(loaderIndex)
                loaderData.handler?(task: task)
                loaderData.clear()
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
