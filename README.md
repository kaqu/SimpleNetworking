# SimpleNetworking

Simple swift networking returning promises instead of just getting callbacks

Swift 4 required!

## Sample usage

```swift
import SimpleNetworking

extension String : Error {}

// get all certs in given bundle - default is main - set regex for m atching host names
let certificatesForPinning = PinningCertificateContainer(for: ["(.)*google\\.com"])

// create netwoking instance - holding session and providing connection security
var networking = Networking()//withTrustedServerCertificates: [certificatesForPinning])

// call network task - returns promise of response
let responsePromise = networking.perform(.get(from: "https://www.google.com"))

// transform promise to gather different data type from response - transformation can fail returning error
let networkResponsePromise = responsePromise.transform { response in
    return .success(with: response.response)
}

// asynchronous - called when promise fulfilled - need to manually switch queue if required, default is main
networkResponsePromise.fulfillmentHandler { response in
    print(response.statusCode)
}

// asynchronous - called when promise failed - need to manually switch queue if required, default is main
networkResponsePromise.failureHandler { error in
    print(error)
}

// synchronous - locking thread until promise fulfilled or failed, then returns optional value - nil if failed
// be sure if not waiting on same queue as provided in networking.perform othrvise can cause deadlocks
let value = networkResponsePromise.value


// define service enum with given services to perform quick and clean service calls
enum SampleService {
    case mainSite
    case downloadData
}

// conform to service protocol to define all needed data
extension SampleService : NetworkService {
    
    var path: String {
        switch self {
        case .mainSite:
            return ""
        case .downloadData:
            return "bytes/102400"
        }
    }
    
    var task: NetworkEndpoint.Task {
        switch self {
        case .mainSite:
            return .get
        case .downloadData:
            return .download(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.data"))
        }
    }
    
    var headers: NetworkRequest.Headers {
        return [:]
    }
}

// define endpoint - set session, endpoint url and easily call services, one service can be called on many endpoints if needed
let testEndpoint = NetworkEndpoint(at:"https://httpbin.org/")

// call service on endpoint using different queue
DispatchQueue.global(qos: .background).async {
    // than wait on that queue until response
    guard let responseValue = testEndpoint.call(SampleService.mainSite).value else {
        return
    }
    // and use its value if any
    print(responseValue)
}

// simple call service with endpoint, define response queue if needed
testEndpoint.call(SampleService.downloadData)
// transform promise to promise with different type - transform called on queue provided when calling service
.transform { (response) -> (FailablePromise<Int>.TransformationResult) in
    if let data = response.data {
        return .success(with: data.count)
    } else {
        return .failure(reason: "No data")
    }
}
// asynchronously gather progress - responding on given queue
.progressHandler(on: .global(qos: .background)) { progress in
    print("Download progress \(progress)")
}
// asynchronously gather response when completed - responding on given queue
.fulfillmentHandler(on: .global(qos: .userInteractive)) { dataSize in
    print("Download completed \(dataSize)")
}
// or asynchronously gather error - responding on default queue - main
.failureHandler { error in
    print("Download error \(error)")
}
// at the end wait until result is available
.value

```

Fastest way to use by
```bash
git clone git@github.com:kaqu/SimpleNetworking.git
```
or
```bash
git submodule add git@github.com:kaqu/SimpleNetworking.git
```
in existing git repository.
