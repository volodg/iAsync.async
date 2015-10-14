//
//  BaseLoaderOwner.swift
//  iAsync_async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

final public class BaseLoaderOwner<Value, Error: ErrorType> {
    
    var barrier = false
    
    var loader: AsyncTypes<Value, Error>.Async!
    
    var loadersHandler  : AsyncHandler?
    var progressCallback: AsyncProgressCallback?
    var stateCallback   : AsyncChangeStateCallback?
    var doneCallback    : AsyncTypes<Value, Error>.DidFinishAsyncCallback?
    
    typealias FinishCallback = (BaseLoaderOwner<Value, Error>) -> ()
    private var didFinishActiveLoaderCallback: FinishCallback?
    
    init(loader: AsyncTypes<Value, Error>.Async, didFinishActiveLoaderCallback: FinishCallback) {
        
        self.loader = loader
        self.didFinishActiveLoaderCallback = didFinishActiveLoaderCallback
    }
    
    func performLoader() {
        
        assert(loadersHandler == nil)
        
        let progressCallbackWrapper = { (progress: AnyObject) -> () in
            
            self.progressCallback?(progressInfo: progress)
            return
        }
        
        let stateCallbackWrapper = { (state: AsyncState) -> () in
            
            self.stateCallback?(state: state)
            return
        }
        
        let doneCallbackWrapper = { (result: AsyncResult<Value, Error>) -> () in
            
            self.didFinishActiveLoaderCallback?(self)
            self.doneCallback?(result: result)
            self.clear()
        }
        
        loadersHandler = loader(
            progressCallback: progressCallbackWrapper,
            stateCallback   : stateCallbackWrapper,
            finishCallback  : doneCallbackWrapper)
    }
    
    private func clear() {
        
        loader           = nil
        didFinishActiveLoaderCallback = nil
        loadersHandler   = nil
        progressCallback = nil
        stateCallback    = nil
        doneCallback     = nil
    }
}
