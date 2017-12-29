//
//  Internals.swift
//  Starburst
//
//  Created by Magnus on 2017-07-22.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import Orbit

extension Store {
    
    func remove(state: StateBox) {
        if let idx = states.index(of: state) {
            states.remove(at: idx)
        }
    }
    
    func remove(reducer: ReducerBox) {
        if let idx = reducers.index(of: reducer) {
            reducers.remove(at: idx)
        }
    }
    
    func remove(observer: ObserverBox) {
        if let idx = observers.index(of: observer) {
            observers.remove(at: idx)
        }
    }
}

struct Box {
    init<T>(value: T) {
        self.value = value
    }
    
    mutating func wrap<T>(value: T) {
        self.value = value
    }
    
    func unwrap<T>() -> T? {
        return value as? T
    }
    
    private var value: Any
}

final class ReducerBox {
    let uuid = UUID()
    
    init<A: Action>(reducer: Reducer<A>) {
        box = Box(value: reducer)
    }
    
    func apply<A: Action>(state: inout A.S, action: A, modified: (A.S) throws -> Void) throws {
        guard let reducer: Reducer<A> = box.unwrap() else { return }
        if case let .modified(newState) = try reducer(&state, action) {
            try modified(newState)
        }
    }
    
    private let box: Box
}

final class StateBox {
    let uuid = UUID()
    
    init<S: State>(state: S) {
        box = Box(value: state)
    }
    
    func apply<A: Action>(action: A, reducers: [ReducerBox], observers: [ObserverBox]) throws {
        for reducer in reducers {
            if var state : A.S = box.unwrap() {
                try reducer.apply(state: &state, action: action) { newState in
                    box.wrap(value: newState)
                    try observers.forEach { try $0.apply(state: newState, reason: .modified) }
                }
            }
        }
    }
    
    func apply<S: State>(observer: Observer<S>) throws {
        guard let state: S = box.unwrap() else { return }
        try observer(state, .subscribed)
    }
    
    private var box: Box
}

final class ObserverBox {
    let priority: Priority
    let uuid = UUID()
    
    init<S: State>(priority: Priority, observer: Observer<S>) {
        self.priority = priority
        box = Box(value: observer)
    }
    
    func apply<S: State>(state: S, reason: Reason) throws {
        guard let observer: Observer<S> = box.unwrap() else { return }
        try observer(state, reason)
    }
    
    func apply<S: State>(state: S) throws {
        guard let observer: Observer<S> = box.unwrap() else { return }
        try observer(state, .subscribed)
    }
    
    private var box: Box
}

extension ReducerBox: Equatable {
    
    static func ==(lhs: ReducerBox, rhs: ReducerBox) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
}

extension StateBox: Equatable {
    
    static func ==(lhs: StateBox, rhs: StateBox) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
}

extension ObserverBox: Equatable {
    
    static func ==(lhs: ObserverBox, rhs: ObserverBox) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
}

/*
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
 
 func add(state: S) -> Disposables
 func add(reducer: @escaping Reducer<S>) -> Disposables
 func dispatch(_ action: S.A) throws
 func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposables
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
 
 func add<S>(state: S) -> Disposables? {
 return addStateBox(state)
 }
 
 func add<S>(reducer: @escaping Reducer<S>) -> Disposables? {
 return addReducerBox(AnyReducer<S>(reducer))
 }
 
 func dispatch(_ action: Action) throws {
 try dispatchBox(action)
 }
 
 func subscribe<S: State>(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposables? {
 return try subscribeBox(AnyObserver<S>(priority, observer))
 }
 
 private let countBox: () -> Int
 private let descriptionBox: () -> String
 private let addStateBox: (Any) -> Disposables?
 private let addReducerBox: (Any) -> Disposables?
 private let dispatchBox: (Action) throws -> Void
 private let subscribeBox: (Any) throws -> Disposables?
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
 
 func add(state: S) -> Disposables {
 let any = AnyState<S>(state)
 states.append(any)
 return Disposables(block: { self.unsubscribe(uuid: any.uuid) })
 }
 
 func add(reducer: @escaping Reducer<S>) -> Disposables {
 let any = AnyReducer<S>(reducer)
 reducers.append(any)
 return Disposables(block: { self.unsubscribe(uuid: any.uuid) })
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
 
 func subscribe(_ priority: Priority, _ observer: @escaping Observer<S>) throws -> Disposables {
 let any = AnyObserver<S>(priority, observer)
 observers.append(any)
 observers.sort(by: { $0.priority.rawValue < $1.priority.rawValue })
 try states.forEach { state in
 try observer(state.state, .subscribed)
 }
 return Disposables(block: { self.unsubscribe(uuid: any.uuid) })
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
 */
