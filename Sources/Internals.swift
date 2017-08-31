//
//  Internals.swift
//  Starburst
//
//  Created by Magnus on 2017-07-22.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import Orbit

extension Reason: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .subscribed: return "subscribed"
        case .modified: return "modified"
        case let .custom(value): return "custom(\(value))"
        }
    }
}

internal struct AnyReducer<S: State> {
    let uuid = UUID()
    
    init(_ reducer: @escaping Reducer<S>) {
        box = reducer
    }
    func reduce(state: inout S, action: S.A) throws -> Reduction<S> {
        return try box(&state, action)
    }
    private let box: (inout S, S.A) throws -> Reduction<S>
}

internal struct AnyObserver<S: State>: Equatable {
    let uuid = UUID()
    let priority: Priority
    
    init(_ priority: Priority, _ observer: @escaping Observer<S>) {
        self.priority = priority
        box = observer
    }
    func newState(state: S, reason: Reason) throws {
        try box(state, reason)
    }
    public static func ==(lhs: AnyObserver, rhs: AnyObserver) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    private let box: (S, Reason) throws -> ()
}

internal protocol Shelf: class, CustomStringConvertible {
    associatedtype S: State

    var count: Int { get }

    func add(state: S) -> Disposable
    func add(reducer: @escaping Reducer<S>) -> Disposable
    func dispatch(_ action: S.A) throws
    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposable
}

internal struct AnyShelf: CustomStringConvertible {
    let uuid = UUID()

    var count: Int { return countBox() }
    var description: String { return descriptionBox() }

    init<S: Shelf>(_ shelf: S) {
        countBox = { return shelf.count }
        descriptionBox = { return shelf.description }
        addStateBox = { state in
            if let state = state as? S.S {
                return shelf.add(state: state)
            }
            return nil
        }
        addReducerBox = { reducer in
            if let reducer = reducer as? AnyReducer<S.S> {
                return shelf.add(reducer: reducer.reduce)
            }
            return nil
        }
        dispatchBox = { action in
            if let action = action as? S.S.A {
                try shelf.dispatch(action)
            }
        }
        subscribeBox = { observer in
            if let observer = observer as? AnyObserver<S.S> {
                return try shelf.subscribe(observer.priority, observer.newState)
            }
            return nil
        }
    }
    
    func add<S>(state: S) -> Disposable? {
        return addStateBox(state)
    }
    
    func add<S>(reducer: @escaping Reducer<S>) -> Disposable? {
        return addReducerBox(AnyReducer<S>(reducer))
    }

    func dispatch(_ action: Action) throws {
        try dispatchBox(action)
    }
    
    func subscribe<S: State>(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposable? {
        return try subscribeBox(AnyObserver<S>(priority, observer))
    }

    private let countBox: () -> Int
    private let descriptionBox: () -> String
    private let addStateBox: (Any) -> Disposable?
    private let addReducerBox: (Any) -> Disposable?
    private let dispatchBox: (Action) throws -> Void
    private let subscribeBox: (Any) throws -> Disposable?
}

internal struct AnyState<S: State> {
    let uuid = UUID()
    var state: S

    init(_ state: S) {
        self.state = state
    }
}

internal class Storage<TS: State>: Shelf {
    typealias S = TS
    
    var count: Int { return states.count + reducers.count + observers.count }

    func add(state: S) -> Disposable {
        let any = AnyState<S>(state)
        states.append(any)
        return Disposable(block: { self.unsubscribe(uuid: any.uuid) })
    }
    
    func add(reducer: @escaping Reducer<S>) -> Disposable {
        let any = AnyReducer<S>(reducer)
        reducers.append(any)
        return Disposable(block: { self.unsubscribe(uuid: any.uuid) })
    }
    
    func dispatch(_ action: S.A) throws {
        try reducers.forEach { reducer in
            try states.enumerated().forEach {
                let (index, state) = $0
                var local = state.state
                let reduction = try reducer.reduce(state: &local, action: action)
                if case let .modified(newState) = reduction {
                    states[index].state = newState
                    try observers.forEach { try $0.newState(state: newState, reason: .modified) }
                } else if case let .modified2(newState, reason) = reduction {
                    states[index].state = newState
                    try observers.forEach { try $0.newState(state: newState, reason: reason) }
                }
            }
        }
    }

    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposable {
        let any = AnyObserver<S>(priority, observer)
        observers.append(any)
        observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
        try states.forEach { state in
            try observer(state.state, .subscribed)
        }
        return Disposable(block: { self.unsubscribe(uuid: any.uuid) })
    }
    
    func unsubscribe(uuid: UUID) {
        observers.enumerated().forEach { let (index, any) = $0
            if any.uuid == uuid {
                observers.remove(at: index)
            }
        }
        reducers.enumerated().forEach { let (index, any) = $0
            if any.uuid == uuid {
                reducers.remove(at: index)
            }
        }
        states.enumerated().forEach { let (index, any) = $0
            if any.uuid == uuid {
                states.remove(at: index)
            }
        }
    }
    
    private var states: [AnyState<S>] = []
    private var reducers: [AnyReducer<S>] = []
    private var observers: [AnyObserver<S>] = []
}

extension Storage: CustomStringConvertible {
    public var description: String {
        return "\(type(of: self)): \(states.count) states, \(reducers.count) reducers, \(observers.count) observers"
    }
}

