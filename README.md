# SimpleNetworking

Simple swift networking returning promises instead of just getting callbacks

## Sample usage

```swift
extension String : Error {}

// get all certs in given bundle - default is main
let certificatesForPinning = CertificateContainer()

// create netwoking instance - holding session and providing connection security
var networking = Networking(withTrustedServerCertificates: ["www.google.pl":certificatesForPinning])

// call network task - returns promise of response
let responsePromise = networking.perform(.get(from: "https://www.google.pl"))

// transform promise to gather different data type from response - transformation can fail returning error
let networkResponsePromise = responsePromise.transform { response in
    return .success(with: response.response)
}

// asynchronus - called when promise fulfilled - need to manually switch queue if required
networkResponsePromise.fulfillHandler = { response in
    DispatchQueue.main.async {
        print(response)
    }
}

// asynchronus - called when promise failed - need to manually switch queue if required
networkResponsePromise.failureHandler = { error in
    DispatchQueue.main.async {
        print(error)
    }
}

// synchronus - locking thread until promise fulfilled or failed, then returns optional value - nil if failed
let value = networkResponsePromise.value

let networkRequestHeaders = ["someHeader":"headerValue"]
let requestData = Data()

// post data to network, can specify on which queue response wuold be held (including all promises) - rest same as above
let postResponsePromise = networking.perform(.post(data: requestData, type: .json(encoded: .utf8), to: "https://www.google.pl"), with: networkRequestHeaders, respondingOn: .main)

// response performed on main thread will cause deadlock here because getting value blocks thread called on - so calling on other thread
DispatchQueue.global(qos: .background).async {
    print(postResponsePromise.value)
    PlaygroundPage.current.finishExecution() // just to complete all
}
```
