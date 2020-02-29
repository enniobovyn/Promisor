# Promisor

[![CI Status](https://img.shields.io/travis/enniobovyn/Promisor.svg?style=flat)](https://travis-ci.org/enniobovyn/Promisor)
[![Version](https://img.shields.io/cocoapods/v/Promisor.svg?style=flat)](https://cocoapods.org/pods/Promisor)
[![License](https://img.shields.io/cocoapods/l/Promisor.svg?style=flat)](https://cocoapods.org/pods/Promisor)
[![Platform](https://img.shields.io/cocoapods/p/Promisor.svg?style=flat)](https://cocoapods.org/pods/Promisor)

Promisor is an implementation of Promise in Swift.

## About Promises

A `Promise` represents the eventual result of an **asynchronous operation**.
Promises are very similar to the promises you make in real life, a promise can either be kept or broken.

### Async Programming: From Callbacks to Promises

Before promises, callback-based APIs were commonly used for asynchronous code. Here's an example:

```swift
// Callback hell
func doSomethingAsync(parameters: [String: Any], completion: @escaping (Response?, Error?) -> ()) {
    validate(parameters) { _, error in
        if let error = error {
            completion(nil, error)
        } else {
            self.queryDB(with: parameters) { dbResult, error in
                if let error = error {
                    completion(nil, error)
                } else if let dbResult = dbResult {
                    self.doServiceCall(dbResult) { response, error in
                        completion(response, error)
                    }
                }
            }
        }
    }
}
```
The specific pattern of using deeply-nested callbacks in this manner is commonly referred to as "callback hell", because it makes the code less readable and hard to maintain.

Now, with promises:
```swift
// Promise
func doSomethingAsync(parameters: [String: Any]) -> Promise<Response> {
    return validate(parameters)
        .then {
            self.queryDB(with: parameters)
        }
        .then { dbResult in
            self.doServiceCall(dbResult)
        }
}
```

## Usage

A `Promise` is an object representing the eventual completion or failure of an asynchronous operation.

Essentially, a promise is a returned object to which you attach handlers (aka callbacks), instead of passing handlers into a function.

Imagine a function, `createAudioFileAsync()`, which asynchronously generates a sound file given a configuration record and two handler functions, one called if the audio file is successfully created, and the other called if an error occurs.

Here's some code that uses `createAudioFileAsync()`:

```swift
func handleSuccess(url: URL) {
    print("Audio file ready at URL:", url)
}

func handleFailure(error: Error) {
    print("Error generating audio file:", error)
}

createAudioFileAsync(settings: audioSettings, successHandler: handleSuccess, failureHandler: handleFailure)
```
...with Promisor you can let functions return a promise you can attach your handlers to instead:

If `createAudioFileAsync()` were rewritten to return a promise, using it could be as simple as this:
```swift
createAudioFileAsync(settings: audioSettings).then(handleSuccess, handleFailure)
```

That's shorthand for:
```swift
let promise = createAudioFileAsync(settings: audioSettings)
promise.then(handleSuccess, handleFailure)
```
We call this an asynchronous function call. This convention has several advantages. We will explore each one.

### Creating a Promise

A Promise can be created from scratch using its initializer.
```swift
let promise = Promise<String> { resolve, reject in
    resolve("Yay, my first promise!")
}
```
You can also use the initializer to wrap a completion handler based API, like `URLSession`.
```swift
let promise = Promise<Data> { resolve, reject in
    session.dataTask(with: request, completionHandler: { data, response, error in
        if let error = error {
            reject(error)
        } else if let data = data {
            resolve(data)
        } else {
            fatalError()
        }
    }).resume()
}
```
Basically, the promise initializer takes an executor function that lets us resolve or reject a promise manually.

### Guarantees

Unlike "old-style", passed-in handlers (aka callbacks), a promise comes with some guarantees:

- Handlers added with `then()`, `catch()` and `finally()` will even be called after the completion or failure of the asynchronous operation.

- Multiple handlers may be added by calling `then()`, `catch()` or `finally()` several times. Each handler is executed one after another, in the order in which they were inserted.

One of the great things about using promises is **chaining**.

### Chaining

A common need is to execute two or more asynchronous operations back to back, where each subsequent operation starts when the previous operation succeeds, with the result from the previous step. We accomplish this by creating a **promise chain**.

Here's the magic: the `then()` function returns a **new promise**, different from the original:
```swift
let promise = doSomething()
let promise2 = promise.then(handleSuccess, handleFailure)
```
or
```swift
let promise2 = doSomething().then(handleSuccess, handleFailure)
```
or
```swift
let promise2 = doSomething()
    .then { value
        handleSuccess(value)
    }
    .catch { error in
        handleFailure(error)
    }
```
This second promise (`promise2`) represents the completion not just of `doSomething()`, but also of the `handleSuccess` or `handleFailure` you passed in, which can be other asynchronous functions returning a promise. When that's the case, any handlers added to `promise2` get queued behind the promise returned by either `handleSuccess` or `handleFailure`.

Basically, each promise represents the completion of another asynchronous step in the chain.

Before, doing several asynchronous operations in a row would lead to the classic callback pyramid of doom:
```swift
doSomething(successHandler: { result in
    doSomethingElse(result, successHandler: { newResult in
        doThirdThing(newResult, successHandler: { finalResult in
            print("Got the final result:", finalResult)
        }, failureHandler: handleFailure)
    }, failureHandler: handleFailure)
}, failureHandler: handleFailure)
```
With promises, we attach our handlers to the returned promises instead, forming a promise chain:
```swift
doSomething()
    .then { result in
        return doSomethingElse(result)
    }
    .then { newResult in
        return doThirdThing(newResult)
    }
    .then { finalResult in
        print("Got the final result:", finalResult)
    }
    .catch(handleFailure)
```

#### Chaining after a failure

It's possible to chain after a failure, with `recover`, which is useful to accomplish new actions even after an action failed in the chain. Read the following example:
```swift
Promise<Void> { resolve, reject in
    print("Initial")

    resolve(())
}
.then {
    throw SomeError()

    print("Do this")
}
.recover { _ -> Promise<Void> in
    print("Do that")

    return doThatOnFailure()
}
.then {
    print("Do this instead")
}
```
This will output the following text, assuming that `doThatOnFailure()` completes successfully:
```
Initial
Do that
Do this instead
```
**Note**: The text "Do this" is not displayed because the `SomeError` error caused a rejection.

### Error propagation

You might recall seeing `handleFailure()` three times in the pyramid of doom earlier, compared to only once at the end of the promise chain:
```swift
doSomething()
    .then { result in doSomethingElse(result) }
    .then { newResult in doThirdThing(newResult) }
    .then { finalResult in print("Got the final result:", finalResult) }
    .catch(handleFailure)
```
Basically, a promise chain stops if there's an exception, looking down the chain for `catch` handlers instead. This is very much modeled after how synchronous code works:
```swift 
do {
    let result = try doSomethingSync()
    let newResult = try doSomethingElseSync(result)
    let finalResult = try doThirdThingSync(newResult)
    print("Got the final result:", finalResult)
} catch {
    handleFailure(error)
}
```

Promises solve a fundamental flaw with the callback pyramid of doom, by catching all errors, even thrown exceptions and programming errors. This is essential for functional composition of asynchronous operations.

### Composition

`Promise.resolve()` and `Promise.reject()` are shortcuts to manually create an already resolved or rejected promise respectively. This can be useful at times.

`Promise.all()` and `Promise.race()` are two composition tools for running asynchronous operations in parallel.

We can start operations in parallel and wait for them all to finish like this:
```swift
Promise.all(books.map { fetchMetadata(for: $0) })
    .then { allMetadata in
        zip(books, allMetadata).forEach { book, metadata in
            print("\(book.title) metadata: \(metadata)")
        }
    }
```

## Installation

Promisor is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Promisor'
```

## Author

Ennio Bovyn, enniobovyn@gmail.com

## License

Promisor is available under the MIT license. See the LICENSE file for more info.
