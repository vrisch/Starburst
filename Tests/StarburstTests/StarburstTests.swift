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
    globalReducerCount += 1
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
    globalObserverCount += 1
    globalCounter = state.counter
}

var mainStore = Store()
var globalCounter = 0
var globalObserverCount = 0
var globalReducerCount = 0

class StarburstTests: XCTestCase {
    
    override func setUp() {
        mainStore.reset()
        globalCounter = 0
        globalObserverCount = 0
        globalReducerCount = 0
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
        mainStore.dispatch(CounterAction.increase) // Should have no effect since store is reset
        XCTAssertEqual(globalCounter, 2)
        XCTAssertEqual(globalObserverCount, 3)

        XCTAssertEqual(globalReducerCount, 3)
    }
    
    func testReorderingRSO() {
        let state = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(reducer: counterReducer),
            mainStore.add(state: state),
            mainStore.subscribe(observer: counterObserver),
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)

        XCTAssertEqual(globalReducerCount, 1)
    }

    func testReorderingROS() {
        let state = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(state: state),
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)

        XCTAssertEqual(globalReducerCount, 1)
    }

    func testReorderingORS() {
        let state = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(reducer: counterReducer),
            mainStore.add(state: state),
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)

        XCTAssertEqual(globalReducerCount, 1)
    }

    func testReorderingOSR() {
        let state = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.subscribe(observer: counterObserver),
            mainStore.add(state: state),
            mainStore.add(reducer: counterReducer),
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)

        XCTAssertEqual(globalReducerCount, 1)
    }

    func testMultipleStates() {
        let state1 = CounterState()
        let state2 = CounterState()
        let tokens = Tokens()
        tokens.once {[
            mainStore.add(reducer: counterReducer),
            mainStore.subscribe(observer: counterObserver),
            ]}
        tokens.always {[
            mainStore.add(state: state1),
            mainStore.add(state: state2),
            ]}
        XCTAssertEqual(globalCounter, 0)
        mainStore.dispatch(CounterAction.increase)
        XCTAssertEqual(globalCounter, 1)

        XCTAssertEqual(globalReducerCount, 2)
    }

    static var allTests = [
        ("testImmutability", testImmutability),
        ("testMutability", testMutability),
        ("testReorderingRSO", testReorderingRSO),
        ("testReorderingROS", testReorderingROS),
        ("testReorderingORS", testReorderingORS),
        ("testReorderingOSR", testReorderingOSR),
    ]
}
