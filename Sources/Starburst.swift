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

public protocol CustomReason: CustomStringConvertible {}
public enum Reason {
    
    case subscribed
    case modified
    case custom(CustomReason)
    
    public var isSubscribed: Bool {
        guard case .subscribed = self else { return false }
        return true
    }
}

public enum Reduction<S: State> {
    case unmodified
    case modified(newState: S)
    case modified2(newState: S, reason: Reason)
}

public typealias Reducer<S: State> = (_ state: inout S, _ action: S.A) -> Reduction<S>

public typealias Observer<S: State> = (_ state: S, _ reason: Reason) -> Void

public final class Token {
    let uuid: UUID
    var store: Store
    
    init(uuid: UUID, store: Store) {
        self.uuid = uuid
        self.store = store
    }
    deinit {
        store.unsubscribe(token: self)
    }
}

public enum Priority: Int {
    case high = 0
    case normal = 20
    case low = 50
}

public struct Store {
    private var shelves: [AnyShelf] = []
    
    public init() { }
    
    public mutating func add<S: State>(state: S) -> Tokens {
        let tokens = Tokens()
        let any = AnyShelf(Storage<S>(states: [state]))
        shelves.append(any)
        tokens.tokens.append(Token(uuid: any.uuid, store: self))
        return tokens
    }
    
    public func add<S>(reducer: @escaping Reducer<S>) -> Tokens {
        let tokens = Tokens()
        shelves.forEach {
            if let uuid = $0.add(reducer: reducer) {
                tokens.tokens.append(Token(uuid: uuid, store: self))
            }
        }
        return tokens
    }
    
    public func dispatch(_ action: Action) {
        shelves.forEach { $0.dispatch(action) }
    }
    
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Tokens {
        let tokens = Tokens()
        shelves.forEach {
            if let uuid = $0.subscribe(priority, observer) {
                tokens.tokens.append(Token(uuid: uuid, store: self))
            }
        }
        return tokens
    }
    
    public mutating func unsubscribe(token: Token?) {
        if let token = token {
            shelves.forEach { $0.unsubscribe(uuid: token.uuid) }
            shelves.enumerated().forEach { let (index, any) = $0
                if any.uuid == token.uuid {
                    shelves.remove(at: index)
                }
            }
            print("TOKEN UNSUBSCRIBED")
        }
    }
    
    public mutating func reset() {
        shelves = []
    }
}

public final class Tokens {
    
    public init() { }
    deinit { done() }
    
    public func once(_ subscription: () -> Tokens) {
        once { [subscription()] }
    }
    
    public func once(_ subscriptions: () -> [Tokens]) {
        if count == 0 { subscriptions().forEach { tokens += $0.tokens } }
        count += 1
    }
    
    public func done() {
        count -= 1
        if count == 0 { tokens.removeAll() }
    }
    
    fileprivate var tokens: [Token] = []
    private var count = 0
}
