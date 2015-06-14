//
//  JAsyncTypesTransform.swift
//  JAsync
//
//  Created by Vladimir Gorbenko on 04.10.14.
//  Copyright (c) 2014 EmbeddedSources. All rights reserved.
//

import Foundation

public enum JAsyncTypesTransform<T1, T2> {
    
    private typealias Async1 = JAsyncTypes<T1>.JAsync
    private typealias Async2 = JAsyncTypes<T2>.JAsync
    
    public typealias PackedType = (T1?, T2?)
    
    private typealias PackedAsync = JAsyncTypes<PackedType>.JAsync
    
    public typealias AsyncTransformer = (PackedAsync) -> PackedAsync
}
