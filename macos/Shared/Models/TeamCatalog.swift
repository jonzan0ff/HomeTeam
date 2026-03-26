import Foundation

// MARK: - Supported sports

enum SupportedSport: String, CaseIterable, Codable, Hashable, Identifiable {
  var id: String { rawValue }
  case nhl, mlb, nfl, nba, mls, f1, motoGP, premierLeague

  var displayName: String {
    switch self {
    case .nhl:          return "NHL"
    case .mlb:          return "MLB"
    case .nfl:          return "NFL"
    case .nba:          return "NBA"
    case .mls:          return "MLS"
    case .f1:           return "F1"
    case .motoGP:       return "MotoGP"
    case .premierLeague: return "Premier League"
    }
  }

  var sportPath: String {
    switch self {
    case .nhl:          return "hockey"
    case .mlb:          return "baseball"
    case .nfl:          return "football"
    case .nba:          return "basketball"
    case .mls, .premierLeague: return "soccer"
    case .f1, .motoGP:  return "racing"
    }
  }

  var leaguePath: String {
    switch self {
    case .nhl:          return "nhl"
    case .mlb:          return "mlb"
    case .nfl:          return "nfl"
    case .nba:          return "nba"
    case .mls:          return "usa.1"
    case .f1:           return "f1"
    case .motoGP:       return "motoGP"
    case .premierLeague: return "eng.1"
    }
  }

  var isRacing: Bool { self == .f1 || self == .motoGP }

  var systemImageName: String {
    switch self {
    case .nhl:                      return "sportscourt"
    case .mlb:                      return "baseball"
    case .nfl:                      return "american.football"
    case .nba:                      return "basketball"
    case .mls, .premierLeague:      return "soccerball"
    case .f1, .motoGP:              return "flag.checkered"
    }
  }

  /// Official sport wordmark PNG — used in place of team logos for racing rows.
  var wordmarkURL: URL? {
    switch self {
    case .f1:
      return URL(string: "https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png")
    case .motoGP:
      return URL(string: "https://static.dorna.com/assets/logos/mgp/brand/mgp-logo-on-light.png")
    default:
      return nil
    }
  }
}

// MARK: - Team definition

struct TeamDefinition: Codable, Hashable, Identifiable {
  let teamID: String          // unique key; for driver entries: "espnID_drivername"
  let espnTeamID: String      // actual ESPN API team ID (for schedule fetch + game matching)
  let sport: SupportedSport
  let city: String
  let name: String
  let displayName: String
  let abbreviation: String
  let driverNames: [String]   // F1/MotoGP: single-element for per-driver entries

  // Identifiable: use composite so ForEach never sees duplicates across sports
  var id: String { compositeID }

  var compositeID: String { "\(sport.rawValue):\(teamID)" }

  var shortLabel: String { city.isEmpty ? displayName : "\(city) \(name)" }

  /// For F1/MotoGP: "Ferrari — Hamilton"; for team sports: displayName
  var raceLabel: String {
    guard !driverNames.isEmpty else { return displayName }
    return "\(displayName) — \(driverNames.joined(separator: " / "))"
  }

  var searchText: String {
    ([displayName, city, name, abbreviation, sport.displayName] + driverNames)
      .joined(separator: " ")
      .lowercased()
  }

  var scheduleURL: URL? {
    URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sport.sportPath)/\(sport.leaguePath)/teams/\(espnTeamID)/schedule")
  }

  /// Logo URL served from GitHub Pages. SVG-only (F1/MotoGP) returns nil — use sport system icon instead.
  var logoURL: URL? {
    guard !sport.isRacing else { return nil }
    return URL(string: "https://jonzan0ff.github.io/HomeTeam/logos/teams/\(sport.rawValue)_\(espnTeamID).png")
  }

  init(teamID: String, sport: SupportedSport, city: String, name: String,
       displayName: String, abbreviation: String, driverNames: [String] = [],
       espnTeamID: String? = nil) {
    self.teamID = teamID
    self.espnTeamID = espnTeamID ?? teamID
    self.sport = sport
    self.city = city
    self.name = name
    self.displayName = displayName
    self.abbreviation = abbreviation
    self.driverNames = driverNames
  }
}

// MARK: - Team catalog

enum TeamCatalog {
  static let defaultTeamCompositeID = "nhl:1"  // Boston Bruins

  // MARK: NHL
  static let teams: [TeamDefinition] = nhlTeams + mlbTeams + nflTeams + nbaTeams
    + mlsTeams + premierLeagueTeams + f1Teams + motoGPTeams

  private static let nhlTeams: [TeamDefinition] = [
    .init(teamID:"25", sport:.nhl, city:"Anaheim",     name:"Ducks",        displayName:"Anaheim Ducks",          abbreviation:"ANA"),
    .init(teamID:"1",  sport:.nhl, city:"Boston",      name:"Bruins",       displayName:"Boston Bruins",          abbreviation:"BOS"),
    .init(teamID:"2",  sport:.nhl, city:"Buffalo",     name:"Sabres",       displayName:"Buffalo Sabres",         abbreviation:"BUF"),
    .init(teamID:"3",  sport:.nhl, city:"Calgary",     name:"Flames",       displayName:"Calgary Flames",         abbreviation:"CGY"),
    .init(teamID:"7",  sport:.nhl, city:"Carolina",    name:"Hurricanes",   displayName:"Carolina Hurricanes",    abbreviation:"CAR"),
    .init(teamID:"4",  sport:.nhl, city:"Chicago",     name:"Blackhawks",   displayName:"Chicago Blackhawks",     abbreviation:"CHI"),
    .init(teamID:"17", sport:.nhl, city:"Colorado",    name:"Avalanche",    displayName:"Colorado Avalanche",     abbreviation:"COL"),
    .init(teamID:"29", sport:.nhl, city:"Columbus",    name:"Blue Jackets", displayName:"Columbus Blue Jackets",  abbreviation:"CBJ"),
    .init(teamID:"9",  sport:.nhl, city:"Dallas",      name:"Stars",        displayName:"Dallas Stars",           abbreviation:"DAL"),
    .init(teamID:"5",  sport:.nhl, city:"Detroit",     name:"Red Wings",    displayName:"Detroit Red Wings",      abbreviation:"DET"),
    .init(teamID:"6",  sport:.nhl, city:"Edmonton",    name:"Oilers",       displayName:"Edmonton Oilers",        abbreviation:"EDM"),
    .init(teamID:"26", sport:.nhl, city:"Florida",     name:"Panthers",     displayName:"Florida Panthers",       abbreviation:"FLA"),
    .init(teamID:"8",  sport:.nhl, city:"Los Angeles", name:"Kings",        displayName:"Los Angeles Kings",      abbreviation:"LA"),
    .init(teamID:"30", sport:.nhl, city:"Minnesota",   name:"Wild",         displayName:"Minnesota Wild",         abbreviation:"MIN"),
    .init(teamID:"10", sport:.nhl, city:"Montreal",    name:"Canadiens",    displayName:"Montreal Canadiens",     abbreviation:"MTL"),
    .init(teamID:"27", sport:.nhl, city:"Nashville",   name:"Predators",    displayName:"Nashville Predators",    abbreviation:"NSH"),
    .init(teamID:"11", sport:.nhl, city:"New Jersey",  name:"Devils",       displayName:"New Jersey Devils",      abbreviation:"NJ"),
    .init(teamID:"12", sport:.nhl, city:"New York",    name:"Islanders",    displayName:"New York Islanders",     abbreviation:"NYI"),
    .init(teamID:"13", sport:.nhl, city:"New York",    name:"Rangers",      displayName:"New York Rangers",       abbreviation:"NYR"),
    .init(teamID:"14", sport:.nhl, city:"Ottawa",      name:"Senators",     displayName:"Ottawa Senators",        abbreviation:"OTT"),
    .init(teamID:"15", sport:.nhl, city:"Philadelphia",name:"Flyers",       displayName:"Philadelphia Flyers",    abbreviation:"PHI"),
    .init(teamID:"16", sport:.nhl, city:"Pittsburgh",  name:"Penguins",     displayName:"Pittsburgh Penguins",    abbreviation:"PIT"),
    .init(teamID:"18",     sport:.nhl, city:"San Jose",    name:"Sharks",        displayName:"San Jose Sharks",        abbreviation:"SJ"),
    .init(teamID:"19",     sport:.nhl, city:"St. Louis",   name:"Blues",         displayName:"St. Louis Blues",        abbreviation:"STL"),
    .init(teamID:"20",     sport:.nhl, city:"Tampa Bay",   name:"Lightning",     displayName:"Tampa Bay Lightning",    abbreviation:"TB"),
    .init(teamID:"21",     sport:.nhl, city:"Toronto",     name:"Maple Leafs",   displayName:"Toronto Maple Leafs",    abbreviation:"TOR"),
    .init(teamID:"22",     sport:.nhl, city:"Vancouver",   name:"Canucks",       displayName:"Vancouver Canucks",      abbreviation:"VAN"),
    .init(teamID:"37",     sport:.nhl, city:"Vegas",       name:"Golden Knights",displayName:"Vegas Golden Knights",   abbreviation:"VGK"),
    .init(teamID:"23",     sport:.nhl, city:"Washington",  name:"Capitals",      displayName:"Washington Capitals",    abbreviation:"WSH"),
    .init(teamID:"28",     sport:.nhl, city:"Winnipeg",    name:"Jets",          displayName:"Winnipeg Jets",          abbreviation:"WPG"),
    .init(teamID:"124292", sport:.nhl, city:"Seattle",     name:"Kraken",        displayName:"Seattle Kraken",         abbreviation:"SEA"),
    .init(teamID:"129764", sport:.nhl, city:"Utah",        name:"Mammoth",       displayName:"Utah Mammoth",           abbreviation:"UTAH"),
  ]

  private static let mlbTeams: [TeamDefinition] = [
    .init(teamID:"1",  sport:.mlb, city:"Baltimore",   name:"Orioles",      displayName:"Baltimore Orioles",      abbreviation:"BAL"),
    .init(teamID:"2",  sport:.mlb, city:"Boston",      name:"Red Sox",      displayName:"Boston Red Sox",         abbreviation:"BOS"),
    .init(teamID:"3",  sport:.mlb, city:"Chicago",     name:"White Sox",    displayName:"Chicago White Sox",      abbreviation:"CHW"),
    .init(teamID:"4",  sport:.mlb, city:"Cleveland",   name:"Guardians",    displayName:"Cleveland Guardians",    abbreviation:"CLE"),
    .init(teamID:"5",  sport:.mlb, city:"Detroit",     name:"Tigers",       displayName:"Detroit Tigers",         abbreviation:"DET"),
    .init(teamID:"6",  sport:.mlb, city:"Houston",     name:"Astros",       displayName:"Houston Astros",         abbreviation:"HOU"),
    .init(teamID:"7",  sport:.mlb, city:"Kansas City", name:"Royals",       displayName:"Kansas City Royals",     abbreviation:"KC"),
    .init(teamID:"8",  sport:.mlb, city:"Los Angeles", name:"Angels",       displayName:"Los Angeles Angels",     abbreviation:"LAA"),
    .init(teamID:"9",  sport:.mlb, city:"Minnesota",   name:"Twins",        displayName:"Minnesota Twins",        abbreviation:"MIN"),
    .init(teamID:"10", sport:.mlb, city:"New York",    name:"Yankees",      displayName:"New York Yankees",       abbreviation:"NYY"),
    .init(teamID:"11", sport:.mlb, city:"Oakland",     name:"Athletics",    displayName:"Oakland Athletics",      abbreviation:"OAK"),
    .init(teamID:"12", sport:.mlb, city:"Seattle",     name:"Mariners",     displayName:"Seattle Mariners",       abbreviation:"SEA"),
    .init(teamID:"13", sport:.mlb, city:"Tampa Bay",   name:"Rays",         displayName:"Tampa Bay Rays",         abbreviation:"TB"),
    .init(teamID:"14", sport:.mlb, city:"Texas",       name:"Rangers",      displayName:"Texas Rangers",          abbreviation:"TEX"),
    .init(teamID:"15", sport:.mlb, city:"Toronto",     name:"Blue Jays",    displayName:"Toronto Blue Jays",      abbreviation:"TOR"),
    .init(teamID:"16", sport:.mlb, city:"Arizona",     name:"Diamondbacks", displayName:"Arizona Diamondbacks",   abbreviation:"ARI"),
    .init(teamID:"17", sport:.mlb, city:"Atlanta",     name:"Braves",       displayName:"Atlanta Braves",         abbreviation:"ATL"),
    .init(teamID:"18", sport:.mlb, city:"Chicago",     name:"Cubs",         displayName:"Chicago Cubs",           abbreviation:"CHC"),
    .init(teamID:"19", sport:.mlb, city:"Cincinnati",  name:"Reds",         displayName:"Cincinnati Reds",        abbreviation:"CIN"),
    .init(teamID:"20", sport:.mlb, city:"Colorado",    name:"Rockies",      displayName:"Colorado Rockies",       abbreviation:"COL"),
    .init(teamID:"21", sport:.mlb, city:"Los Angeles", name:"Dodgers",      displayName:"Los Angeles Dodgers",    abbreviation:"LAD"),
    .init(teamID:"22", sport:.mlb, city:"Miami",       name:"Marlins",      displayName:"Miami Marlins",          abbreviation:"MIA"),
    .init(teamID:"23", sport:.mlb, city:"Milwaukee",   name:"Brewers",      displayName:"Milwaukee Brewers",      abbreviation:"MIL"),
    .init(teamID:"24", sport:.mlb, city:"New York",    name:"Mets",         displayName:"New York Mets",          abbreviation:"NYM"),
    .init(teamID:"25", sport:.mlb, city:"Philadelphia",name:"Phillies",     displayName:"Philadelphia Phillies",  abbreviation:"PHI"),
    .init(teamID:"26", sport:.mlb, city:"Pittsburgh",  name:"Pirates",      displayName:"Pittsburgh Pirates",     abbreviation:"PIT"),
    .init(teamID:"27", sport:.mlb, city:"San Diego",   name:"Padres",       displayName:"San Diego Padres",       abbreviation:"SD"),
    .init(teamID:"28", sport:.mlb, city:"San Francisco",name:"Giants",      displayName:"San Francisco Giants",   abbreviation:"SF"),
    .init(teamID:"29", sport:.mlb, city:"St. Louis",   name:"Cardinals",    displayName:"St. Louis Cardinals",    abbreviation:"STL"),
    .init(teamID:"30", sport:.mlb, city:"Washington",  name:"Nationals",    displayName:"Washington Nationals",   abbreviation:"WSH"),
  ]

  private static let nflTeams: [TeamDefinition] = [
    .init(teamID:"1",  sport:.nfl, city:"Atlanta",     name:"Falcons",      displayName:"Atlanta Falcons",        abbreviation:"ATL"),
    .init(teamID:"2",  sport:.nfl, city:"Buffalo",     name:"Bills",        displayName:"Buffalo Bills",          abbreviation:"BUF"),
    .init(teamID:"3",  sport:.nfl, city:"Chicago",     name:"Bears",        displayName:"Chicago Bears",          abbreviation:"CHI"),
    .init(teamID:"4",  sport:.nfl, city:"Cincinnati",  name:"Bengals",      displayName:"Cincinnati Bengals",     abbreviation:"CIN"),
    .init(teamID:"5",  sport:.nfl, city:"Cleveland",   name:"Browns",       displayName:"Cleveland Browns",       abbreviation:"CLE"),
    .init(teamID:"6",  sport:.nfl, city:"Dallas",      name:"Cowboys",      displayName:"Dallas Cowboys",         abbreviation:"DAL"),
    .init(teamID:"7",  sport:.nfl, city:"Denver",      name:"Broncos",      displayName:"Denver Broncos",         abbreviation:"DEN"),
    .init(teamID:"8",  sport:.nfl, city:"Detroit",     name:"Lions",        displayName:"Detroit Lions",          abbreviation:"DET"),
    .init(teamID:"9",  sport:.nfl, city:"Green Bay",   name:"Packers",      displayName:"Green Bay Packers",      abbreviation:"GB"),
    .init(teamID:"10", sport:.nfl, city:"Tennessee",   name:"Titans",       displayName:"Tennessee Titans",       abbreviation:"TEN"),
    .init(teamID:"11", sport:.nfl, city:"Indianapolis",name:"Colts",        displayName:"Indianapolis Colts",     abbreviation:"IND"),
    .init(teamID:"12", sport:.nfl, city:"Kansas City", name:"Chiefs",       displayName:"Kansas City Chiefs",     abbreviation:"KC"),
    .init(teamID:"13", sport:.nfl, city:"Las Vegas",   name:"Raiders",      displayName:"Las Vegas Raiders",      abbreviation:"LV"),
    .init(teamID:"14", sport:.nfl, city:"Los Angeles", name:"Rams",         displayName:"Los Angeles Rams",       abbreviation:"LAR"),
    .init(teamID:"15", sport:.nfl, city:"Miami",       name:"Dolphins",     displayName:"Miami Dolphins",         abbreviation:"MIA"),
    .init(teamID:"16", sport:.nfl, city:"Minnesota",   name:"Vikings",      displayName:"Minnesota Vikings",      abbreviation:"MIN"),
    .init(teamID:"17", sport:.nfl, city:"New England", name:"Patriots",     displayName:"New England Patriots",   abbreviation:"NE"),
    .init(teamID:"18", sport:.nfl, city:"New Orleans", name:"Saints",       displayName:"New Orleans Saints",     abbreviation:"NO"),
    .init(teamID:"19", sport:.nfl, city:"New York",    name:"Giants",       displayName:"New York Giants",        abbreviation:"NYG"),
    .init(teamID:"20", sport:.nfl, city:"New York",    name:"Jets",         displayName:"New York Jets",          abbreviation:"NYJ"),
    .init(teamID:"21", sport:.nfl, city:"Philadelphia",name:"Eagles",       displayName:"Philadelphia Eagles",    abbreviation:"PHI"),
    .init(teamID:"22", sport:.nfl, city:"Arizona",     name:"Cardinals",    displayName:"Arizona Cardinals",      abbreviation:"ARI"),
    .init(teamID:"23", sport:.nfl, city:"Pittsburgh",  name:"Steelers",     displayName:"Pittsburgh Steelers",    abbreviation:"PIT"),
    .init(teamID:"24", sport:.nfl, city:"Los Angeles", name:"Chargers",     displayName:"Los Angeles Chargers",   abbreviation:"LAC"),
    .init(teamID:"25", sport:.nfl, city:"San Francisco",name:"49ers",       displayName:"San Francisco 49ers",    abbreviation:"SF"),
    .init(teamID:"26", sport:.nfl, city:"Seattle",     name:"Seahawks",     displayName:"Seattle Seahawks",       abbreviation:"SEA"),
    .init(teamID:"27", sport:.nfl, city:"Tampa Bay",   name:"Buccaneers",   displayName:"Tampa Bay Buccaneers",   abbreviation:"TB"),
    .init(teamID:"28", sport:.nfl, city:"Washington",  name:"Commanders",   displayName:"Washington Commanders",  abbreviation:"WSH"),
    .init(teamID:"29", sport:.nfl, city:"Carolina",    name:"Panthers",     displayName:"Carolina Panthers",      abbreviation:"CAR"),
    .init(teamID:"30", sport:.nfl, city:"Jacksonville",name:"Jaguars",      displayName:"Jacksonville Jaguars",   abbreviation:"JAX"),
    .init(teamID:"33", sport:.nfl, city:"Baltimore",   name:"Ravens",       displayName:"Baltimore Ravens",       abbreviation:"BAL"),
    .init(teamID:"34", sport:.nfl, city:"Houston",     name:"Texans",       displayName:"Houston Texans",         abbreviation:"HOU"),
  ]

  private static let nbaTeams: [TeamDefinition] = [
    .init(teamID:"1",  sport:.nba, city:"Atlanta",     name:"Hawks",        displayName:"Atlanta Hawks",          abbreviation:"ATL"),
    .init(teamID:"2",  sport:.nba, city:"Boston",      name:"Celtics",      displayName:"Boston Celtics",         abbreviation:"BOS"),
    .init(teamID:"3",  sport:.nba, city:"New Orleans", name:"Pelicans",     displayName:"New Orleans Pelicans",   abbreviation:"NO"),
    .init(teamID:"4",  sport:.nba, city:"Chicago",     name:"Bulls",        displayName:"Chicago Bulls",          abbreviation:"CHI"),
    .init(teamID:"5",  sport:.nba, city:"Cleveland",   name:"Cavaliers",    displayName:"Cleveland Cavaliers",    abbreviation:"CLE"),
    .init(teamID:"6",  sport:.nba, city:"Dallas",      name:"Mavericks",    displayName:"Dallas Mavericks",       abbreviation:"DAL"),
    .init(teamID:"7",  sport:.nba, city:"Denver",      name:"Nuggets",      displayName:"Denver Nuggets",         abbreviation:"DEN"),
    .init(teamID:"8",  sport:.nba, city:"Detroit",     name:"Pistons",      displayName:"Detroit Pistons",        abbreviation:"DET"),
    .init(teamID:"9",  sport:.nba, city:"Golden State",name:"Warriors",     displayName:"Golden State Warriors",  abbreviation:"GS"),
    .init(teamID:"10", sport:.nba, city:"Houston",     name:"Rockets",      displayName:"Houston Rockets",        abbreviation:"HOU"),
    .init(teamID:"11", sport:.nba, city:"Indiana",     name:"Pacers",       displayName:"Indiana Pacers",         abbreviation:"IND"),
    .init(teamID:"12", sport:.nba, city:"Los Angeles", name:"Clippers",     displayName:"Los Angeles Clippers",   abbreviation:"LAC"),
    .init(teamID:"13", sport:.nba, city:"Los Angeles", name:"Lakers",       displayName:"Los Angeles Lakers",     abbreviation:"LAL"),
    .init(teamID:"14", sport:.nba, city:"Memphis",     name:"Grizzlies",    displayName:"Memphis Grizzlies",      abbreviation:"MEM"),
    .init(teamID:"15", sport:.nba, city:"Miami",       name:"Heat",         displayName:"Miami Heat",             abbreviation:"MIA"),
    .init(teamID:"16", sport:.nba, city:"Milwaukee",   name:"Bucks",        displayName:"Milwaukee Bucks",        abbreviation:"MIL"),
    .init(teamID:"17", sport:.nba, city:"Minnesota",   name:"Timberwolves", displayName:"Minnesota Timberwolves", abbreviation:"MIN"),
    .init(teamID:"18", sport:.nba, city:"Brooklyn",    name:"Nets",         displayName:"Brooklyn Nets",          abbreviation:"BKN"),
    .init(teamID:"19", sport:.nba, city:"New York",    name:"Knicks",       displayName:"New York Knicks",        abbreviation:"NY"),
    .init(teamID:"20", sport:.nba, city:"Orlando",     name:"Magic",        displayName:"Orlando Magic",          abbreviation:"ORL"),
    .init(teamID:"21", sport:.nba, city:"Philadelphia",name:"76ers",        displayName:"Philadelphia 76ers",     abbreviation:"PHI"),
    .init(teamID:"22", sport:.nba, city:"Phoenix",     name:"Suns",         displayName:"Phoenix Suns",           abbreviation:"PHX"),
    .init(teamID:"23", sport:.nba, city:"Portland",    name:"Trail Blazers",displayName:"Portland Trail Blazers", abbreviation:"POR"),
    .init(teamID:"24", sport:.nba, city:"Sacramento",  name:"Kings",        displayName:"Sacramento Kings",       abbreviation:"SAC"),
    .init(teamID:"25", sport:.nba, city:"San Antonio", name:"Spurs",        displayName:"San Antonio Spurs",      abbreviation:"SA"),
    .init(teamID:"26", sport:.nba, city:"Oklahoma City",name:"Thunder",     displayName:"Oklahoma City Thunder",  abbreviation:"OKC"),
    .init(teamID:"27", sport:.nba, city:"Utah",        name:"Jazz",         displayName:"Utah Jazz",              abbreviation:"UTAH"),
    .init(teamID:"28", sport:.nba, city:"Washington",  name:"Wizards",      displayName:"Washington Wizards",     abbreviation:"WSH"),
    .init(teamID:"29", sport:.nba, city:"Toronto",     name:"Raptors",      displayName:"Toronto Raptors",        abbreviation:"TOR"),
  ]

  // MLS and Premier League teams use ESPN numeric IDs from the API, not fixed IDs.
  // Populated from ESPN API at first launch and cached. Placeholder entries below
  // are overwritten by the live fetch. The IDs here match what the pipeline collected.
  private static let mlsTeams: [TeamDefinition] = [
    .init(teamID:"18418", sport:.mls, city:"Atlanta",      name:"United",       displayName:"Atlanta United",         abbreviation:"ATL"),
    .init(teamID:"20906", sport:.mls, city:"Austin",       name:"FC",           displayName:"Austin FC",              abbreviation:"ATX"),
    .init(teamID:"9720",  sport:.mls, city:"Montreal",     name:"CF",           displayName:"CF Montréal",            abbreviation:"MTL"),
    .init(teamID:"21300", sport:.mls, city:"Charlotte",    name:"FC",           displayName:"Charlotte FC",           abbreviation:"CLT"),
    .init(teamID:"182",   sport:.mls, city:"Chicago",      name:"Fire",         displayName:"Chicago Fire",           abbreviation:"CHI"),
    .init(teamID:"184",   sport:.mls, city:"Colorado",     name:"Rapids",       displayName:"Colorado Rapids",        abbreviation:"COL"),
    .init(teamID:"183",   sport:.mls, city:"Columbus",     name:"Crew",         displayName:"Columbus Crew",          abbreviation:"CLB"),
    .init(teamID:"193",   sport:.mls, city:"DC",           name:"United",       displayName:"DC United",              abbreviation:"DC"),
    .init(teamID:"18267", sport:.mls, city:"Cincinnati",   name:"FC",           displayName:"FC Cincinnati",          abbreviation:"CIN"),
    .init(teamID:"185",   sport:.mls, city:"Dallas",       name:"FC",           displayName:"FC Dallas",              abbreviation:"DAL"),
    .init(teamID:"6077",  sport:.mls, city:"Houston",      name:"Dynamo",       displayName:"Houston Dynamo",         abbreviation:"HOU"),
    .init(teamID:"20232", sport:.mls, city:"Miami",        name:"Inter",        displayName:"Inter Miami CF",         abbreviation:"MIA"),
    .init(teamID:"187",   sport:.mls, city:"Los Angeles",  name:"Galaxy",       displayName:"LA Galaxy",              abbreviation:"LA"),
    .init(teamID:"18966", sport:.mls, city:"Los Angeles",  name:"FC",           displayName:"LAFC",                   abbreviation:"LAFC"),
    .init(teamID:"17362", sport:.mls, city:"Minnesota",    name:"United",       displayName:"Minnesota United",       abbreviation:"MIN"),
    .init(teamID:"18986", sport:.mls, city:"Nashville",    name:"SC",           displayName:"Nashville SC",           abbreviation:"NSH"),
    .init(teamID:"189",   sport:.mls, city:"New England",  name:"Revolution",   displayName:"New England Revolution", abbreviation:"NE"),
    .init(teamID:"17606", sport:.mls, city:"New York",     name:"City FC",      displayName:"New York City FC",       abbreviation:"NYC"),
    .init(teamID:"12011", sport:.mls, city:"Orlando",      name:"City",         displayName:"Orlando City",           abbreviation:"ORL"),
    .init(teamID:"10739", sport:.mls, city:"Philadelphia", name:"Union",        displayName:"Philadelphia Union",     abbreviation:"PHI"),
    .init(teamID:"9723",  sport:.mls, city:"Portland",     name:"Timbers",      displayName:"Portland Timbers",       abbreviation:"POR"),
    .init(teamID:"4771",  sport:.mls, city:"Real Salt Lake",name:"",            displayName:"Real Salt Lake",         abbreviation:"RSL"),
    .init(teamID:"190",   sport:.mls, city:"New York",     name:"Red Bulls",    displayName:"New York Red Bulls",     abbreviation:"RBNY"),
    .init(teamID:"22529", sport:.mls, city:"San Diego",    name:"FC",           displayName:"San Diego FC",           abbreviation:"SD"),
    .init(teamID:"191",   sport:.mls, city:"San Jose",     name:"Earthquakes",  displayName:"San Jose Earthquakes",   abbreviation:"SJ"),
    .init(teamID:"9726",  sport:.mls, city:"Seattle",      name:"Sounders",     displayName:"Seattle Sounders",       abbreviation:"SEA"),
    .init(teamID:"186",   sport:.mls, city:"Sporting",     name:"Kansas City",  displayName:"Sporting Kansas City",   abbreviation:"SKC"),
    .init(teamID:"21812", sport:.mls, city:"St. Louis",    name:"City",         displayName:"St. Louis City SC",      abbreviation:"STL"),
    .init(teamID:"7318",  sport:.mls, city:"Toronto",      name:"FC",           displayName:"Toronto FC",             abbreviation:"TOR"),
    .init(teamID:"9727",  sport:.mls, city:"Vancouver",    name:"Whitecaps",    displayName:"Vancouver Whitecaps",    abbreviation:"VAN"),
  ]

  private static let premierLeagueTeams: [TeamDefinition] = [
    .init(teamID:"349", sport:.premierLeague, city:"",              name:"Bournemouth",    displayName:"AFC Bournemouth",        abbreviation:"BOU"),
    .init(teamID:"359", sport:.premierLeague, city:"",              name:"Arsenal",        displayName:"Arsenal",                abbreviation:"ARS"),
    .init(teamID:"362", sport:.premierLeague, city:"",              name:"Aston Villa",    displayName:"Aston Villa",            abbreviation:"AVL"),
    .init(teamID:"337", sport:.premierLeague, city:"",              name:"Brentford",      displayName:"Brentford",              abbreviation:"BRE"),
    .init(teamID:"331", sport:.premierLeague, city:"Brighton",      name:"& Hove Albion",  displayName:"Brighton & Hove Albion", abbreviation:"BHA"),
    .init(teamID:"363", sport:.premierLeague, city:"",              name:"Chelsea",        displayName:"Chelsea",                abbreviation:"CHE"),
    .init(teamID:"384", sport:.premierLeague, city:"Crystal",       name:"Palace",         displayName:"Crystal Palace",         abbreviation:"CRY"),
    .init(teamID:"368", sport:.premierLeague, city:"",              name:"Everton",        displayName:"Everton",                abbreviation:"EVE"),
    .init(teamID:"370", sport:.premierLeague, city:"",              name:"Fulham",         displayName:"Fulham",                 abbreviation:"FUL"),
    .init(teamID:"364", sport:.premierLeague, city:"",              name:"Liverpool",      displayName:"Liverpool",              abbreviation:"LIV"),
    .init(teamID:"382", sport:.premierLeague, city:"Manchester",    name:"City",           displayName:"Manchester City",        abbreviation:"MNC"),
    .init(teamID:"360", sport:.premierLeague, city:"Manchester",    name:"United",         displayName:"Manchester United",      abbreviation:"MAN"),
    .init(teamID:"361", sport:.premierLeague, city:"Newcastle",     name:"United",         displayName:"Newcastle United",       abbreviation:"NEW"),
    .init(teamID:"393", sport:.premierLeague, city:"Nottingham",    name:"Forest",         displayName:"Nottingham Forest",      abbreviation:"NFO"),
    .init(teamID:"367", sport:.premierLeague, city:"",              name:"Tottenham",      displayName:"Tottenham Hotspur",      abbreviation:"TOT"),
    .init(teamID:"371", sport:.premierLeague, city:"West Ham",      name:"United",         displayName:"West Ham United",        abbreviation:"WHU"),
    .init(teamID:"380", sport:.premierLeague, city:"",              name:"Wolves",         displayName:"Wolverhampton Wanderers",abbreviation:"WOL"),
  ]

  // One entry per driver. espnTeamID is the shared ESPN team ID for schedule fetching.
  // Update lineups each winter.
  private static let f1Teams: [TeamDefinition] = [
    .init(teamID:"106842_hamilton",   sport:.f1, city:"", name:"Ferrari",       displayName:"Ferrari",       abbreviation:"FER", driverNames:["Hamilton"],    espnTeamID:"106842"),
    .init(teamID:"106842_leclerc",    sport:.f1, city:"", name:"Ferrari",       displayName:"Ferrari",       abbreviation:"FER", driverNames:["Leclerc"],     espnTeamID:"106842"),
    .init(teamID:"106892_norris",     sport:.f1, city:"", name:"McLaren",       displayName:"McLaren",       abbreviation:"MCL", driverNames:["Norris"],      espnTeamID:"106892"),
    .init(teamID:"106892_piastri",    sport:.f1, city:"", name:"McLaren",       displayName:"McLaren",       abbreviation:"MCL", driverNames:["Piastri"],     espnTeamID:"106892"),
    .init(teamID:"106893_russell",    sport:.f1, city:"", name:"Mercedes",      displayName:"Mercedes",      abbreviation:"MER", driverNames:["Russell"],     espnTeamID:"106893"),
    .init(teamID:"106893_antonelli",  sport:.f1, city:"", name:"Mercedes",      displayName:"Mercedes",      abbreviation:"MER", driverNames:["Antonelli"],   espnTeamID:"106893"),
    .init(teamID:"106921_verstappen", sport:.f1, city:"", name:"Red Bull",      displayName:"Red Bull",      abbreviation:"RBR", driverNames:["Verstappen"],  espnTeamID:"106921"),
    .init(teamID:"106921_tsunoda",    sport:.f1, city:"", name:"Red Bull",      displayName:"Red Bull",      abbreviation:"RBR", driverNames:["Tsunoda"],     espnTeamID:"106921"),
    .init(teamID:"106922_gasly",      sport:.f1, city:"", name:"Alpine",        displayName:"Alpine",        abbreviation:"ALP", driverNames:["Gasly"],       espnTeamID:"106922"),
    .init(teamID:"106922_doohan",     sport:.f1, city:"", name:"Alpine",        displayName:"Alpine",        abbreviation:"ALP", driverNames:["Doohan"],      espnTeamID:"106922"),
    .init(teamID:"123986_alonso",     sport:.f1, city:"", name:"Aston Martin",  displayName:"Aston Martin",  abbreviation:"AM",  driverNames:["Alonso"],      espnTeamID:"123986"),
    .init(teamID:"123986_stroll",     sport:.f1, city:"", name:"Aston Martin",  displayName:"Aston Martin",  abbreviation:"AM",  driverNames:["Stroll"],      espnTeamID:"123986"),
    .init(teamID:"111427_hulkenberg", sport:.f1, city:"", name:"Haas",          displayName:"Haas",          abbreviation:"HAS", driverNames:["Hülkenberg"],  espnTeamID:"111427"),
    .init(teamID:"111427_bearman",    sport:.f1, city:"", name:"Haas",          displayName:"Haas",          abbreviation:"HAS", driverNames:["Bearman"],     espnTeamID:"111427"),
    .init(teamID:"106967_albon",      sport:.f1, city:"", name:"Williams",      displayName:"Williams",      abbreviation:"WIL", driverNames:["Albon"],       espnTeamID:"106967"),
    .init(teamID:"106967_sainz",      sport:.f1, city:"", name:"Williams",      displayName:"Williams",      abbreviation:"WIL", driverNames:["Sainz"],       espnTeamID:"106967"),
    .init(teamID:"123988_hadjar",     sport:.f1, city:"", name:"Racing Bulls",  displayName:"Racing Bulls",  abbreviation:"RB",  driverNames:["Hadjar"],      espnTeamID:"123988"),
    .init(teamID:"123988_lawson",     sport:.f1, city:"", name:"Racing Bulls",  displayName:"Racing Bulls",  abbreviation:"RB",  driverNames:["Lawson"],      espnTeamID:"123988"),
  ]

  // One entry per rider. Update each winter.
  private static let motoGPTeams: [TeamDefinition] = [
    .init(teamID:"motogp_ducati_bagnaia",    sport:.motoGP, city:"", name:"Ducati Lenovo",  displayName:"Ducati Lenovo",  abbreviation:"DUC", driverNames:["Bagnaia"],          espnTeamID:"motogp_ducati_lenovo"),
    .init(teamID:"motogp_ducati_mmarquez",   sport:.motoGP, city:"", name:"Ducati Lenovo",  displayName:"Ducati Lenovo",  abbreviation:"DUC", driverNames:["M.Marquez"],        espnTeamID:"motogp_ducati_lenovo"),
    .init(teamID:"motogp_pramac_martin",     sport:.motoGP, city:"", name:"Prima Pramac",   displayName:"Prima Pramac",   abbreviation:"PRM", driverNames:["Martin"],           espnTeamID:"motogp_pramac"),
    .init(teamID:"motogp_pramac_zarco",      sport:.motoGP, city:"", name:"Prima Pramac",   displayName:"Prima Pramac",   abbreviation:"PRM", driverNames:["Zarco"],            espnTeamID:"motogp_pramac"),
    .init(teamID:"motogp_aprilia_aleix",     sport:.motoGP, city:"", name:"Aprilia Racing", displayName:"Aprilia Racing", abbreviation:"APR", driverNames:["Aleix"],            espnTeamID:"motogp_aprilia"),
    .init(teamID:"motogp_aprilia_vinales",   sport:.motoGP, city:"", name:"Aprilia Racing", displayName:"Aprilia Racing", abbreviation:"APR", driverNames:["Vinales"],          espnTeamID:"motogp_aprilia"),
    .init(teamID:"motogp_ktm_binder",        sport:.motoGP, city:"", name:"Red Bull KTM",   displayName:"Red Bull KTM",   abbreviation:"KTM", driverNames:["Binder"],           espnTeamID:"motogp_ktm"),
    .init(teamID:"motogp_ktm_acosta",        sport:.motoGP, city:"", name:"Red Bull KTM",   displayName:"Red Bull KTM",   abbreviation:"KTM", driverNames:["Acosta"],           espnTeamID:"motogp_ktm"),
    .init(teamID:"motogp_gresini_amarquez",  sport:.motoGP, city:"", name:"Gresini Racing", displayName:"Gresini Racing", abbreviation:"GRS", driverNames:["A.Marquez"],        espnTeamID:"motogp_gresini"),
    .init(teamID:"motogp_gresini_dg",        sport:.motoGP, city:"", name:"Gresini Racing", displayName:"Gresini Racing", abbreviation:"GRS", driverNames:["Di Giannantonio"],  espnTeamID:"motogp_gresini"),
    .init(teamID:"motogp_vr46_bezzecchi",    sport:.motoGP, city:"", name:"VR46",           displayName:"Mooney VR46",    abbreviation:"VR46",driverNames:["Bezzecchi"],        espnTeamID:"motogp_vr46"),
    .init(teamID:"motogp_vr46_marini",       sport:.motoGP, city:"", name:"VR46",           displayName:"Mooney VR46",    abbreviation:"VR46",driverNames:["Marini"],           espnTeamID:"motogp_vr46"),
    .init(teamID:"motogp_honda_mir",         sport:.motoGP, city:"", name:"Repsol Honda",   displayName:"Repsol Honda",   abbreviation:"HRC", driverNames:["Mir"],              espnTeamID:"motogp_honda_repsol"),
    .init(teamID:"motogp_honda_marini2",     sport:.motoGP, city:"", name:"Repsol Honda",   displayName:"Repsol Honda",   abbreviation:"HRC", driverNames:["Marini"],           espnTeamID:"motogp_honda_repsol"),
    .init(teamID:"motogp_yamaha_quartararo", sport:.motoGP, city:"", name:"Monster Yamaha", displayName:"Monster Yamaha", abbreviation:"YAM", driverNames:["Quartararo"],       espnTeamID:"motogp_yamaha"),
    .init(teamID:"motogp_yamaha_morbidelli", sport:.motoGP, city:"", name:"Monster Yamaha", displayName:"Monster Yamaha", abbreviation:"YAM", driverNames:["Morbidelli"],       espnTeamID:"motogp_yamaha"),
  ]
}

// MARK: - Lookup helpers

extension TeamCatalog {
  static func defaultTeam() -> TeamDefinition {
    team(withCompositeID: defaultTeamCompositeID) ?? teams[0]
  }

  static func team(withCompositeID compositeID: String) -> TeamDefinition? {
    teams.first { $0.compositeID == compositeID }
  }

  /// Convenience alias used throughout views and parsers.
  static func team(for compositeID: String) -> TeamDefinition? {
    team(withCompositeID: compositeID)
  }

  /// All teams, sorted alphabetically.
  static var all: [TeamDefinition] { teams.sorted { $0.displayName < $1.displayName } }

  static func canonicalCompositeID(for rawID: String) -> String? {
    team(withCompositeID: rawID)?.compositeID
  }

  static func teams(for sport: SupportedSport) -> [TeamDefinition] {
    teams.filter { $0.sport == sport }
  }

  static func widgetConfigurationTeams(settings: AppSettings) -> [TeamDefinition] {
    let favorites = settings.favoriteTeamCompositeIDs.compactMap(team(withCompositeID:))
    if !favorites.isEmpty { return favorites }
    return teams
  }

  static func widgetPickerTeams(settings: AppSettings) -> [TeamDefinition] {
    prioritizedWidgetConfigurationTeams(from: teams, settings: settings)
  }

  static func prioritizedWidgetConfigurationTeams(
    from candidates: [TeamDefinition],
    settings: AppSettings,
    pinnedCompositeIDs: [String] = []
  ) -> [TeamDefinition] {
    let favoriteSet = Set(settings.favoriteTeamCompositeIDs)
    let pinnedSet = Set(pinnedCompositeIDs)

    return candidates.sorted { lhs, rhs in
      let lhsPinned = pinnedSet.contains(lhs.compositeID)
      let rhsPinned = pinnedSet.contains(rhs.compositeID)
      if lhsPinned != rhsPinned { return lhsPinned }

      let lhsFav = favoriteSet.contains(lhs.compositeID)
      let rhsFav = favoriteSet.contains(rhs.compositeID)
      if lhsFav != rhsFav { return lhsFav }

      return lhs.displayName < rhs.displayName
    }
  }

  static func resolveWidgetSelectionTeam(
    configuredCompositeID: String?,
    settings: AppSettings
  ) -> TeamDefinition {
    if let id = configuredCompositeID, let team = team(withCompositeID: id) {
      return team
    }
    return defaultTeam()
  }
}
