import Testing
@testable import GiteaKit

@Suite("ANSITerminalParserTests")
struct ANSITerminalParserTests {
    @Test("Auto-expands failed step and marks first error line index")
    func expandsFailedStep() {
        let log = """
        ::group::Checkout
        \u{001B}[32mChecked out main\u{001B}[0m
        ::endgroup::
        ::group::Unit Tests
        Compiling...
        \u{001B}[31merror: testPortPreserved failed\u{001B}[0m
        Done
        ::endgroup::
        """

        let steps = ANSITerminalParser.parseSteps(from: log, runFailed: true)
        #expect(steps.count == 2)
        #expect(steps[0].status == .success)
        #expect(steps[0].isExpanded == false)
        #expect(steps[1].status == .failure)
        #expect(steps[1].isExpanded == true)
        #expect(steps[1].firstErrorLineIndex == 1)
        #expect(steps[1].lines[1].text == "error: testPortPreserved failed")
        #expect(steps[1].lines[1].severity == .error)
    }
}
