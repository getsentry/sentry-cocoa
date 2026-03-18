// swiftlint:disable missing_docs
import Foundation

/// Used to transform an NSPredicate into a human-friendly string.
/// This class is used for CoreData and omits variable values
/// and doesn't convert CoreData unsupported instructions.
@objc
@_spi(Private) public final class SentryPredicateDescriptor: NSObject {

    @objc
    public func predicateDescription(_ predicate: NSPredicate) -> String {
        if let compound = predicate as? NSCompoundPredicate {
            return compoundPredicateDescription(compound)
        }
        if let comparison = predicate as? NSComparisonPredicate {
            return comparisonPredicateDescription(comparison)
        }
        return "<UNKNOWN PREDICATE>"
    }

    private func compoundPredicateDescription(_ predicate: NSCompoundPredicate) -> String {
        var expressions: [String] = []

        for sub in predicate.subpredicates {
            if let subPredicate = sub as? NSPredicate {
                if subPredicate is NSCompoundPredicate {
                    expressions.append("(\(predicateDescription(subPredicate)))")
                } else {
                    expressions.append(predicateDescription(subPredicate))
                }
            }
        }

        if expressions.count == 1 {
            return "\(compoundPredicateTypeDescription(predicate.compoundPredicateType)) \(expressions.first ?? "")"
        }

        return expressions.joined(separator: compoundPredicateTypeDescription(predicate.compoundPredicateType))
    }

    private func comparisonPredicateDescription(_ predicate: NSComparisonPredicate) -> String {
        guard let op = predicateOperatorTypeDescription(predicate.predicateOperatorType) else {
            return "<COMPARISON NOT SUPPORTED>"
        }

        return "\(expressionDescription(predicate.leftExpression)) \(op) \(expressionDescription(predicate.rightExpression))"
    }

    private func expressionDescription(_ expression: NSExpression) -> String {
        switch expression.expressionType {
        case .constantValue:
            return "%@"
        case .aggregate:
            guard let collection = expression.collection as? [Any] else {
                return "%@"
            }
            let items = collection.map { obj -> String in
                if let expr = obj as? NSExpression {
                    return expressionDescription(expr)
                }
                return "%@"
            }
            return "{\(items.joined(separator: ", "))}"
        case .conditional:
            return "TERNARY(\(predicateDescription(expression.predicate)),\(expressionDescription(expression.`true`)),\(expressionDescription(expression.`false`)))"
        default:
            return expression.description
        }
    }

    private func compoundPredicateTypeDescription(_ compoundType: NSCompoundPredicate.LogicalType) -> String {
        switch compoundType {
        case .and:
            return " AND "
        case .or:
            return " OR "
        case .not:
            return "NOT"
        @unknown default:
            return ", "
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func predicateOperatorTypeDescription(_ op: NSComparisonPredicate.Operator) -> String? {
        switch op {
        case .lessThan:
            return "<"
        case .lessThanOrEqualTo:
            return "<="
        case .greaterThan:
            return ">"
        case .greaterThanOrEqualTo:
            return ">="
        case .equalTo:
            return "=="
        case .notEqualTo:
            return "!="
        case .matches:
            return "MATCHES"
        case .beginsWith:
            return "BEGINSWITH"
        case .endsWith:
            return "ENDSWITH"
        case .`in`:
            return "IN"
        case .contains:
            return "CONTAINS"
        case .between:
            return "BETWEEN"
        case .like:
            return "LIKE"
        case .customSelector:
            return nil
        @unknown default:
            return nil
        }
    }
}
// swiftlint:enable missing_docs
