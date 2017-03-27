//
//  Starburst.swift
//  Starburst
//
//  Created by Magnus Nilsson on 2017-03-11.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation

public protocol State {
    associatedtype A: Action
}
public protocol Action {}
public protocol Reducer {
    associatedtype S: State
    func reduce(state: inout S, action: S.A) -> S?
}
public enum ObserverPriority: Int {
    case high = 0
    case normal = 20
    case low = 50
}
public protocol Observer {
    typealias Token = UUID
    var token: Token { get }
    var priority: ObserverPriority { get }
    
    associatedtype S: State
    func newState(_ state: S)
}
public extension Observer {
    var priority: ObserverPriority { return .normal }
}
public struct Store {
    private var spaces: [AnyMutator] = []
    
    public init() {
    }
    
    mutating func add<S: State>(state: S) {
        spaces.append(AnyMutator(Space<S>(state: state)))
    }
    
    func add<R: Reducer>(reducer: R) {
        spaces.forEach { $0.add(reducer: reducer) }
    }
    
    func dispatch(_ action: Action) {
        spaces.forEach { $0.dispatch(action) }
    }
    
    func subscribe<O: Observer>(_ observer: O) {
        spaces.forEach { $0.subscribe(observer) }
    }
    
    func unsubscribe<O: Observer>(_ observer: O) {
        spaces.forEach { $0.unsubscribe(observer) }
    }
}

// PRIVATE

private struct AnyReducer<S: State>: Reducer {
    init<R: Reducer>(_ reducer: R) where R.S == S {
        box = reducer.reduce
    }
    func reduce(state: inout S, action: S.A) -> S? {
        return box(&state, action)
    }
    private let box: (inout S, S.A) -> S?
}
private struct AnyObserver<S: State>: Observer, Equatable {
    let token: Observer.Token
    var priority: ObserverPriority { return priorityBox() }
    
    init<O: Observer>(_ observer: O) where O.S == S {
        token = observer.token
        stateBox = observer.newState
        priorityBox = { observer.priority }
    }
    func newState(_ state: S) {
        stateBox(state)
    }
    public static func ==(lhs: AnyObserver, rhs: AnyObserver) -> Bool {
        return lhs.token == rhs.token
    }
    private let stateBox: (S) -> Void
    private let priorityBox: () -> ObserverPriority
}
private protocol Mutator: class {
    associatedtype S: State
    func add<R: Reducer>(reducer: R) where R.S == S
    func dispatch(_ action: S.A)
    func subscribe<O: Observer>(_ observer: O) where O.S == S
    func unsubscribe<O: Observer>(_ observer: O) where O.S == S
}
private struct AnyMutator {
    init<M: Mutator>(_ mutator: M) {
        addBox = { reducer in
            if let reducer = reducer as? AnyReducer<M.S> {
                mutator.add(reducer: reducer)
            }
        }
        dispatchBox = { action in
            if let action = action as? M.S.A {
                mutator.dispatch(action)
            }
        }
        subscribeBox = { observer in
            if let observer = observer as? AnyObserver<M.S> {
                mutator.subscribe(observer)
            }
        }
        unsubscribeBox = { observer in
            if let observer = observer as? AnyObserver<M.S> {
                mutator.unsubscribe(observer)
            }
        }
    }
    func add<R: Reducer>(reducer: R) {
        addBox(AnyReducer<R.S>(reducer))
    }
    func dispatch(_ action: Action) {
        dispatchBox(action)
    }
    func subscribe<O: Observer>(_ observer: O) {
        subscribeBox(AnyObserver<O.S>(observer))
    }
    func unsubscribe<O: Observer>(_ observer: O) {
        unsubscribeBox(AnyObserver<O.S>(observer))
    }
    private let addBox: (Any) -> ()
    private let dispatchBox: (Action) -> ()
    private let subscribeBox: (Any) -> ()
    private let unsubscribeBox: (Any) -> ()
}
private class Space<TS: State>: Mutator {
    typealias S = TS
    
    var state: S
    var reducers: [AnyReducer<S>] = []
    var observers: [AnyObserver<S>] = []
    
    init(state: S) {
        self.state = state
    }
    
    func add<R: Reducer>(reducer: R) where R.S == S {
        reducers.append(AnyReducer<S>(reducer))
    }
    
    func dispatch(_ action: S.A) {
        reducers.forEach { reducer in
            if let s = reducer.reduce(state: &state, action: action) {
                state = s
                observers.forEach { $0.newState(state) }
            }
        }
    }
    
    func subscribe<O: Observer>(_ observer: O) where O.S == S {
        observers.append(AnyObserver<S>(observer))
        observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
        observer.newState(state)
    }
    
    func unsubscribe<O: Observer>(_ observer: O) where O.S == S {
        if let index = observers.index(of: AnyObserver<S>(observer)) {
            observers.remove(at: index)
        }
    }
}
