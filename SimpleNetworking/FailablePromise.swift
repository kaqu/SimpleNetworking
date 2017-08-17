//
//  FailablePromise.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 17/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public class FailablePromise<T> {
    
    fileprivate var semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    private var trainsformCompletion: ((T?, Error?)->())? {
        didSet {
            switch state {
            case .waiting:
                break
            case let .fulfilled(value):
                trainsformCompletion?(value, nil)
            case let .failed(error):
                trainsformCompletion?(nil, error)
            }
        }
    }
    public var fulfillHandler: ((T)->())? {
        didSet {
            switch state {
            case .waiting:
                fallthrough
            case .failed:
                break
            case let .fulfilled(value):
                fulfillHandler?(value)
            }
        }
    }
    public var failureHandler: ((Error)->())? {
        didSet {
            switch state {
            case .waiting:
                fallthrough
            case .fulfilled:
                break
            case let .failed(error):
                failureHandler?(error)
            }
        }
    }
    
    fileprivate var state: State = .waiting {
        willSet {
            checkStateChange(from: state, to: newValue)
        }
        didSet {
            switch state {
            case .waiting:
                break
            case let .fulfilled(value):
                semaphore.signal()
                fulfillHandler?(value)
                trainsformCompletion?(value, nil)
            case let .failed(error):
                semaphore.signal()
                failureHandler?(error)
                trainsformCompletion?(nil, error)
            }
            
        }
    }
    
    public init() {
        self.trensformedPromiseRef = nil
    }
    
    private let trensformedPromiseRef: AnyObject?
    
    private init<A>(transforming promise: FailablePromise<A>, with transform: @escaping (A)->TransformationResult) {
        self.trensformedPromiseRef = promise
        promise.trainsformCompletion = { [weak self] value, error in
            if let error = error {
                self?.send(.fail(with: error))
            } else if let value = value {
                switch transform(value) {
                case let .success(value):
                    self?.send(.fulfill(with: value))
                case let .failure(error):
                    self?.send(.fail(with: error))
                }
            } else {
                fatalError("Internal inconsitency - promise completion without any information")
            }
        }
    }
    
    public func transform<A>(with transform: @escaping (T)->(FailablePromise<A>.TransformationResult)) -> FailablePromise<A> {
        return FailablePromise<A>(transforming: self, with: transform)
    }
    
    indirect public enum TransformationResult {
        case success(with: T)
        case failure(reason: Error)
    }
    
    indirect internal enum State {
        case waiting
        case fulfilled(value: T)
        case failed(reason: Error)
    }
    
    indirect internal enum Message {
        case fulfill(with: T)
        case fail(with: Error)
    }
}

extension FailablePromise {
    
    internal func send(_ message: Message) {
        //        precondition(fulfillingThread == Thread.current, "Internal inconsitency - promise message sent on wrong thread")
        switch message {
        case let .fulfill(data):
            self.state = .fulfilled(value:data)
        case let .fail(error):
            self.state = .failed(reason: error)
        }
    }
}

extension FailablePromise {
    
    public var value: T? {
        if case .waiting = state {
            //            if fulfillingThread == Thread.current {
            //                fatalError("Internal inconsitency - waiting promise doing deadlock on thread: \(Thread.current)")
            //            }
            semaphore.wait()
        }
        if case let .fulfilled(value) = state {
            return value
        } else if case .failed = state {
            return nil
        } else {
            fatalError("Internal inconsitency - waiting promise trying to return value ignoring semaphore")
        }
    }
}

extension FailablePromise {
    
    fileprivate func checkStateChange(from: State, to: State) {
        if case .waiting = to {
            if case .fulfilled = from {
                fatalError("Internal inconsitency - promise can't wait when already fulfilled or failed")
            } else if case .failed = from {
                fatalError("Internal inconsitency - promise can't wait when already fulfilled or failed")
            }
        } else if case .fulfilled = to {
            if case .failed = from {
                fatalError("Internal inconsitency - promise can't fail when already fulfilled")
            }
        } else if case .failed = to {
            if case .fulfilled = from {
                fatalError("Internal inconsitency - promise can't fulfill when already failed")
            }
        }
    }
}
