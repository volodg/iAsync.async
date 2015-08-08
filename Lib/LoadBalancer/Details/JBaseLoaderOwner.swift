//
//  JBaseLoaderOwner.swift
//  Async
//
//  Created by Vladimir Gorbenko on 09.07.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

import iAsync_utils

public class JBaseLoaderOwner<Value, Error: ErrorType> {
    
    var barrier = false
    
    var loader: AsyncTypes<Value, Error>.Async!
    
    var loadersHandler  : JAsyncHandler?
    var progressCallback: AsyncProgressCallback?
    var stateCallback   : AsyncChangeStateCallback?
    var doneCallback    : AsyncTypes<Value, Error>.JDidFinishAsyncCallback?
    
    typealias FinishCallback = (JBaseLoaderOwner<Value, Error>) -> ()
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
        
        let stateCallbackWrapper = { (state: JAsyncState) -> () in
            
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
