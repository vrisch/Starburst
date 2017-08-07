//
//  Internals.swift
//  Starburst
//
//  Created by Magnus on 2017-07-22.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation

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
    func reduce(state: inout S, action: S.A) -> Reduction<S> {
        return box(&state, action)
    }
    private let box: (inout S, S.A) -> Reduction<S>
}

internal struct AnyObserver<S: State>: Equatable {
    let uuid = UUID()
    let priority: Priority
    
    init(_ priority: Priority, _ observer: @escaping Observer<S>) {
        self.priority = priority
        box = observer
    }
    func newState(state: S, reason: Reason) {
        box(state, reason)
    }
    public static func ==(lhs: AnyObserver, rhs: AnyObserver) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    private let box: (S, Reason) -> ()
}

internal protocol Shelf: class, CustomStringConvertible {
    associatedtype S: State

    func add(state: S) -> UUID
    func add(reducer: @escaping Reducer<S>) -> UUID
    func dispatch(_ action: S.A)
    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) -> UUID
    func unsubscribe(uuid: UUID)
}

internal struct AnyShelf: CustomStringConvertible {
    let uuid = UUID()
    var description: String { return descriptionBox() }

    init<S: Shelf>(_ shelf: S) {
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
                shelf.dispatch(action)
            }
        }
        subscribeBox = { observer in
            if let observer = observer as? AnyObserver<S.S> {
                return shelf.subscribe(observer.priority, observer.newState)
            }
            return nil
        }
        unsubscribeBox = { uuid in
            shelf.unsubscribe(uuid: uuid)
        }
    }
    
    func add<S>(state: S) -> UUID? {
        return addStateBox(state)
    }
    
    func add<S>(reducer: @escaping Reducer<S>) -> UUID? {
        return addReducerBox(AnyReducer<S>(reducer))
    }

    func dispatch(_ action: Action) {
        dispatchBox(action)
    }
    
    func subscribe<S: State>(_ priority: Priority, _ observer: @escaping Observer<S>) -> UUID? {
        return subscribeBox(AnyObserver<S>(priority, observer))
    }
    
    func unsubscribe(uuid: UUID) {
        unsubscribeBox(uuid)
    }

    private let descriptionBox: () -> String
    private let addStateBox: (Any) -> UUID?
    private let addReducerBox: (Any) -> UUID?
    private let dispatchBox: (Action) -> Void
    private let subscribeBox: (Any) -> UUID?
    private let unsubscribeBox: (UUID) -> Void
}

internal class Storage<TS: State>: Shelf {
    typealias S = TS
    
    init(states: [S]) {
        self.states = states
    }

    func add(state: S) -> UUID {
        states.append(state)
        return UUID() // There is really no UUID to return at this stage, but perhaps it should be
    }

    func add(reducer: @escaping Reducer<S>) -> UUID {
        let any = AnyReducer<S>(reducer)
        reducers.append(any)
        return any.uuid
    }
    
    func dispatch(_ action: S.A) {
        reducers.forEach { reducer in
            states.enumerated().forEach { let (index, state) = $0
                var local = state
                let reduction = reducer.reduce(state: &local, action: action)
                if case let .modified(newState) = reduction {
                    states[index] = newState
                    observers.forEach { $0.newState(state: newState, reason: .modified) }
                } else if case let .modified2(newState, reason) = reduction {
                    states[index] = newState
                    observers.forEach { $0.newState(state: newState, reason: reason) }
                }
            }
        }
    }

    func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) -> UUID {
        let any = AnyObserver<S>(priority, observer)
        observers.append(any)
        observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
        states.forEach { state in
            observer(state, .subscribed)
        }
        return any.uuid
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
    }
    
    private var states: [S] = []
    private var reducers: [AnyReducer<S>] = []
    private var observers: [AnyObserver<S>] = []
}

extension Storage: CustomStringConvertible {
    public var description: String {
        return "\(type(of: self)): \(states.count) states, \(reducers.count) reducers, \(observers.count) observers"
    }
}

