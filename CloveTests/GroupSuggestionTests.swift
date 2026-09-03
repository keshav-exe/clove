import Testing
@testable import Clove

struct GroupSuggestionTests {
    @Test func emptyQueryListsUnassignedGroups() {
        let result = GroupSuggestion.matching(
            query: "",
            assigned: ["design"],
            available: ["design", "review", "ios"]
        )
        #expect(result == [.existing("review"), .existing("ios")])
    }

    @Test func typedNameCanCreateANewGroup() {
        let result = GroupSuggestion.matching(
            query: "motion",
            assigned: ["design"],
            available: ["design", "review"]
        )
        #expect(result == [.create("motion")])
    }

    @Test func queryFiltersExistingGroupsAndOffersCreate() {
        let result = GroupSuggestion.matching(
            query: "re",
            assigned: [],
            available: ["review", "design"]
        )
        #expect(result == [.create("re"), .existing("review")])
    }

    @Test func exactMatchDoesNotOfferCreate() {
        let result = GroupSuggestion.matching(
            query: "review",
            assigned: [],
            available: ["review"]
        )
        #expect(result == [.existing("review")])
    }

    @Test func alreadyAssignedNameOffersNothing() {
        let result = GroupSuggestion.matching(
            query: "design",
            assigned: ["design"],
            available: ["design", "review"]
        )
        #expect(result.isEmpty)
    }
}
