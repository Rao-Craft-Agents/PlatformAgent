import GraniteAgents

/// The platform agent's place in Granite's roster: an app that links this package finds the `platform` agent by
/// this record, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let platformRecord: GraniteRoster.Record = { GraniteRoster.record(PlatformAgent.self) }
