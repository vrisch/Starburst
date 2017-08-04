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

func counterReducer(state: inout CounterState, action: CounterAction) -> Reduction<CounterState> {
    switch action {
    case .increase:
        state.counter += 1
        return .modified(newState: state)
    case .decrease:
        state.counter -= 1
        return .modified(newState: state)
    case .nothing:
        return .unmodified
    }
}

func counterObserver(state: CounterState, reason: Reason) {
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
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(state: state),
            mainStore.add(reducer: counterReducer)
            ]}
        XCTAssertEqual(state.counter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(state.counter, 0)
    }
    
    func testMutability() {
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(state: CounterState()),
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver)
            ]}
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
    
    func testReordering1() {
        let state = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(reducer: counterReducer),
            mainStore.add(state: state),
            mainStore.subscribe(observer: counterObserver)
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)
    }

    static var allTests = [
        ("testImmutability", testImmutability),
        ("testMutability", testMutability),
        ("testReordering1", testReordering1),
    ]
}
