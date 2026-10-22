import Foundation
import Testing
@testable import Clove

struct LeaderboardParserTests {
    /// Mirrors how skills.sh streams its list: JSON inside JS string chunks,
    /// split at arbitrary points.
    private let html = #"""
    <html><body>
    <script>self.__next_f.push([1,"4c:[\"$\",\"$L53\",null,{\"initialSk"])</script>
    <script>self.__next_f.push([1,"ills\":[{\"source\":\"vercel-labs/skills\",\"skillId\":\"find-skills\",\"name\":\"find-skills\",\"installs\":3988237,\"weeklyInstalls\":[1,2,3],\"isOfficial\":true},{\"source\":\"mattpocock/skills\",\"skillId\":\"grill-me\",\"name\":\"grill [me]\",\"installs\":12,\"change\":-3}],\"other\":1}]"])</script>
    </body></html>
    """#

    @Test func extractsSkillsAcrossChunks() throws {
        let skills = try LeaderboardParser.skills(fromHTML: html)
        #expect(skills.count == 2)
        #expect(skills[0].id == "vercel-labs/skills/find-skills")
        #expect(skills[0].weeklyInstalls == [1, 2, 3])
        #expect(skills[0].isOfficial)
        #expect(skills[1].name == "grill [me]")
        #expect(skills[1].change == -3)
        #expect(skills[1].weeklyInstalls.isEmpty)
    }

    @Test func throwsWhenPayloadIsMissing() {
        #expect(throws: LeaderboardParser.Failure.missingPayload) {
            try LeaderboardParser.skills(fromHTML: "<html></html>")
        }
    }

    @Test func balancedValueIgnoresBracketsInStrings() {
        let value = LeaderboardParser.jsonValue(after: "\"k\":", in: #"{"k":[{"a":"]}"},2],"z":1}"#)
        #expect(value == #"[{"a":"]}"},2]"#)
    }
}
