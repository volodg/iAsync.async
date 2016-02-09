//
//  AsyncStream+Additions.swift
//  iAsync_async
//
//  Created by Gorbenko Vladimir on 07/02/16.
//  Copyright (c) 2016 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils
import iAsync_reactiveKit

import ReactiveKit

public func asyncToStream<Value, Error: ErrorType>(loader: AsyncTypes<Value, Error>.Async) -> AsyncStream<Value, AnyObject, Error> {

    typealias Event = AsyncEvent<Value, AnyObject, Error>

    let result = AsyncStream { (observer: Event -> ()) -> DisposableType? in

        let handler = loader(progressCallback: { (progressInfo) -> () in

            observer(.Next(progressInfo))
        }, finishCallback: { (result) -> Void in

            switch result {
            case .Success(let value):
                observer(.Success(value))
            case .Failure(let error):
                observer(.Failure(error))
            }
        })

        return BlockDisposable({ () -> () in

            handler(task: .Cancel)
        })
    }

    return result
}

public extension AsyncStreamType where Self.Next == AnyObject, Self.Error == NSError {

    public func toAsync() -> AsyncTypes<Self.Value, Self.Error>.Async {

        return { (
            progressCallback: AsyncProgressCallback?,
            finishCallback  : AsyncTypes<Self.Value, Self.Error>.DidFinishAsyncCallback?) -> AsyncHandler in

            var progressCallbackHolder = progressCallback
            var finishCallbackHolder   = finishCallback

            let finishOnce = { (result: Result<Self.Value, Self.Error>) -> Void in

                progressCallbackHolder = nil

                if let finishCallback = finishCallbackHolder {
                    finishCallbackHolder = nil
                    finishCallback(result: result)
                }
            }

            let dispose = self.observe(on: nil, observer: { event -> () in

                if finishCallbackHolder == nil { return }

                switch event {
                case .Success(let value):
                    finishOnce(.Success(value))
                case .Failure(let error):
                    finishOnce(.Failure(error))
                case .Next(let next):
                    progressCallbackHolder?(progressInfo: next)
                }
            })

            return { (task: AsyncHandlerTask) -> Void in

                switch task {
                case .Cancel:
                    dispose.dispose()
                    finishOnce(.Failure(AsyncInterruptedError()))
                case .UnSubscribe:
                    progressCallbackHolder = nil
                    finishCallbackHolder   = nil
                }
            }
        }
    }
}
