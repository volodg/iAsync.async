//
//  NSURL+LocalDataLoader.swift
//  iAsync_async
//
//  Created by Gorbenko Vladimir on 25.11.15.
//  Copyright (c) 2015 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_reactiveKit

final private class URLLocalDataLoader : AsyncStreamInterface {

    static func loader(url: NSURL) -> AsyncTypes<Value, Error>.Async {

        let factory = { () -> URLLocalDataLoader in

            let asyncObj = URLLocalDataLoader(url: url)
            return asyncObj
        }

        let loader = createStream(factory).toAsync()
        return loader
    }

    let url: NSURL

    private init(url: NSURL) {

        self.url = url
    }

    typealias Value = NSData
    typealias Next  = AnyObject
    typealias Error = NSError

    private var success: (Value -> Void)?

    func asyncWithCallbacks(
        success success: Value -> Void,
        next   : Next  -> Void,
        error  : Error -> Void) {

        url.localDataWithCallbacks({ (data) -> Void in

            success(data)
        }) { (value) -> Void in

            error(value)
        }
    }

    func cancel() {}
}

extension NSURL {

    public func localDataLoader() -> AsyncTypes<NSData, NSError>.Async {

        //TODO add merger
        return URLLocalDataLoader.loader(self)
    }
}
