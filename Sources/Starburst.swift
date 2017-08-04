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
    
    public mutating func add<S: State>(state: S) -> Token {
        let any = AnyShelf(Storage<S>(state: state))
        shelves.append(any)
        return Token(uuid: any.uuid, store: self)
    }
    
    public func add<S>(reducer: @escaping Reducer<S>) -> Token {
        var token: Token? = nil
        shelves.forEach {
            if let uuid = $0.add(reducer: reducer) {
                token = Token(uuid: uuid, store: self)
            }
        }
        return token!
    }
    
    public func dispatch(_ action: Action) {
        shelves.forEach { $0.dispatch(action) }
    }
    
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Token {
        var token: Token? = nil
        shelves.forEach {
            if let uuid = $0.subscribe(priority, observer) {
                token = Token(uuid: uuid, store: self)
            }
        }
        return token!
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

    public func once(_ subscription: () -> Token) {
        once { [subscription()] }
    }
    
    public func once(_ subscriptions: () -> [Token]) {
        if count == 0 { tokens += subscriptions() }
        count += 1
    }
    
    public func always(_ subscription: () -> Token) {
        always { [subscription()] }
    }

    public func always(_ subscriptions: () -> [Token]) {
        tokens += subscriptions()
        count += 1
    }

    public func done() {
        count -= 1
        if count == 0 { tokens.removeAll() }
    }

    private var tokens: [Token] = []
    private var count = 0
}
