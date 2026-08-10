import Foundation
import ZoneBarCore

let timeZoneCatalogTests: [TestCase] = [
    TestCase(name: "country lookups") {
        expectEqual(TimeZoneCatalog.countryCode(for: "Europe/Stockholm"), "SE")
        expectEqual(TimeZoneCatalog.countryName(for: "Europe/Stockholm"), "Sweden")
        expectEqual(TimeZoneCatalog.countryName(for: "Asia/Tokyo"), "Japan")
        expectNil(TimeZoneCatalog.countryCode(for: "UTC"))
        expectNil(TimeZoneCatalog.countryName(for: "UTC"))
    },

    TestCase(name: "region grouping") {
        expectEqual(TimeZoneCatalog.region(for: "Europe/Stockholm"), "Europe")
        expectEqual(TimeZoneCatalog.region(for: "America/New_York"), "Americas")
        expectEqual(TimeZoneCatalog.region(for: "Asia/Tokyo"), "Asia")
        expectEqual(TimeZoneCatalog.region(for: "Africa/Nairobi"), "Africa")
    },

    TestCase(name: "Australia and Pacific share Oceania") {
        expectEqual(TimeZoneCatalog.region(for: "Australia/Sydney"), "Oceania")
        expectEqual(TimeZoneCatalog.region(for: "Pacific/Auckland"), "Oceania")
    },

    TestCase(name: "zones without a known region are Other") {
        expectEqual(TimeZoneCatalog.region(for: "UTC"), "Other")
        expectEqual(TimeZoneCatalog.region(for: "GMT"), "Other")
        expectEqual(TimeZoneCatalog.region(for: "Atlantic/Azores"), "Other")
        expectEqual(TimeZoneCatalog.region(for: "Indian/Maldives"), "Other")
        expectEqual(TimeZoneCatalog.region(for: "Antarctica/Casey"), "Other")
    },

    TestCase(name: "region sort index orders headers") {
        expectLessThan(
            TimeZoneCatalog.regionSortIndex("Americas"), TimeZoneCatalog.regionSortIndex("Europe"))
        expectLessThan(
            TimeZoneCatalog.regionSortIndex("Asia"), TimeZoneCatalog.regionSortIndex("Oceania"))
        for region in ["Americas", "Europe", "Africa", "Asia", "Oceania"] {
            expectLessThan(
                TimeZoneCatalog.regionSortIndex(region), TimeZoneCatalog.regionSortIndex("Other"),
                "\(region) must sort before Other")
        }
    },

    TestCase(name: "city name strips prefix and underscores") {
        expectEqual(TimeZoneCatalog.cityName(for: "Europe/Stockholm"), "Stockholm")
        expectEqual(TimeZoneCatalog.cityName(for: "America/New_York"), "New York")
        expectEqual(
            TimeZoneCatalog.cityName(for: "America/Argentina/Buenos_Aires"), "Buenos Aires")
        expectEqual(TimeZoneCatalog.cityName(for: "UTC"), "UTC")
    },

    TestCase(name: "search label includes country when known") {
        expectEqual(TimeZoneCatalog.searchLabel(for: "Europe/Stockholm"), "Stockholm — Sweden")
        expectEqual(TimeZoneCatalog.searchLabel(for: "UTC"), "UTC")
    },

    TestCase(name: "search matches city, country and identifier") {
        let zones = ["Europe/Stockholm", "Asia/Tokyo", "America/New_York"]
        expectEqual(TimeZoneCatalog.search("stockholm", in: zones), ["Europe/Stockholm"])
        expectEqual(
            TimeZoneCatalog.search("sweden", in: zones), ["Europe/Stockholm"],
            "country name is not part of the identifier")
        expectEqual(TimeZoneCatalog.search("japan", in: zones), ["Asia/Tokyo"])
        expectEqual(TimeZoneCatalog.search("america", in: zones), ["America/New_York"])
        expectEqual(TimeZoneCatalog.search("new y", in: zones), ["America/New_York"])
    },

    TestCase(name: "search is case insensitive and trims whitespace") {
        expectEqual(
            TimeZoneCatalog.search("  TOKYO  ", in: ["Europe/Stockholm", "Asia/Tokyo"]),
            ["Asia/Tokyo"])
    },

    TestCase(name: "empty search returns everything") {
        let zones = ["Europe/Stockholm", "Asia/Tokyo"]
        expectEqual(TimeZoneCatalog.search("", in: zones), zones)
        expectEqual(TimeZoneCatalog.search("   ", in: zones), zones)
    },

    TestCase(name: "search with no matches is empty") {
        expectTrue(TimeZoneCatalog.search("zzzznope", in: ["Europe/Stockholm"]).isEmpty)
    },

    TestCase(name: "all identifiers is non-empty and sorted") {
        expectFalse(TimeZoneCatalog.allIdentifiers.isEmpty)
        expectEqual(TimeZoneCatalog.allIdentifiers, TimeZoneCatalog.allIdentifiers.sorted())
        expectTrue(TimeZoneCatalog.allIdentifiers.contains("Europe/Stockholm"))
    },

    TestCase(name: "UTC offset description") {
        // Mid-January 2024: Stockholm CET, Tokyo +09, New York EST.
        let winter = Date(timeIntervalSince1970: 1_705_312_800)
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(
                for: TimeZone(identifier: "Europe/Stockholm")!, at: winter), "UTC+01:00")
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(
                for: TimeZone(identifier: "Asia/Tokyo")!, at: winter), "UTC+09:00")
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(
                for: TimeZone(identifier: "America/New_York")!, at: winter), "UTC-05:00")
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(for: TimeZone(identifier: "UTC")!, at: winter),
            "UTC")
    },

    TestCase(name: "UTC offset handles half-hour zones") {
        let winter = Date(timeIntervalSince1970: 1_705_312_800)
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(
                for: TimeZone(identifier: "Asia/Kolkata")!, at: winter), "UTC+05:30")
        expectEqual(
            TimeZoneCatalog.utcOffsetDescription(
                for: TimeZone(identifier: "Pacific/Marquesas")!, at: winter), "UTC-09:30")
    },

    TestCase(name: "UTC offset follows daylight saving") {
        let stockholm = TimeZone(identifier: "Europe/Stockholm")!
        let winter = Date(timeIntervalSince1970: 1_705_312_800)
        let summer = Date(timeIntervalSince1970: 1_721_037_600)
        expectEqual(TimeZoneCatalog.utcOffsetDescription(for: stockholm, at: winter), "UTC+01:00")
        expectEqual(TimeZoneCatalog.utcOffsetDescription(for: stockholm, at: summer), "UTC+02:00")
    },
]
