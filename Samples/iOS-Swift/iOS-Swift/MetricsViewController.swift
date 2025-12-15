import Sentry
import UIKit

class MetricsViewController: UIViewController {

    // MARK: - Interface Builder Outlets

    @IBOutlet weak var counterTextField: UITextField!
    @IBOutlet weak var distributionTextField: UITextField!
    @IBOutlet weak var gaugeTextField: UITextField!

    // MARK: - Interface Builder Actions

    @IBAction func addCountAction(_ sender: UIButton) {
        guard let value = Int(counterTextField.text ?? "0") else { return }
        // Example using Attributable protocol - all types with both constants and literals
        // Scalar types
        let endpoint = "api/users" // String constant
        let success = true // Boolean constant
        let statusCode = 200 // Integer constant
        let responseTime = 123.45 // Double constant
        
        // Array types
        let tags = ["production", "v2", "api"] // String array constant
        let flags = [true, false, true] // Boolean array constant
        let statusCodes = [200, 201, 404] // Integer array constant
        let latencies = [12.3, 45.6, 78.9] // Double array constant
        
        SentrySDK.metrics.count(
            key: "sample.counter",
            value: value,
            unit: "request",
            attributes: [
                // Scalar types - using constants
                "endpoint": endpoint, // String
                "success": success, // Boolean
                "status_code": statusCode, // Integer
                "response_time": responseTime, // Double
                // Scalar types - using literals
                "method": "GET", // String literal
                "cached": false, // Boolean literal
                "retry_count": 3, // Integer literal
                "cache_hit_rate": 0.95, // Double literal
                // Array types - using constants
                "tags": tags, // String array
                "flags": flags, // Boolean array
                "status_codes": statusCodes, // Integer array
                "latencies": latencies, // Double array
                // Array types - using literals
                "environments": ["prod", "staging"], // String array literal
                "features": [true, false], // Boolean array literal
                "ports": [80, 443, 8_080], // Integer array literal
                "percentages": [0.1, 0.5, 0.9] // Double array literal
            ]
        )
    }

    @IBAction func addDistributionAction(_ sender: UIButton) {
        guard let value = Double(distributionTextField.text ?? "0") else { return }
        // Example using Attributable protocol - all types with both constants and literals
        // Scalar types
        let operation = "database_query" // String constant
        let cacheHit = false // Boolean constant
        let queryCount = 42 // Integer constant
        let queryTime = 3.14159 // Double constant
        
        // Array types
        let operations = ["select", "insert", "update"] // String array constant
        let cacheHits = [true, false, true] // Boolean array constant
        let queryCounts = [10, 20, 30] // Integer array constant
        let queryTimes = [1.2, 3.4, 5.6] // Double array constant
        
        SentrySDK.metrics.distribution(
            key: "sample.distribution",
            value: value,
            unit: "millisecond",
            attributes: [
                // Scalar types - using constants
                "operation": operation, // String
                "cache_hit": cacheHit, // Boolean
                "query_count": queryCount, // Integer
                "query_time": queryTime, // Double
                // Scalar types - using literals
                "database": "postgres", // String literal
                "indexed": true, // Boolean literal
                "row_count": 1_000, // Integer literal
                "avg_time": 2.71828, // Double literal
                // Array types - using constants
                "operations": operations, // String array
                "cache_hits": cacheHits, // Boolean array
                "query_counts": queryCounts, // Integer array
                "query_times": queryTimes, // Double array
                // Array types - using literals
                "tables": ["users", "orders"], // String array literal
                "indexed_tables": [true, false], // Boolean array literal
                "row_counts": [100, 200, 300], // Integer array literal
                "avg_times": [1.1, 2.2, 3.3] // Double array literal
            ]
        )
    }

    @IBAction func addGaugeAction(_ sender: UIButton) {
        guard let value = Double(gaugeTextField.text ?? "0") else { return }
        // Example using Attributable protocol - all types with both constants and literals
        // Scalar types
        let pool = "main" // String constant
        let active = true // Boolean constant
        let maxConnections = 100 // Integer constant
        let connectionRate = 0.85 // Double constant
        
        // Array types
        let pools = ["main", "secondary", "cache"] // String array constant
        let activeStates = [true, false, true] // Boolean array constant
        let maxConnectionsList = [100, 200, 50] // Integer array constant
        let connectionRates = [0.8, 0.9, 0.7] // Double array constant
        
        SentrySDK.metrics.gauge(
            key: "sample.gauge",
            value: value,
            unit: "connection",
            attributes: [
                // Scalar types - using constants
                "pool": pool, // String
                "active": active, // Boolean
                "max_connections": maxConnections, // Integer
                "connection_rate": connectionRate, // Double
                // Scalar types - using literals
                "region": "us-east", // String literal
                "compressed": false, // Boolean literal
                "timeout": 30, // Integer literal
                "utilization": 0.75, // Double literal
                // Array types - using constants
                "pools": pools, // String array
                "active_states": activeStates, // Boolean array
                "max_connections_list": maxConnectionsList, // Integer array
                "connection_rates": connectionRates, // Double array
                // Array types - using literals
                "regions": ["us-east", "us-west"], // String array literal
                "compressed_states": [true, false], // Boolean array literal
                "timeouts": [30, 60, 90], // Integer array literal
                "utilizations": [0.7, 0.8, 0.9] // Double array literal
            ]
        )
    }
}
