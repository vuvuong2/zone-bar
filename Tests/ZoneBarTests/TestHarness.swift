import Foundation

// A minimal test harness.
//
// XCTest ships inside Xcode, not the Command Line Tools, so `swift test` cannot
// run here. This gives the same essentials — named cases, non-fatal assertions
// with file/line, and a non-zero exit on failure — with no dependencies.
// Run it with: swift run ZoneBarTests

struct TestCase {
    let name: String
    let run: () -> Void
}

/// Collects failures for the case currently running.
enum TestReport {
    nonisolated(unsafe) static var currentFailures: [String] = []

    static func record(_ message: String, file: StaticString, line: UInt) {
        let path = String(describing: file)
        let name = (path as NSString).lastPathComponent
        currentFailures.append("\(message)  [\(name):\(line)]")
    }
}

func expectEqual<T: Equatable>(
    _ actual: T, _ expected: T, _ note: String = "",
    file: StaticString = #file, line: UInt = #line
) {
    guard actual != expected else { return }
    let suffix = note.isEmpty ? "" : " — \(note)"
    TestReport.record(
        "expected \(String(reflecting: expected)), got \(String(reflecting: actual))\(suffix)",
        file: file, line: line)
}

func expectTrue(
    _ value: Bool, _ note: String = "", file: StaticString = #file, line: UInt = #line
) {
    guard !value else { return }
    TestReport.record("expected true\(note.isEmpty ? "" : " — \(note)")", file: file, line: line)
}

func expectFalse(
    _ value: Bool, _ note: String = "", file: StaticString = #file, line: UInt = #line
) {
    guard value else { return }
    TestReport.record("expected false\(note.isEmpty ? "" : " — \(note)")", file: file, line: line)
}

func expectNil<T>(
    _ value: T?, _ note: String = "", file: StaticString = #file, line: UInt = #line
) {
    guard let value else { return }
    let suffix = note.isEmpty ? "" : " — \(note)"
    TestReport.record("expected nil, got \(String(reflecting: value))\(suffix)", file: file, line: line)
}

func expectNotNil<T>(
    _ value: T?, _ note: String = "", file: StaticString = #file, line: UInt = #line
) {
    guard value == nil else { return }
    TestReport.record("expected non-nil\(note.isEmpty ? "" : " — \(note)")", file: file, line: line)
}

func expectLessThan<T: Comparable>(
    _ lhs: T, _ rhs: T, _ note: String = "", file: StaticString = #file, line: UInt = #line
) {
    guard !(lhs < rhs) else { return }
    let suffix = note.isEmpty ? "" : " — \(note)"
    TestReport.record("expected \(lhs) < \(rhs)\(suffix)", file: file, line: line)
}

func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
    TestReport.record(message, file: file, line: line)
}

/// Runs every case and prints a summary. Returns the process exit code.
func runSuites(_ suites: [(String, [TestCase])]) -> Int32 {
    var passed = 0
    var failedCases: [(String, [String])] = []

    for (suiteName, cases) in suites {
        print("\n\(suiteName)")
        for testCase in cases {
            TestReport.currentFailures = []
            testCase.run()
            let failures = TestReport.currentFailures
            if failures.isEmpty {
                passed += 1
                print("  ✓ \(testCase.name)")
            } else {
                failedCases.append(("\(suiteName).\(testCase.name)", failures))
                print("  ✗ \(testCase.name)")
                for failure in failures { print("      \(failure)") }
            }
        }
    }

    let total = passed + failedCases.count
    print("\n" + String(repeating: "─", count: 56))
    if failedCases.isEmpty {
        print("All \(total) tests passed.")
        return 0
    }
    print("\(passed)/\(total) passed, \(failedCases.count) failed:")
    for (name, _) in failedCases { print("  • \(name)") }
    return 1
}
