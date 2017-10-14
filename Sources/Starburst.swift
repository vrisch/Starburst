//
//  Starburst.swift
//  Starburst
//
//  Created by Magnus Nilsson on 2017-03-11.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import Orbit

public protocol State {}
public protocol Action {
    associatedtype S: State
}
public typealias Reducer<A: Action> = (_ state: inout A.S, _ action: A) throws -> Reduction<A.S>
public typealias Observer<S: State> = (_ state: S, _ reason: Reason) throws -> Void

public enum Reason {
    case subscribed
    case modified
}

public enum Reduction<S: State> {
    case unmodified
    case modified(newState: S)
}

public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}

public final class Store {
    
    public var count: Int {
        return states.count + reducers.count + observers.count
    }
    
    public init() { }
    
    public func add<S: State>(state: S) -> Disposables {
        let box = StateBox(state: state)
        states.append(box)
        observers.forEach { try? $0.apply(state: state) }
        return Disposables(block: { self.remove(state: box) })
    }

    public func add<A: Action>(reducer: @escaping Reducer<A>) -> Disposables {
        let box = ReducerBox(reducer: reducer)
        reducers.append(box)
        return Disposables(block: { self.remove(reducer: box) })
    }

    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Disposables {
        let box = ObserverBox(priority: priority, observer: observer)
        observers.append(box)
        observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
        states.forEach { try? $0.apply(observer: observer) }
        return Disposables(block: { self.remove(observer: box) })
    }

    public func dispatch<A: Action>(_ action: A) throws {
        try states.forEach {
            try $0.apply(action: action, reducers: reducers, observers: observers)
        }
    }

    var states: [StateBox] = []
    var reducers: [ReducerBox] = []
    var observers: [ObserverBox] = []
}
