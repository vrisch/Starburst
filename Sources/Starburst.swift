//
//  Starburst.swift
//  Starburst
//
//  Created by Magnus Nilsson on 2017-03-11.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import Orbit

public protocol State {
    associatedtype A: Action
}

public protocol Action {}

public protocol CustomReason: CustomStringConvertible {}
public enum Reason {
    
    case subscribed
    case modified
    case custom(CustomReason)
}

public extension Reason {
    public var isSubscribed: Bool {
        guard case .subscribed = self else { return false }
        return true
    }
    public var isModified: Bool {
        guard case .modified = self else { return false }
        return true
    }
    public var custom: CustomReason? {
        guard case let .custom(customReason) = self else { return nil }
        return customReason
    }
}

public enum Reduction<S: State> {
    case unmodified
    case modified(newState: S)
    case modified2(newState: S, reason: Reason)
}

public typealias Reducer<S: State> = (_ state: inout S, _ action: S.A) throws -> Reduction<S>

public typealias Observer<S: State> = (_ state: S, _ reason: Reason) throws -> Void

public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}

public final class Store {
    
    public var count: Int {
        var result = 0
        shelves.forEach { result += $0.count }
        return result
    }
    
    public init() { }
    
    public func add<S: State>(state: S) -> Disposables {
        var disposables = Disposables()
        do {
            shelves.forEach {
                $0.add(state: state).flatMap { disposables += $0 }
            }
            if disposables.isEmpty {
                try disposables += add(state: state, reducer: nil, observer: nil)
            }
        } catch {
        }
        return disposables
    }
    
    public func add<S>(reducer: @escaping Reducer<S>) -> Disposables {
        var disposables = Disposables()
        do {
            shelves.forEach {
                $0.add(reducer: reducer).flatMap { disposables += $0 }
            }
            if disposables.isEmpty {
                try disposables += add(state: nil, reducer: reducer, observer: nil)
            }
        } catch {
        }
        return disposables
    }
    
    public func dispatch(_ action: Action) throws {
        try shelves.forEach { try $0.dispatch(action) }
    }
    
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Disposables {
        var disposables = Disposables()
        do {
            try shelves.forEach {
                try $0.subscribe(priority, observer).flatMap { disposables += $0 }
            }
            if disposables.isEmpty {
                try disposables += add(state: nil, reducer: nil, priority: priority, observer: observer)
            }
        } catch {
        }
        return disposables
    }
    
    private var shelves: [AnyShelf] = []
}

extension Store: CustomStringConvertible {
    
    public var description: String {
        var result = "\(type(of: self)): {\n"
        shelves.forEach { result.append("\($0)\n") }
        result.append("}")
        return result
    }
}

private extension Store {
    
    private func unsubscribe(uuid: UUID) {
        shelves.enumerated().forEach { let (index, any) = $0
            if any.uuid == uuid {
                shelves.remove(at: index)
            }
        }
    }
    
    private func add<S>(state: S?, reducer: Reducer<S>?, priority: Priority = .normal, observer: Observer<S>?) throws -> Disposables {
        var disposables = Disposables()

        let any = AnyShelf(Storage<S>())
        shelves.append(any)
        disposables += Disposables(block: { self.unsubscribe(uuid: any.uuid) })

        if let state = state {
            any.add(state: state).flatMap { disposables += $0 }
        }
        if let reducer = reducer {
            any.add(reducer: reducer).flatMap { disposables += $0 }
        }
        if let observer = observer {
            try any.subscribe(priority, observer).flatMap { disposables += $0 }
        }
        
        return disposables
    }
}
