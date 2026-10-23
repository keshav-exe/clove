import Foundation
import Testing
@testable import Clove

struct SkillPageParserTests {
    private let html = """
    <html><head>
    <meta name="description" content="Reviews SwiftUI code &amp; finds bugs."/>
    <script>var x = "<div>Summary</div>";</script>
    </head><body>
    <div>Summary</div><ul><li>Checks modern APIs</li><li>Reports real issues</li></ul>
    <div><span>SKILL.md</span></div><p>Review the code.</p><button>Show more</button>
    <div>Installs</div><div>34.5K</div>
    <div>GitHub Stars</div><div><svg></svg><span>6.3K</span></div>
    <div>First Seen</div><div>Mar 5, 2026</div>
    <div>Security Audits</div>
    <a><span>Gen Agent Trust Hub</span><span>Pass</span></a>
    <a><span>Snyk</span><span>Warn</span></a>
    <h3>Browse</h3>
    </body></html>
    """

    @Test func readsPageFields() {
        let details = SkillPageParser.details(fromHTML: html)
        #expect(details.description == "Reviews SwiftUI code & finds bugs.")
        #expect(details.highlights == ["Checks modern APIs", "Reports real issues"])
        #expect(details.renderedBody == ["Review the code."])
        #expect(details.gitHubStars == "6.3K")
        #expect(details.firstSeen == "Mar 5, 2026")
        #expect(details.audits.map(\.provider) == ["Gen Agent Trust Hub", "Snyk"])
        #expect(details.audits.map(\.verdict) == [.pass, .warn])
    }

    @Test func missingSectionsStayEmpty() {
        let details = SkillPageParser.details(fromHTML: "<html><body><p>Nothing here</p></body></html>")
        #expect(details.description == nil)
        #expect(details.audits.isEmpty)
        #expect(details.gitHubStars == nil)
    }
}

@Test func inlineTagsStayInOneLine() {
    let lines = SkillPageParser.textLines(fromHTML: "<li>Provides <code>npx skills find</code> to search</li><li>Run <code>npx skills add &#x3C;package&#62;</code></li>")
    #expect(lines == ["Provides npx skills find to search", "Run npx skills add <package>"])
}
