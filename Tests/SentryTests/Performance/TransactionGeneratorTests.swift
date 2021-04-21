import XCTest

/**
* This isn't an actual test. It creates transactions and sends them to the Sentry, but doesn't verify if they arrive there.
*/
class TransactionGeneratorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = TestConstants.realDSN
            options.maxCacheItems = 100
        }
    }

    func tesGenerateTransactions() {
        transactionWithChildren()
        
        transactionWithErrorAndScope()
        
        peformanceOfTransactions()
    }
    
    private func transactionWithChildren() {
        let transaction = SentrySDK.startTransaction(name: "Generated With Children", operation: "Some Operation")
        
        let search = transaction.startChild(operation: "Search")
        
        delayNonBlocking(timeout: 0.02)
        
        searchSpans(span: search)
        
        delayNonBlocking(timeout: 0.01)
        
        search.finish()
        let checkout = transaction.startChild(operation: "Checkout")
        
        checkoutSpans(span: checkout)
        
        checkout.finish()
        transaction.finish()
    }
    
    private func searchSpans(span: Span) {
        let webSearch = span.startChild(operation: "Web Search")
        let localSearch = span.startChild(operation: "Search in DB")
        
        let google = webSearch.startChild(operation: "Ask Google", description: "I ask Google")
        let bing = webSearch.startChild(operation: "Ask Bing")
        let duck = webSearch.startChild(operation: "Ask DuckDuckGo")
        delayNonBlocking(timeout: 0.001)
        google.finish()
        delayNonBlocking(timeout: 0.001)
        bing.finish()
        duck.finish()
        
        delayNonBlocking(timeout: 0.01)
        
        // Cancel search
        localSearch.finish(status: SentrySpanStatus.cancelled)
        
        let merge = webSearch.startChild(operation: "Merge results")
        
        delayNonBlocking(timeout: 0.04)
        merge.finish(status: SentrySpanStatus.alreadyExists)
        
        webSearch.finish()
    }
    
    private func checkoutSpans(span: Span) {
        let prices = span.startChild(operation: "Load Prices")
        
        delayNonBlocking(timeout: 0.001)
        prices.finish(status: SentrySpanStatus.internalError)
        
        let fixPrices = span.startChild(operation: "Fix Prices")
        fixPrices.setExtra(value: "price 1234", key: "price key")
        fixPrices.finish(status: SentrySpanStatus.failedPrecondition)
        
        let reloadPrices = span.startChild(operation: "Reload Prices")
        delayNonBlocking(timeout: 0.001)
        reloadPrices.finish(status: SentrySpanStatus.aborted)
        
        let getMoney = span.startChild(operation: "Get Money")
        delayNonBlocking(timeout: 0.01)
        
        let moneyService1 = getMoney.startChild(operation: "Money Service 1")
        delayNonBlocking(timeout: 0.001)
        moneyService1.finish()
        
        let moneyService2 = getMoney.startChild(operation: "Money Service 2")
        delayNonBlocking(timeout: 0.001)
        moneyService2.finish()
        
        getMoney.finish(status: SentrySpanStatus.invalidArgument)
    }
    
    private func transactionWithErrorAndScope() {
        let context = TransactionContext(name: "Generated With Error", operation: "Error Operation")
        let errorTransaction = SentrySDK.startTransaction(transactionContext: context, bindToScope: true)
        
        let search = errorTransaction.startChild(operation: "Search")
        
        delayNonBlocking(timeout: 0.02)
        searchSpans(span: search)
        search.finish()
        
        SentrySDK.capture(error: SampleError.awesomeCentaur)
        let child2 = errorTransaction.startChild(operation: "Child 2")
        
        delayNonBlocking(timeout: 0.02)
        
        child2.finish()
        SentrySDK.span?.finish()
    }
    
    private func peformanceOfTransactions() {
        for _ in 0...100 {
            let transaction = SentrySDK.startTransaction(name: "Performance Test", operation: "Load Test")
            for _ in 0...10 {
                let child = transaction.startChild(operation: "Child")
                delayNonBlocking(timeout: 0.000_1)
                child.finish()
            }
            delayNonBlocking(timeout: 0.001)
            transaction.finish()
        }
        
        // Wait to flush out transactions
        delayNonBlocking(timeout: 5)
    }
}
