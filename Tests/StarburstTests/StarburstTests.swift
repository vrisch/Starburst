//
//  StarburstTests.swift
//  Starburst
//
//  Created by Vrisch on {TODAY}.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import XCTest
import Starburst

enum CounterAction: Action {
    case increase
    case decrease
    case nothing
}

struct CounterState: State {
    typealias A = CounterAction
    
    var counter: Int = 0
}

func counterReducer(_ state: inout CounterState, _ action: CounterAction) -> Reduction<CounterState> {
    switch action {
    case .increase:
        state.counter += 1
        return .modified(state)
    case .decrease:
        state.counter -= 1
        return .modified(state)
    case .nothing:
        return .unmodified
    }
}

func counterObserver(_ state: CounterState) {
    globalCounter = state.counter
    globalObserverCount += 1
}

var mainStore = Store()
var globalCounter = 0
var globalObserverCount = 0

class StarburstTests: XCTestCase {
    
    override func setUp() {
        mainStore.reset()
        globalCounter = 0
        globalObserverCount = 0
    }

    func testImmutability() {
        let state = CounterState()
        mainStore.add(state: state)
        mainStore.add(reducer: counterReducer)
        XCTAssertEqual(state.counter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(state.counter, 0)
    }
    
    func testMutability() {
        mainStore.add(state: CounterState())
        mainStore.add(reducer: counterReducer)
        mainStore.subscribe(observer: counterObserver)
        mainStore.dispatch(CounterAction.increase)
        mainStore.dispatch(CounterAction.increase)
        mainStore.dispatch(CounterAction.nothing)
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3) // Subscribe + 2 .increase actions

        mainStore.reset()
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3)
    }
    
    static var allTests = [
        ("testImmutability", testImmutability),
        ("testMutability", testMutability),
    ]
}
