//
//  FailablePromise.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 17/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public class FailablePromise<T> {
    
//    fileprivate var semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    fileprivate var dispatchGroup: DispatchGroup = DispatchGroup()
    
    fileprivate var transformCompletion: ((T?, Error?)->())? {
        didSet {
            switch state {
            case .waiting:
                break
            case let .fulfilled(value):
                transformCompletion?(value, nil)
            case let .failed(error):
                transformCompletion?(nil, error)
            }
        }
    }
    
    fileprivate var transformProgress: ((Progress)->())?
    
    fileprivate var fulfillHandler: (DispatchQueue, (T)->())? {
        didSet {
            switch state {
            case .waiting:
                fallthrough
            case .failed:
                break
            case let .fulfilled(value):
                if let (queue, handler) = fulfillHandler {
                    queue.async {
                        handler(value)
                    }
                }
            }
        }
    }
    
    fileprivate var failureHandler: (DispatchQueue, (Error)->())? {
        didSet {
            switch state {
            case .waiting:
                fallthrough
            case .fulfilled:
                break
            case let .failed(error):
                if let (queue, handler) = failureHandler {
                    queue.async {
                        handler(error)
                    }
                }
            }
        }
    }
    
    fileprivate var progressHandler: (DispatchQueue, (Progress)->())?
    
    fileprivate var state: State = .waiting {
        didSet {
            defer {
                dispatchGroup.leave()
            }
            switch state {
            case .waiting:
                break
            case let .fulfilled(value):
                if let (queue, handler) = fulfillHandler {
                    queue.async {
                        handler(value)
                    }
                }
                transformCompletion?(value, nil)
            case let .failed(error):
                if let (queue, handler) = failureHandler {
                    queue.async {
                        handler(error)
                    }
                }
                transformCompletion?(nil, error)
            }
//            dispatchGroup.notify(queue: DispatchQueue.global(qos: .background)) {
//                print("All async calls were run!")
//            }
        }
    }
    
    public init() {
        self.trensformedPromiseRef = nil
        self.dispatchGroup.enter()
    }
    
    private let trensformedPromiseRef: AnyObject?
    
    private init<A>(transforming promise: FailablePromise<A>, with transform: @escaping (A)->TransformationResult) {
        self.dispatchGroup.enter()
        self.trensformedPromiseRef = promise
        promise.transformCompletion = { [weak self] value, error in
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
        promise.transformProgress = { [weak self] progress in
            self?.send(.progress(value: progress))
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
        case progress(value: Progress)
        case fail(with: Error)
    }
}

extension FailablePromise {
    
    @discardableResult
    public func fulfillmentHandler(on queue: DispatchQueue = .main, withHandler handler: @escaping (T)->()) -> Self {
        self.fulfillHandler = (queue, handler)
        return self
    }
    
    @discardableResult
    public func failureHandler(on queue: DispatchQueue = .main, withHandler handler: @escaping (Error)->()) -> Self {
        self.failureHandler = (queue, handler)
        return self
    }
    
    @discardableResult
    public func progressHandler(on queue: DispatchQueue = .main, withHandler handler: @escaping (Progress)->()) -> Self {
        self.progressHandler = (queue, handler)
        return self
    }
}

extension FailablePromise {
    
    internal func send(_ message: Message) {
        guard case .waiting = self.state else {
            print("WARN - cannot apply \(message) - messages accepted ony before fulfilled or failed - current: \(self.state)")
            return
        }
        switch message {
        case let .fulfill(data):
            self.state = .fulfilled(value:data)
        case let .progress(value):
            if let (queue, handler) = self.progressHandler {
                queue.async {
                    handler(value)
                }
            }
            self.transformProgress?(value)
        case let .fail(error):
            self.state = .failed(reason: error)
        }
    }
}

extension FailablePromise {
    
    public var completed: Bool {
        if case .waiting = state {
            return false
        } else {
            return true
        }
    }
    
    public var value: T? {
        if !completed {
            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {
                print("All async calls were run!")
            }
            dispatchGroup.wait()
        }
        if case let .fulfilled(value) = state {
            return value
        } else if case .failed = state {
            return nil
        } else {
            fatalError("Internal inconsitency - waiting promise trying to return value ignoring semaphore")
        }
    }
    
    public func valueWithTimeout(_ timeout: Double) -> T? {
        if !completed {
            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {
                print("All async calls were run!")
            }
            let waitResult = dispatchGroup.wait(timeout: DispatchTime.now() + timeout)
            if case .timedOut = waitResult {
                return nil
            }
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
        guard case .waiting = from else {
            fatalError("Internal inconsitency - promise can't change state if not waiting - current:\(state)")
        }
    }
}
