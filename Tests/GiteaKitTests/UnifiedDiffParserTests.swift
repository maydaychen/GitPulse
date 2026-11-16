import Testing
@testable import GiteaKit

@Suite("UnifiedDiffParserTests")
struct UnifiedDiffParserTests {
    @Test("No-newline metadata never consumes a file line")
    func ignoresNoNewlineMarkers() {
        let diff = "diff --git a/a.txt b/a.txt\n--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n"
        let lines = UnifiedDiffParser.parse(diff)[0].hunks[0].lines
        #expect(lines.count == 2)
        #expect(lines[0].oldLineNumber == 1)
        #expect(lines.last?.newLineNumber == 1)
    }

    @Test("Parses file patch, additions/deletions counts, and paired split rows")
    func parsesDiffAndSplitRows() {
        let diff = """
        diff --git a/App.swift b/App.swift
        index 111..222 100644
        --- a/App.swift
        +++ b/App.swift
        @@ -10,3 +10,4 @@ struct App {
         let stable = true
        -let port = 443
        +let port = 8443
        +let lanPort = 23000
        """

        let files = UnifiedDiffParser.parse(diff)
        #expect(files.count == 1)
        let patch = files[0]
        #expect(patch.path == "App.swift")
        #expect(patch.additions == 2)
        #expect(patch.deletions == 1)
        #expect(patch.hunks.count == 1)
        #expect(patch.hunks[0].lines.count == 4)
        #expect(patch.hunks[0].splitRows.count == 3)
        #expect(patch.hunks[0].splitRows[1].left?.content == "let port = 443")
        #expect(patch.hunks[0].splitRows[1].right?.content == "let port = 8443")
        #expect(patch.hunks[0].splitRows[2].left == nil)
        #expect(patch.hunks[0].splitRows[2].right?.content == "let lanPort = 23000")
    }
}
