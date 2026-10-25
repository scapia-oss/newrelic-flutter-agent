/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// The plugin's own copy of the header names the agent has been asked to track.
///
/// `getHTTPHeadersTrackingFor` used to return `NewRelic.httpHeadersAddedForTracking()`.
/// The agent returns its static tracked-header array from that method without
/// taking a lock, while `noticeNetworkRequest(...andParams:)` replaces (and frees)
/// that array on a background queue for every request reported with params. A
/// lookup that loaded the old array just before it was replaced used freed memory
/// and crashed with EXC_BAD_ACCESS (newrelic/newrelic-ios-agent#937, FRONT-4292).
/// Keeping our own list means the plugin never calls that method.
///
/// Deliberately free of Flutter and NewRelic imports so it can be unit tested
/// without an iOS app build. Rationale for every rule lives in
/// `Tests/TrackedHeaderListTests/TrackedHeaderListTests.swift`.
struct TrackedHeaderList {
    /// The names the agent seeds its own list with (`NRMAHTTPUtilities`), so the
    /// plugin reports exactly what the agent tracks.
    static let agentDefaults = [
        "X-APOLLO-OPERATION-NAME",
        "X-APOLLO-OPERATION-TYPE",
        "X-APOLLO-OPERATION-ID",
    ]

    private(set) var headers: [String] = TrackedHeaderList.agentDefaults

    /// Adds every name not already present, in order. Names are compared exactly,
    /// case included, which is how the agent's own set treats them.
    mutating func add(_ newHeaders: [String]) {
        for header in newHeaders where !headers.contains(header) {
            headers.append(header)
        }
    }
}
