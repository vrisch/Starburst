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
public typealias Reducer<S: State> = (_ state: inout S, _ action: S.A) -> S?
public typealias Observer<S: State> = (_ state: S) -> Void
public typealias Token = UUID
public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}
public struct Store {
    private var spaces: [AnyMutator] = []

    public init() {
    }
    public mutating func add<S: State>(state: S) {
        spaces.append(AnyMutator(Space<S>(state: state)))
    }
    public func add<S: State>(reducer: @escaping Reducer<S>) {
        spaces.forEach { $0.add(reducer: reducer) }
    }
    public func dispatch(_ action: Action) {
        spaces.forEach { $0.dispatch(action) }
    }
    @discardableResult
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Token? {
        var token: Token? = nil
        spaces.forEach {
            if let t = $0.subscribe(priority, observer) {
                token = t
            }
        }
        return token
    }
    public func unsubscribe(token: Token?) {
        if let token = token {
            spaces.forEach { $0.unsubscribe(token: token) }
        }
    }
}

// PRIVATE

private struct AnyReducer<S: State> {
    init(_ reducer: @escaping Reducer<S>) {
        box = reducer
    }
    func reduce(state: inout S, action: S.A) -> S? {
        return box(&state, action)
    }
    private let box: (inout S, S.A) -> S?
}
private struct AnyObserver<S: State>: Equatable {
    let token: Token = UUID()
    let priority: Priority
    
    init(_ priority: Priority, _ observer: @escaping Observer<S>) {
        self.priority = priority
        box = observer
    }
    func newState(_ state: S) {
        box(state)
    }
    public static func ==(lhs: AnyObserver, rhs: AnyObserver) -> Bool {
        return lhs.token == rhs.token
    }
    private let box: (S) -> ()
}
private protocol Mutator: class {
    associatedtype S: State
    func add(reducer: @escaping Reducer<S>)
    func dispatch(_ action: S.A)
    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) -> Token
    func unsubscribe(token: Token)
}
private struct AnyMutator {
    init<M: Mutator>(_ mutator: M) {
        addBox = { reducer in
            if let reducer = reducer as? AnyReducer<M.S> {
                mutator.add(reducer: reducer.reduce)
            }
        }
        dispatchBox = { action in
            if let action = action as? M.S.A {
                mutator.dispatch(action)
            }
        }
        subscribeBox = { observer in
            if let observer = observer as? AnyObserver<M.S> {
                return mutator.subscribe(observer.priority, observer.newState)
            }
            return nil
        }
        unsubscribeBox = { token in
            mutator.unsubscribe(token: token)
        }
    }
    func add<S: State>(reducer: @escaping Reducer<S>) {
        addBox(AnyReducer<S>(reducer))
    }
    func dispatch(_ action: Action) {
        dispatchBox(action)
    }
    func subscribe<S: State>(_ priority: Priority, _ observer: @escaping Observer<S>) -> Token? {
        return subscribeBox(AnyObserver<S>(priority, observer))
    }
    func unsubscribe(token: Token) {
        unsubscribeBox(token)
    }
    private let addBox: (Any) -> Void
    private let dispatchBox: (Action) -> Void
    private let subscribeBox: (Any) -> Token?
    private let unsubscribeBox: (Token) -> Void
}
private class Space<TS: State>: Mutator {
    typealias S = TS
    
    var state: S
    var reducers: [AnyReducer<S>] = []
    var observers: [AnyObserver<S>] = []
    
    init(state: S) {
        self.state = state
    }
    func add(reducer: @escaping Reducer<S>) {
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
    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) -> Token {
        let obs = AnyObserver<S>(priority, observer)
        observers.append(obs)
        observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
        observer(state)
        return obs.token
    }
    func unsubscribe(token: Token) {
        if let match = observers.first(where: { $0.token == token }) {
            if let index = observers.index(of: match) {
                observers.remove(at: index)
            }
        }
    }
}
