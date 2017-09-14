//
//  Test.swift
//  Transformers
//
//  Created by Jake Heiser on 9/12/17.
//

import Exec
import Regex
import Rainbow

public extension Transformers {
    
    static func test(t: OutputTransformer) {
        build(t: t)
        t.ignore("^Test Suite '(All tests|Selected tests)' started", on: .err)
        t.replace(PackageTestsBegunMatch.self, on: .err) { "\n\($0.packageName):\n".bold }
        t.register(TestEndResponse.self, on: .err)
        t.register(TestSuiteResponse.self, on: .err)
        t.ignore("Executed [0-9]+ tests", on: .err)
        t.register(OutputAccumulator.self, on: .out)
        t.last("\n")
    }
    
}

private final class OutputAccumulator: SimpleResponse {
    class Match: RegexMatch, Matchable {
        static let regex = Regex("^(.*)$")
        var line: String { return captures[0] }
    }
    
    static var accumulated = ""
    
    init(match: Match) {
        OutputAccumulator.accumulated += match.line
    }
    
    func go() {}
    
    func keepGoing(on line: String) -> Bool {
        let separator = OutputAccumulator.accumulated.isEmpty ? "" : "\n"
        OutputAccumulator.accumulated += separator + line
        return true
    }
    
    func stop() {}
    
}

private class PackageTestsBegunMatch: RegexMatch, Matchable {
    static let regex = Regex("^Test Suite '(.*)\\.xctest' started")
    var packageName: String { return captures[0] }
}

private final class TestSuiteResponse: SimpleResponse {
    
    class Match: RegexMatch, Matchable {
        static let regex = Regex("^Test Suite '(.*)'")
        var suiteName: String { return captures[0] }
    }
    
    static let doneRegex = Regex("Executed .* tests?")
    
    let suiteName: String
    let stream: StdStream = .err
    
    private var failed = false
    private var done = false
    
    var currentTestCase: TestCaseResponse?
    
    init(match: Match) {
        self.suiteName = match.suiteName
    }
    
    func go() {
        stream.output(badge(text: "RUNS", color: .blue), terminator: "")
    }
    
    func keepGoing(on line: String) -> Bool {
        if done {
            return false
        }
        
        if let currentTestCase = currentTestCase {
            // Continue/end test case
            if currentTestCase.keepGoing(on: line) {
                return true
            } else {
                currentTestCase.stop()
                self.currentTestCase = nil
            }
        }
        
        if let match = TestCaseResponse.Match.match(line) {
            // Start test case
            let response = TestCaseResponse(testSuite: self, match: match)
            response.go()
            currentTestCase = response
            return true
        }
        
        if Match.match(line) != nil {
            // Second to last line
            return true
        }
        
        if TestSuiteResponse.doneRegex.matches(line) {
            done = true
            return true
        }
        
        fatalError("\n\nError: unexpected output: \(line)\n\n")
    }
    
    func markFailed() {
        if !failed {
            stream.output("\r" + badge(text: "FAIL", color: .red))
            stream.output("")
            failed = true
        }
    }
    
    func stop() {
        if failed == false {
            stream.output("\r" + badge(text: "PASS", color: .green))
        }
    }
    
    func badge(text: String, color: BackgroundColor) -> String {
        return " \(text) ".applyingBackgroundColor(color).black.bold + " " + suiteName.bold
    }
    
}

private final class TestCaseResponse: Response {
    
    class Match: RegexMatch, Matchable {
        enum Status: String, Capturable {
            case started
            case passed
            case failed
        }
        
        static let regex = Regex("^Test Case .* ([^ ]*)\\]' (started|passed|failed)")
        var caseName: String { return captures[0] }
        var status: Status { return captures[1] }
    }
    
    class FatalErrorMatch: RegexMatch, Matchable {
        static let regex = Regex("^fatal error: (.*)$")
        var message: String { return captures[0] }
    }
    
    let testSuite: TestSuiteResponse
    let caseName: String
    
    var status: Match.Status = .started
    var currentAssertionFailure: AssertionResponse?
    var markedAsFailure = false
    
    init(testSuite: TestSuiteResponse, match: Match) {
        self.testSuite = testSuite
        self.caseName = match.caseName
    }
    
    func go() {
        OutputAccumulator.accumulated = ""
    }
    
    func keepGoing(on line: String) -> Bool {
        guard status == .started else {
            return false
        }

        if let currentAssertionFailure = currentAssertionFailure {
            // Continue/end assertion
            if currentAssertionFailure.keepGoing(on: line) {
                return true
            } else {
                currentAssertionFailure.stop()
                self.currentAssertionFailure = nil
            }
        }
        if let match = AssertionResponse.Match.match(line) {
            // Start assertion
            testSuite.markFailed()
            if !markedAsFailure {
                StdStream.err.output(" ● \(caseName)".red.bold)
                markedAsFailure = true
            }
            
            let assertionFailure = AssertionResponse(match: match)
            assertionFailure.go()
            self.currentAssertionFailure = assertionFailure
            return true
        }
        
        if let match = Match.match(line) {
            status = match.status
            return true
        }
        
        if let match = FatalErrorMatch.match(line) {
            testSuite.markFailed()
            StdStream.err.output("Fatal error: ".red.bold + match.message)
            return true
        }
        
        fatalError("\n\nError: unexpected output: \(line)\n\n")
    }
    
    func stop() {
        if status == .failed {
            if !OutputAccumulator.accumulated.isEmpty {
                StdStream.err.output()
                StdStream.err.output("\tOutput:")
                let output = OutputAccumulator.accumulated.components(separatedBy: "\n").map({ "\t\($0)" }).joined(separator: "\n")
                StdStream.err.output(output.dim)
                StdStream.err.output()
            }
        }
    }
    
}

final class AssertionResponse: Response {
    
    class Match: RegexMatch, Matchable {
        static let regex = Regex("(.*):([0-9]+): error: .* : (.*)$")
        var file: String { return captures[0] }
        var lineNumber: Int { return captures[1] }
        var assertion: String { return captures[2] }
    }
    
    static let newlineReplacement = "______$$$$$$$$"
    
    let file: String
    let lineNumber: Int
    var assertion: String
    
    let stream = StdStream.err
    
    init(match: Match) {
        self.file = match.file
        self.lineNumber = match.lineNumber
        self.assertion = match.assertion
    }
    
    func go() {}
    
    func keepGoing(on line: String) -> Bool {
        if AssertionResponse.Match.matches(line)
            || TestCaseResponse.FatalErrorMatch.matches(line)
            || TestCaseResponse.Match.matches(line) {
            return false
        }
        
        assertion += AssertionResponse.newlineReplacement + line
        
        return true
    }
    
    func stop() {        
        stream.output()
        
        var foundMatch = false
        for matchType in xctMatches {
            if let match = matchType.match(assertion) {
                match.output()
                
                if !match.message.isEmpty {
                    stream.output()
                    let lines = match.message.components(separatedBy: AssertionResponse.newlineReplacement)
                    var message = lines[0]
                    if lines.count > 1 {
                        message += "\n" + lines.dropFirst().map({ "\t\($0)" }).joined(separator: "\n")
                    }
                    stream.output("\tNote: \(message)")
                }
                
                foundMatch = true
                break
            }
        }
        
        if !foundMatch {
            stream.output("\nWarning: unrecognized error\n")
            stream.output(assertion)
        }
        
        let fileLocation = file.beautifyPath
        stream.output()
        stream.output("\tat \(fileLocation):\(lineNumber)".dim)
        stream.output()
    }
    
}

private final class TestEndResponse: SimpleResponse {
    
    class Match: RegexMatch, Matchable {
        static let regex = Regex("Test Suite '(All tests|Selected tests|.*\\.xctest)' (passed|failed)")
        var suite: String { return captures[0] }
    }
    
    class CountMatch: RegexMatch, Matchable {
        static let regex = Regex("Executed ([0-9]+) tests?, with ([0-9]*) failures? .* \\(([\\.0-9]+)\\) seconds$")
        var totalCount: Int { return captures[0] }
        var failureCount: Int { return captures[1] }
        var duration: String { return captures[2] }
    }
    
    let stream: StdStream
    var nextLine = true
    
    init(match: Match) {
        if match.suite == "All tests" || match.suite == "Selected tests" {
            stream = .err
        } else {
            stream = .null
        }
    }
    
    func go() {
        stream.output("")
    }
    
    func keepGoing(on line: String) -> Bool {
        guard nextLine else {
            return false
        }
        nextLine = false
        
        if let match = CountMatch.match(line) {
            var parts: [String] = []
            if match.failureCount > 0 {
                parts.append("\(match.failureCount) failed".bold.red)
            }
            if match.failureCount < match.totalCount {
                parts.append("\(match.totalCount - match.failureCount) passed".bold.green)
            }
            parts.append("\(match.totalCount) total")
            
            let output = "Tests:\t".bold.white + parts.joined(separator: ", ")
            stream.output(output)
            
            stream.output("Time:\t".bold.white + match.duration + "s")
        }
        
        return true
    }
    
    func stop() {}
    
}
