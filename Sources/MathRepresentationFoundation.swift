import Foundation

enum MathOperation: String, Hashable, Sendable {
    case addition
    case subtraction
    case multiplication
    case division

    var symbol: String {
        switch self {
        case .addition: return "+"
        case .subtraction: return "−"
        case .multiplication: return "×"
        case .division: return "÷"
        }
    }

    var accessibilityName: String {
        switch self {
        case .addition: return String(localized: "plus")
        case .subtraction: return String(localized: "minus")
        case .multiplication: return String(localized: "times")
        case .division: return String(localized: "divided by")
        }
    }

    func applying(_ left: Int, _ right: Int) -> Int? {
        switch self {
        case .addition:
            let result = left.addingReportingOverflow(right)
            return result.overflow ? nil : result.partialValue
        case .subtraction:
            let result = left.subtractingReportingOverflow(right)
            return result.overflow ? nil : result.partialValue
        case .multiplication:
            let result = left.multipliedReportingOverflow(by: right)
            return result.overflow ? nil : result.partialValue
        case .division:
            guard right != 0, !(left == .min && right == -1), left.isMultiple(of: right) else { return nil }
            return left / right
        }
    }
}

enum MathComparisonRelation: String, Hashable, Sendable {
    case lessThan
    case equal
    case greaterThan

    var symbol: String {
        switch self {
        case .lessThan: return "<"
        case .equal: return "="
        case .greaterThan: return ">"
        }
    }

    var accessibilityName: String {
        switch self {
        case .lessThan: return String(localized: "is less than")
        case .equal: return String(localized: "equals")
        case .greaterThan: return String(localized: "is greater than")
        }
    }
}

struct MathNumeralRepresentation: Hashable, Sendable {
    let value: Int
    let structureID: RepresentationStructureID
}

struct MathQuantityRepresentation: Hashable, Sendable {
    let count: Int
    let structureID: RepresentationStructureID

    init?(count: Int, structureID: RepresentationStructureID) {
        guard count >= 0 else { return nil }
        self.count = count
        self.structureID = structureID
    }
}

struct MathGroupedQuantityRepresentation: Hashable, Sendable {
    let groupCounts: [Int]
    let structureID: RepresentationStructureID

    init?(groupCounts: [Int], structureID: RepresentationStructureID) {
        guard !groupCounts.isEmpty, groupCounts.allSatisfy({ $0 > 0 }) else { return nil }
        self.groupCounts = groupCounts
        self.structureID = structureID
    }
}

struct MathPlaceValueComponent: Hashable, Sendable {
    let placeValue: Int
    let digit: Int

    init?(placeValue: Int, digit: Int) {
        guard placeValue > 0, (0...9).contains(digit) else { return nil }
        self.placeValue = placeValue
        self.digit = digit
    }
}

struct MathPlaceValueRepresentation: Hashable, Sendable {
    let components: [MathPlaceValueComponent]
    let structureID: RepresentationStructureID

    init?(components: [MathPlaceValueComponent], structureID: RepresentationStructureID) {
        guard !components.isEmpty,
              Set(components.map(\.placeValue)).count == components.count else { return nil }
        self.components = components
        self.structureID = structureID
    }
}

struct MathEqualGroupsRepresentation: Hashable, Sendable {
    let groupCount: Int
    let itemsPerGroup: Int
    let structureID: RepresentationStructureID

    init?(groupCount: Int, itemsPerGroup: Int, structureID: RepresentationStructureID) {
        guard groupCount > 0, itemsPerGroup > 0 else { return nil }
        self.groupCount = groupCount
        self.itemsPerGroup = itemsPerGroup
        self.structureID = structureID
    }
}

struct MathNumberLineRepresentation: Hashable, Sendable {
    let lowerBound: Rational
    let upperBound: Rational
    let position: Rational
    let structureID: RepresentationStructureID
}

struct MathArithmeticRepresentation: Hashable, Sendable {
    let left: ExactNumericValue
    let operation: MathOperation
    let right: ExactNumericValue
    let structureID: RepresentationStructureID
}

enum MathMissingPosition: String, Hashable, Sendable {
    case leftOperand
    case rightOperand
    case result
}

struct MathMissingValueRepresentation: Hashable, Sendable {
    let left: ExactNumericValue?
    let operation: MathOperation
    let right: ExactNumericValue?
    let result: ExactNumericValue?
    let missingPosition: MathMissingPosition
    let structureID: RepresentationStructureID

    init?(
        left: ExactNumericValue?,
        operation: MathOperation,
        right: ExactNumericValue?,
        result: ExactNumericValue?,
        missingPosition: MathMissingPosition,
        structureID: RepresentationStructureID
    ) {
        let isValid: Bool
        switch missingPosition {
        case .leftOperand: isValid = left == nil && right != nil && result != nil
        case .rightOperand: isValid = left != nil && right == nil && result != nil
        case .result: isValid = left != nil && right != nil && result == nil
        }
        guard isValid else { return nil }
        self.left = left
        self.operation = operation
        self.right = right
        self.result = result
        self.missingPosition = missingPosition
        self.structureID = structureID
    }
}

struct MathFractionRepresentation: Hashable, Sendable {
    let value: Rational
    let structureID: RepresentationStructureID
}

struct MathDecimalRepresentation: Hashable, Sendable {
    let displayText: String
    let exactValue: Rational
    let structureID: RepresentationStructureID
}

struct MathPercentRepresentation: Hashable, Sendable {
    let percentValue: Rational
    let structureID: RepresentationStructureID
}

struct MathRatioRepresentation: Hashable, Sendable {
    let first: Int
    let second: Int
    let structureID: RepresentationStructureID

    init?(first: Int, second: Int, structureID: RepresentationStructureID) {
        guard first >= 0, second > 0 else { return nil }
        self.first = first
        self.second = second
        self.structureID = structureID
    }
}

struct MathPowerRepresentation: Hashable, Sendable {
    let base: Int
    let exponent: Int
    let exactValue: Int
    let structureID: RepresentationStructureID

    init?(base: Int, exponent: Int, exactValue: Int, structureID: RepresentationStructureID) {
        guard exponent == 2 || exponent == 3 else { return nil }
        let squared = base.multipliedReportingOverflow(by: base)
        guard !squared.overflow else { return nil }
        let calculated: Int
        if exponent == 2 {
            calculated = squared.partialValue
        } else {
            let cubed = squared.partialValue.multipliedReportingOverflow(by: base)
            guard !cubed.overflow else { return nil }
            calculated = cubed.partialValue
        }
        guard calculated == exactValue else { return nil }
        self.base = base
        self.exponent = exponent
        self.exactValue = exactValue
        self.structureID = structureID
    }
}

struct MathOrderOfOperationsRepresentation: Hashable, Sendable {
    let first: Int
    let firstOperation: MathOperation
    let second: Int
    let secondOperation: MathOperation
    let third: Int
    let exactValue: Int
    let structureID: RepresentationStructureID

    init?(
        first: Int,
        firstOperation: MathOperation,
        second: Int,
        secondOperation: MathOperation,
        third: Int,
        exactValue: Int,
        structureID: RepresentationStructureID
    ) {
        let secondOperationHasPrecedence =
            (secondOperation == .multiplication || secondOperation == .division)
            && (firstOperation == .addition || firstOperation == .subtraction)
        let calculated: Int?
        if secondOperationHasPrecedence {
            calculated = secondOperation.applying(second, third)
                .flatMap { firstOperation.applying(first, $0) }
        } else {
            calculated = firstOperation.applying(first, second)
                .flatMap { secondOperation.applying($0, third) }
        }
        guard calculated == exactValue else { return nil }
        self.first = first
        self.firstOperation = firstOperation
        self.second = second
        self.secondOperation = secondOperation
        self.third = third
        self.exactValue = exactValue
        self.structureID = structureID
    }
}

struct MathOneStepEquationRepresentation: Hashable, Sendable {
    let operation: MathOperation
    let operand: Int
    let result: Int
    let solution: Int
    let structureID: RepresentationStructureID

    init?(
        operation: MathOperation,
        operand: Int,
        result: Int,
        solution: Int,
        structureID: RepresentationStructureID
    ) {
        guard operation.applying(solution, operand) == result else { return nil }
        self.operation = operation
        self.operand = operand
        self.result = result
        self.solution = solution
        self.structureID = structureID
    }
}

struct MathTwoStepEquationRepresentation: Hashable, Sendable {
    let multiplier: Int
    let offset: Int
    let result: Int
    let solution: Int
    let structureID: RepresentationStructureID

    init?(multiplier: Int, offset: Int, result: Int, solution: Int, structureID: RepresentationStructureID) {
        guard multiplier != 0,
              let product = MathOperation.multiplication.applying(multiplier, solution),
              MathOperation.addition.applying(product, offset) == result else { return nil }
        self.multiplier = multiplier
        self.offset = offset
        self.result = result
        self.solution = solution
        self.structureID = structureID
    }
}

struct MathLinearRelationshipRepresentation: Hashable, Sendable {
    let input: Int
    let multiplier: Int
    let offset: Int
    let output: Int
    let structureID: RepresentationStructureID

    init?(input: Int, multiplier: Int, offset: Int, output: Int, structureID: RepresentationStructureID) {
        guard let product = MathOperation.multiplication.applying(multiplier, input),
              MathOperation.addition.applying(product, offset) == output else { return nil }
        self.input = input
        self.multiplier = multiplier
        self.offset = offset
        self.output = output
        self.structureID = structureID
    }
}

struct MathProportionRepresentation: Hashable, Sendable {
    let leftNumerator: Int
    let leftDenominator: Int
    let rightNumerator: Int
    let missingDenominator: Int
    let structureID: RepresentationStructureID

    init?(
        leftNumerator: Int,
        leftDenominator: Int,
        rightNumerator: Int,
        missingDenominator: Int,
        structureID: RepresentationStructureID
    ) {
        guard leftDenominator > 0, missingDenominator > 0,
              let left = Rational(numerator: leftNumerator, denominator: leftDenominator),
              let right = Rational(numerator: rightNumerator, denominator: missingDenominator),
              left == right else { return nil }
        self.leftNumerator = leftNumerator
        self.leftDenominator = leftDenominator
        self.rightNumerator = rightNumerator
        self.missingDenominator = missingDenominator
        self.structureID = structureID
    }
}

struct MathProbabilityRepresentation: Hashable, Sendable {
    let favorableCount: Int
    let totalCount: Int
    let structureID: RepresentationStructureID

    init?(favorableCount: Int, totalCount: Int, structureID: RepresentationStructureID) {
        guard totalCount > 0, (0...totalCount).contains(favorableCount) else { return nil }
        self.favorableCount = favorableCount
        self.totalCount = totalCount
        self.structureID = structureID
    }

    var exactValue: Rational { Rational(numerator: favorableCount, denominator: totalCount)! }
}

enum MathGeometryMeasure: String, Hashable, Sendable {
    case rectangleArea
    case rectanglePerimeter
}

struct MathGeometryRepresentation: Hashable, Sendable {
    let measure: MathGeometryMeasure
    let width: Int
    let height: Int
    let exactValue: Int
    let structureID: RepresentationStructureID

    init?(measure: MathGeometryMeasure, width: Int, height: Int, exactValue: Int, structureID: RepresentationStructureID) {
        guard width > 0, height > 0 else { return nil }
        let calculated: Int?
        switch measure {
        case .rectangleArea:
            calculated = MathOperation.multiplication.applying(width, height)
        case .rectanglePerimeter:
            calculated = MathOperation.addition.applying(width, height)
                .flatMap { MathOperation.multiplication.applying(2, $0) }
        }
        guard calculated == exactValue else { return nil }
        self.measure = measure
        self.width = width
        self.height = height
        self.exactValue = exactValue
        self.structureID = structureID
    }
}

struct MathComparisonRepresentation: Hashable, Sendable {
    let left: ExactNumericValue
    let relation: MathComparisonRelation
    let right: ExactNumericValue
    let structureID: RepresentationStructureID
}

enum MathRepresentation: Hashable, Sendable {
    case numeral(MathNumeralRepresentation)
    case quantity(MathQuantityRepresentation)
    case groupedQuantity(MathGroupedQuantityRepresentation)
    case placeValue(MathPlaceValueRepresentation)
    case equalGroups(MathEqualGroupsRepresentation)
    case numberLine(MathNumberLineRepresentation)
    case arithmeticExpression(MathArithmeticRepresentation)
    case missingValueExpression(MathMissingValueRepresentation)
    case fraction(MathFractionRepresentation)
    case decimal(MathDecimalRepresentation)
    case percent(MathPercentRepresentation)
    case ratio(MathRatioRepresentation)
    case power(MathPowerRepresentation)
    case orderOfOperations(MathOrderOfOperationsRepresentation)
    case oneStepEquation(MathOneStepEquationRepresentation)
    case twoStepEquation(MathTwoStepEquationRepresentation)
    case linearRelationship(MathLinearRelationshipRepresentation)
    case proportion(MathProportionRepresentation)
    case probability(MathProbabilityRepresentation)
    case geometry(MathGeometryRepresentation)
    case comparison(MathComparisonRepresentation)

    var requiresLeftToRightLayout: Bool { true }

    var displayText: String {
        switch self {
        case .numeral(let value): return String(value.value)
        case .quantity(let value): return "Quantity \(value.count)"
        case .groupedQuantity(let value): return value.groupCounts.map(String.init).joined(separator: " + ")
        case .placeValue(let value):
            return value.components
                .sorted { $0.placeValue > $1.placeValue }
                .map { "\($0.digit)×\($0.placeValue)" }
                .joined(separator: " + ")
        case .equalGroups(let value): return "\(value.groupCount) × \(value.itemsPerGroup)"
        case .numberLine(let value): return value.position.displayText
        case .arithmeticExpression(let value):
            return "\(value.left.displayText) \(value.operation.symbol) \(value.right.displayText)"
        case .missingValueExpression(let value):
            let left = value.left?.displayText ?? "□"
            let right = value.right?.displayText ?? "□"
            let result = value.result?.displayText ?? "□"
            return "\(left) \(value.operation.symbol) \(right) = \(result)"
        case .fraction(let value): return value.value.displayText
        case .decimal(let value): return value.displayText
        case .percent(let value): return "\(value.percentValue.displayText)%"
        case .ratio(let value): return "\(value.first):\(value.second)"
        case .power(let value): return "\(value.base)^\(value.exponent)"
        case .orderOfOperations(let value):
            return "\(value.first) \(value.firstOperation.symbol) \(value.second) \(value.secondOperation.symbol) \(value.third)"
        case .oneStepEquation(let value):
            return "x \(value.operation.symbol) \(value.operand) = \(value.result)"
        case .twoStepEquation(let value):
            let sign = value.offset < 0 ? "− \(value.offset.magnitude)" : "+ \(value.offset)"
            return "\(value.multiplier)x \(sign) = \(value.result)"
        case .linearRelationship(let value):
            let sign = value.offset < 0 ? "− \(value.offset.magnitude)" : "+ \(value.offset)"
            return "x = \(value.input) → \(value.multiplier)x \(sign) = \(value.output)"
        case .proportion(let value):
            return "\(value.leftNumerator)/\(value.leftDenominator) = \(value.rightNumerator)/□"
        case .probability(let value):
            return "\(value.favorableCount)/\(value.totalCount)"
        case .geometry(let value):
            let symbol = value.measure == .rectangleArea ? "A" : "P"
            return "\(symbol): \(value.width) × \(value.height)"
        case .comparison(let value):
            return "\(value.left.displayText) \(value.relation.symbol) \(value.right.displayText)"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .numeral(let value):
            return String(format: String(localized: "Number %lld"), Int64(value.value))
        case .quantity(let value):
            return value.count == 0
                ? String(localized: "Empty quantity")
                : String(format: String(localized: "Quantity of %lld"), Int64(value.count))
        case .groupedQuantity(let value):
            return String(
                format: String(localized: "Grouped quantity with groups of %@"),
                value.groupCounts.map(String.init).joined(separator: ", ")
            )
        case .placeValue(let value):
            let components = value.components
                .sorted { $0.placeValue > $1.placeValue }
                .map {
                    String(
                        format: String(localized: "%lld in place %lld"),
                        Int64($0.digit),
                        Int64($0.placeValue)
                    )
                }
                .joined(separator: ", ")
            return String(format: String(localized: "Place value, %@"), components)
        case .equalGroups(let value):
            return String(
                format: String(localized: "%lld equal groups of %lld"),
                Int64(value.groupCount),
                Int64(value.itemsPerGroup)
            )
        case .numberLine(let value):
            return String(
                format: String(localized: "Number line position %@"),
                value.position.displayText
            )
        case .arithmeticExpression(let value):
            let key: String.LocalizationValue
            switch value.operation {
            case .addition: key = "%@ plus %@"
            case .subtraction: key = "%@ minus %@"
            case .multiplication: key = "%@ times %@"
            case .division: key = "%@ divided by %@"
            }
            return String(format: String(localized: key), value.left.displayText, value.right.displayText)
        case .missingValueExpression:
            return String(format: String(localized: "Missing value expression, %@"), displayText)
        case .fraction(let value):
            return String(
                format: String(localized: "Fraction %lld over %lld"),
                Int64(value.value.numerator),
                Int64(value.value.denominator)
            )
        case .decimal(let value):
            return String(format: String(localized: "Decimal %@"), value.displayText)
        case .percent(let value):
            return String(format: String(localized: "%@ percent"), value.percentValue.displayText)
        case .ratio(let value):
            return String(
                format: String(localized: "Ratio %lld to %lld"),
                Int64(value.first),
                Int64(value.second)
            )
        case .power, .orderOfOperations, .oneStepEquation, .twoStepEquation,
             .linearRelationship, .proportion, .probability, .geometry:
            return displayText
        case .comparison(let value):
            let key: String.LocalizationValue
            switch value.relation {
            case .lessThan: key = "%@ is less than %@"
            case .equal: key = "%@ equals %@"
            case .greaterThan: key = "%@ is greater than %@"
            }
            return String(format: String(localized: key), value.left.displayText, value.right.displayText)
        }
    }
}

extension ExactNumericValue {
    var normalizedRational: Rational {
        switch self {
        case .integer(let value): return Rational(numerator: value, denominator: 1)!
        case .rational(let value): return value
        }
    }

    var displayText: String { normalizedRational.displayText }
}

extension Rational {
    var displayText: String {
        denominator == 1 ? String(numerator) : "\(numerator)/\(denominator)"
    }
}
