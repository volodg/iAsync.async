//
//  NSURL+LocalDataLoader.swift
//  iAsync_async
//
//  Created by Gorbenko Vladimir on 25.11.15.
//  Copyright (c) 2015 EmbeddedSources. All rights reserved.
//

import Foundation

final private class URLLocalDataLoader : AsyncInterface {

    static func loader(url: NSURL) -> AsyncTypes<ValueT, ErrorT>.Async {

        let factory = { () -> URLLocalDataLoader in

            let asyncObj = URLLocalDataLoader(url: url)
            return asyncObj
        }

        let loader = AsyncBuilder.buildWithAdapterFactory(factory)
        return loader
    }

    let url: NSURL

    private init(url: NSURL) {

        self.url = url
    }

    typealias ErrorT = NSError
    typealias ValueT = NSData

    private var finishCallback: AsyncTypes<ValueT, NSError>.DidFinishAsyncCallback?

    func asyncWithResultCallback(
        finishCallback  : AsyncTypes<ValueT, ErrorT>.DidFinishAsyncCallback,
        stateCallback   : AsyncChangeStateCallback,
        progressCallback: AsyncProgressCallback)
    {
        url.localDataWithCallbacks({ (data) -> Void in

            finishCallback(result: .Success(data))
        }) { (error) -> Void in

            finishCallback(result: .Failure(error))
        }
    }

    func doTask(task: AsyncHandlerTask) {}

    var isForeignThreadResultCallback: Bool {
        return false
    }
}

extension NSURL {

    public func localDataLoader() -> AsyncTypes<NSData, NSError>.Async {

        //TODO add merger
        return URLLocalDataLoader.loader(self)
    }
}
