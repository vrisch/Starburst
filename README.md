# Starburst

### Defining states

``` swift
struct StringState: State {
  typealias S = StringState
  let value: String
}

struct IntState: State {
  typealias A = IntAction
  let value: Int
}
```

### Defining actions

``` swift
enum StringAction: Action { case add(String) }

enum IntAction: Action { case add(Int) }
```

### Defining reducers

``` swift
struct StringReducer: Reducer {
  func reduce(state: inout StringState, action: StringAction) -> StringState? {
    switch action {
    case .add(let v): return StringState(value: state.value + v)
    }
  }
}

struct IntReducer: Reducer {
  func reduce(state: inout IntState, action: IntAction) -> IntState? {
    switch action {
    case .add(let v): return IntState(value: state.value + v)
    }
  }
}
```

### Defining observers

``` swift
struct StringObserver: Observer {
  let token: Observer.Token = UUID()
  func newState(_ state: StringState) {
    print("New state is \(state.value)")
  }
}

struct IntObserver: Observer {
  let token: Observer.Token = UUID()
  func newState(_ state: IntState) {
    print("New state is \(state.value)")
  }
}
```

### Defining a store and dispatch actions

``` swift
var store = Store()

store.add(state: StringState(value: "Hello"))
store.add(state: IntState(value: 1))

store.add(reducer: StringReducer())
store.add(reducer: IntReducer())

store.subscribe(stringObserver)
store.subscribe(intObserver)

store.dispatch(StringAction.add(" world"))
store.dispatch(IntAction.add(4))

store.unsubscribe(intObserver)
store.dispatch(IntAction.add(5))
```
