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
    let store: Store

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
    private var spaces: [AnyMutator] = []

    public init() {
    }

    public mutating func add<S: State>(state: S) {
        spaces.append(AnyMutator(Space<S>(state: state)))
    }

    public func add<S>(reducer: @escaping Reducer<S>) {
        spaces.forEach { $0.add(reducer: reducer) }
    }

    public func dispatch(_ action: Action) {
        spaces.forEach { $0.dispatch(action) }
    }

    @discardableResult
    public func subscribe<S: State>(priority: Priority = .normal, observer: @escaping Observer<S>) -> Token? {
        var token: Token? = nil
        spaces.forEach {
            if let uuid = $0.subscribe(priority, observer) {
                token = Token(uuid: uuid, store: self)
            }
        }
        return token
    }

    public func unsubscribe(token: Token?) {
        if let token = token {
            spaces.forEach { $0.unsubscribe(uuid: token.uuid) }
        }
    }

    public mutating func reset() {
        spaces = []
    }
}

