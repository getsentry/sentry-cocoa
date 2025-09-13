# Sentry Cocoa SDK Testing Guidelines

## Overview

This document outlines the testing patterns and conventions used in the Sentry Cocoa SDK project. All tests should follow these guidelines to maintain consistency and readability across the codebase.

## Test Structure and Organization

### Test Class Organization

```swift
class SentryExampleTests: XCTestCase {
    
    private class Fixture {
        let options: Options
        let client: TestClient
        let event: Event
        let scope: Scope
        
        init() {
            // Initialize test fixtures
            options = Options.noIntegrations()
            options.dsn = TestConstants.dsnAsString(username: "ExampleTests")
            
            client = TestClient(options: options)!
            event = Event()
            scope = Scope()
        }
        
        func getSut() -> SystemUnderTest {
            return SystemUnderTest(options: options, client: client)
        }
    }
    
    private var fixture: Fixture!
    private lazy var sut = fixture.getSut()
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        // Additional setup
    }
    
    override func tearDown() {
        super.tearDown()
        // Cleanup
        clearTestState()
    }
}
```

### Objective-C Test Structure

```objc
@interface SentryExampleTests : XCTestCase
@end

@implementation SentryExampleTests

- (void)setUp {
    [super setUp];
    // Test setup
}

- (void)tearDown {
    // Cleanup
    [super tearDown];
}

- (void)testExample {
    // Test implementation
}

@end
```

## Arrange-Act-Assert Pattern

### Use Clear AAA Structure

All tests should follow the Arrange-Act-Assert pattern with clear visual separation:

```swift
func testSerializeAbormalMechanism() {
    // Arrange
    let session = SentrySession(releaseName: "1.0.0", distinctId: "distinctId")
    session.abnormalMechanism = "app hang"
    
    // Act
    let jsonDict = session.serialize()
    
    // Assert
    XCTAssertEqual(session.abnormalMechanism, jsonDict["abnormal_mechanism"] as? String)
}
```

### Objective-C AAA Pattern

```objc
- (void)testSerializeNSData {
    // Arrange
    NSURL *tempDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *tempFileURL = [tempDirectoryURL URLByAppendingPathComponent:@"test.dat"];
    NSDictionary<NSString *, id<SentryStreamable>> *dictionary = @{
        @"key1" : [@"Data 1" dataUsingEncoding:NSUTF8StringEncoding],
        @"key2" : [@"Data 2" dataUsingEncoding:NSUTF8StringEncoding]
    };
    
    // Act
    BOOL result = [SentryMsgPackSerializer serializeDictionaryToMessagePack:dictionary
                                                                   intoFile:tempFileURL];
    
    // Assert
    XCTAssertTrue(result);
    NSData *tempFile = [NSData dataWithContentsOfURL:tempFileURL];
    [self assertMsgPack:tempFile];
    
    // Cleanup
    [[NSFileManager defaultManager] removeItemAtURL:tempFileURL error:nil];
}
```

## Test Method Naming

### Swift Test Naming

- Use descriptive, behavior-focused names
- Format: `test<MethodUnderTest>_<Scenario>_<ExpectedBehavior>`
- Examples:
  ```swift
  func testPublicInit_WithOperation_shouldMatchExpectedContext()
  func testSerializeAbormalMechanism_IfNil_NotAddedToDict()
  func testInitWithJson_IfJsonMissesField_SessionIsNil()
  ```

### Objective-C Test Naming

- Use descriptive camelCase names
- Start with `test` prefix
- Examples:
  ```objc
  - (void)testSerializeNSData
  - (void)testSerializeInvalidFile
  - (void)testSharedClient
  ```

## Fixture Pattern

### Use Fixture Classes for Complex Setup

Create inner `Fixture` classes to encapsulate common test data and setup:

```swift
private class Fixture {
    let options: Options
    let transport: TestTransport
    let dateProvider = TestCurrentDateProvider()
    let random = TestRandom(value: 1.0)
    
    init() throws {
        options = Options()
        options.dsn = TestConstants.dsnAsString(username: "TestClass")
        transport = TestTransport()
        
        // Configure dependencies
        SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
        SentryDependencyContainer.sharedInstance().random = random
    }
    
    func getSut(configureOptions: (Options) -> Void = { _ in }) -> SystemUnderTest {
        configureOptions(options)
        return SystemUnderTest(options: options, transport: transport)
    }
}
```

## Test Data and Mocking

### Use Test Constants

```swift
private static let dsnAsString = TestConstants.dsnAsString(username: "TestClassName")
```

### Mock Objects

- Use `Test` prefixed classes for mocks: `TestTransport`, `TestClient`, `TestCurrentDateProvider`
- Leverage existing test utilities in `SentryTestUtils`

### Test State Management

Always clean up test state:

```swift
override func tearDown() {
    super.tearDown()
    fixture.fileManager.deleteCurrentSession()
    fixture.fileManager.deleteCrashedSession()
    clearTestState()
}
```

## Assertions

### Use Descriptive Assertions

```swift
// Good
XCTAssertEqual(expected.traceId, actual.traceId, "Transaction trace IDs should match")

// Acceptable for simple cases
XCTAssertEqual(expected.traceId, actual.traceId)
```

### Multiple Assertions

When testing complex objects, use helper methods:

```swift
private func assertFullContext(
    context: TransactionContext,
    expectedParentSpanId: SentrySpanId?,
    expectedTraceId: SentryId = traceID,
    expectedSpanId: SentrySpanId = spanID
) {
    XCTAssertEqual(context.traceId, expectedTraceId)
    XCTAssertEqual(context.spanId, expectedSpanId)
    XCTAssertEqual(context.parentSpanId, expectedParentSpanId)
}
```

## File Organization

### Test Directory Structure

```
Tests/
├── Configuration/
│   └── SentryTests.xcconfig
├── SentryTests/                 # Main test suite
│   ├── Categories/
│   ├── Extensions/
│   ├── Helper/
│   ├── Integrations/
│   ├── Networking/
│   └── [Individual test files]
├── SentryProfilerTests/         # Profiler-specific tests
├── SentrySwiftUITests/         # SwiftUI-specific tests
└── Resources/                  # Test resources and fixtures
```

### Test File Naming

- Swift: `Sentry[Component]Tests.swift`
- Objective-C: `Sentry[Component]Tests.m`
- Test utilities: `Test[Component].swift/.m`

## Common Patterns

### Async Testing

```swift
func testAsyncOperation() async {
    // Arrange
    let expectation = XCTestExpectation(description: "Async operation completes")
    
    // Act
    await sut.performAsyncOperation { result in
        // Assert
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 1.0)
}
```

### Error Testing

```swift
func testMethodThrowsError() {
    // Arrange
    let invalidInput = "invalid"
    
    // Act & Assert
    XCTAssertThrowsError(try sut.processInput(invalidInput)) { error in
        XCTAssertTrue(error is ValidationError)
    }
}
```

### Testing with Options

```swift
func testWithCustomOptions() {
    // Arrange
    let sut = fixture.getSut { options in
        options.debug = true
        options.maxBreadcrumbs = 50
    }
    
    // Act & Assert
    // Test implementation
}
```

## Best Practices

1. **One test, one behavior** - Each test should verify a single behavior
2. **Independent tests** - Tests should not depend on each other
3. **Clear arrange phase** - Set up all necessary preconditions
4. **Minimal act phase** - Execute only the behavior being tested
5. **Comprehensive assert phase** - Verify all expected outcomes
6. **Clean teardown** - Always clean up resources and test state
7. **Use meaningful test data** - Avoid magic numbers and strings
8. **Test edge cases** - Include boundary conditions and error scenarios
9. **Keep tests focused** - Avoid testing implementation details
10. **Use descriptive names** - Test names should explain what is being tested

## Anti-Patterns to Avoid

- ❌ Testing multiple behaviors in one test
- ❌ Tests that depend on execution order
- ❌ Hardcoded test data without explanation
- ❌ Testing private implementation details
- ❌ Overly complex test setup
- ❌ Missing cleanup in tearDown
- ❌ Unclear or missing assertions
- ❌ Tests without clear AAA structure