//
//  Extras.swift
//  Starburst
//
//  Created by Magnus on 2017-10-14.
//  Copyright © 2017 Starburst. All rights reserved.
//

public extension Reason {
    public var isSubscribed: Bool {
        guard case .subscribed = self else { return false }
        return true
    }
    public var isModified: Bool {
        guard case .modified = self else { return false }
        return true
    }
}

extension Reason: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .subscribed: return "subscribed"
        case .modified: return "modified"
        }
    }
}

extension Store: CustomStringConvertible {

    public var description: String {
        var result = "\(type(of: self)): {\n"
        states.forEach { result.append("\($0)\n") }
        reducers.forEach { result.append("\($0)\n") }
        observers.forEach { result.append("\($0)\n") }
        result.append("}")
        return result
    }
}

