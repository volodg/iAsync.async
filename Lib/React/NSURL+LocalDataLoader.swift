//
//  NSURL+LocalDataLoader.swift
//  iAsync_async
//
//  Created by Gorbenko Vladimir on 25.11.15.
//  Copyright (c) 2015 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_reactiveKit
import ReactiveKit

extension NSURL {

    public func localDataLoader() -> AsyncStream<NSData, AnyObject, NSError> {

        return create(producer: { observer -> DisposableType? in

            self.localDataWithCallbacks({ data -> Void in

                observer(.Success(data))
            }) { error -> Void in

                observer(.Failure(error))
            }
            return nil
        })
    }
}
