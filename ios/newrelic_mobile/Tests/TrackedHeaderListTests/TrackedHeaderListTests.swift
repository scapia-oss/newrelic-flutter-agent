/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// Tests for TrackedHeaderList, the plugin's own copy of the header names the
// agent has been asked to track.
//
// WHY THIS CODE EXISTS AT ALL
// ---------------------------
// `getHTTPHeadersTrackingFor` used to return `NewRelic.httpHeadersAddedForTracking()`.
// The agent reads its static tracked-header array there without a lock, while
// `noticeNetworkRequest(...andParams:)` replaces and frees that array on a
// background queue. The Dart side asks for the list on every HTTP response and
// reports every response with params, so the two kept overlapping and the main
// thread crashed on a freed array (newrelic/newrelic-ios-agent#937, FRONT-4292).
//
// WHY IT MUST MATCH THE AGENT
// ---------------------------
// The Dart side uses this list to decide which header values to capture and send
// back as params. Returning anything other than what the agent tracks would add
// or drop attributes on MobileRequest. So the rules below mirror the agent: the
// same three default names, exact case-sensitive names, no duplicates.

import XCTest

@testable import newrelic_mobile

final class TrackedHeaderListTests: XCTestCase {

    // The agent seeds its list with the Apollo GraphQL operation headers, so a
    // fresh plugin must report them before anything is registered.
    func testStartsWithTheAgentDefaults() {
        XCTAssertEqual(TrackedHeaderList().headers, [
            "X-APOLLO-OPERATION-NAME",
            "X-APOLLO-OPERATION-TYPE",
            "X-APOLLO-OPERATION-ID",
        ])
    }

    func testAddsARegisteredName() {
        var list = TrackedHeaderList()
        list.add(["x-sc-request-id"])
        XCTAssertEqual(list.headers, TrackedHeaderList.agentDefaults + ["x-sc-request-id"])
    }

    // The app registers at startup and may register again (hot restart, a second
    // engine); the agent keeps a set, so a name must never be reported twice.
    func testRegisteringTheSameNameTwiceKeepsOneCopy() {
        var list = TrackedHeaderList()
        list.add(["x-sc-request-id"])
        list.add(["x-sc-request-id"])
        list.add(["x-sc-request-id", "x-sc-request-id"])
        XCTAssertEqual(list.headers, TrackedHeaderList.agentDefaults + ["x-sc-request-id"])
    }

    // Re-registering a default is not a new name either.
    func testRegisteringADefaultAddsNothing() {
        var list = TrackedHeaderList()
        list.add(["X-APOLLO-OPERATION-ID"])
        XCTAssertEqual(list.headers, TrackedHeaderList.agentDefaults)
    }

    // The agent compares names exactly, so names differing only in case are two
    // entries there and must be two entries here. The Dart lookup itself is
    // case-insensitive, so this only affects what is listed, not what is captured.
    func testNamesDifferingOnlyInCaseAreKeptSeparately() {
        var list = TrackedHeaderList()
        list.add(["X-Sc-Request-Id", "x-sc-request-id"])
        XCTAssertEqual(
            list.headers,
            TrackedHeaderList.agentDefaults + ["X-Sc-Request-Id", "x-sc-request-id"])
    }

    func testKeepsRegistrationOrder() {
        var list = TrackedHeaderList()
        list.add(["b-header", "a-header"])
        list.add(["c-header"])
        XCTAssertEqual(
            list.headers,
            TrackedHeaderList.agentDefaults + ["b-header", "a-header", "c-header"])
    }

    func testRegisteringNothingChangesNothing() {
        var list = TrackedHeaderList()
        list.add([])
        XCTAssertEqual(list.headers, TrackedHeaderList.agentDefaults)
    }
}
