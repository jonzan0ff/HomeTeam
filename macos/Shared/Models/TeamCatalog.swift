import Foundation

enum SupportedSport: String, CaseIterable, Codable, Hashable {
  case nhl
  case mlb
  case nfl
  case nba
  case mls
  case f1
  case motogp
  case premierLeague

  var displayName: String {
    switch self {
    case .nhl: return "NHL"
    case .mlb: return "MLB"
    case .nfl: return "NFL"
    case .nba: return "NBA"
    case .mls: return "MLS"
    case .f1: return "F1"
    case .motogp: return "MotoGP"
    case .premierLeague: return "Premier League"
    }
  }

  var sportPath: String {
    switch self {
    case .nhl: return "hockey"
    case .mlb: return "baseball"
    case .nfl: return "football"
    case .nba: return "basketball"
    case .mls, .premierLeague: return "soccer"
    case .f1, .motogp: return "racing"
    }
  }

  var leaguePath: String {
    switch self {
    case .nhl: return "nhl"
    case .mlb: return "mlb"
    case .nfl: return "nfl"
    case .nba: return "nba"
    case .mls: return "usa.1"
    case .f1: return "f1"
    case .motogp: return "motogp"
    case .premierLeague: return "eng.1"
    }
  }
}

struct TeamDefinition: Codable, Hashable, Identifiable {
  let id: String
  let sport: SupportedSport
  let city: String
  let name: String
  let displayName: String
  let abbreviation: String

  var compositeID: String {
    "\(sport.rawValue):\(id)"
  }

  var shortLabel: String {
    city.isEmpty ? displayName : "\(city) \(name)"
  }

  var searchText: String {
    [displayName, city, name, abbreviation, sport.displayName].joined(separator: " ").lowercased()
  }

  var scheduleURL: URL? {
    URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sport.sportPath)/\(sport.leaguePath)/teams/\(id)/schedule")
  }
}

enum TeamCatalog {
  static let defaultTeamCompositeID = "nhl:23"

  static let teams: [TeamDefinition] = [
    TeamDefinition(id: "25", sport: .nhl, city: "Anaheim", name: "Ducks", displayName: "Anaheim Ducks", abbreviation: "ANA"),
    TeamDefinition(id: "1", sport: .nhl, city: "Boston", name: "Bruins", displayName: "Boston Bruins", abbreviation: "BOS"),
    TeamDefinition(id: "2", sport: .nhl, city: "Buffalo", name: "Sabres", displayName: "Buffalo Sabres", abbreviation: "BUF"),
    TeamDefinition(id: "3", sport: .nhl, city: "Calgary", name: "Flames", displayName: "Calgary Flames", abbreviation: "CGY"),
    TeamDefinition(id: "7", sport: .nhl, city: "Carolina", name: "Hurricanes", displayName: "Carolina Hurricanes", abbreviation: "CAR"),
    TeamDefinition(id: "4", sport: .nhl, city: "Chicago", name: "Blackhawks", displayName: "Chicago Blackhawks", abbreviation: "CHI"),
    TeamDefinition(id: "17", sport: .nhl, city: "Colorado", name: "Avalanche", displayName: "Colorado Avalanche", abbreviation: "COL"),
    TeamDefinition(id: "29", sport: .nhl, city: "Columbus", name: "Blue Jackets", displayName: "Columbus Blue Jackets", abbreviation: "CBJ"),
    TeamDefinition(id: "9", sport: .nhl, city: "Dallas", name: "Stars", displayName: "Dallas Stars", abbreviation: "DAL"),
    TeamDefinition(id: "5", sport: .nhl, city: "Detroit", name: "Red Wings", displayName: "Detroit Red Wings", abbreviation: "DET"),
    TeamDefinition(id: "6", sport: .nhl, city: "Edmonton", name: "Oilers", displayName: "Edmonton Oilers", abbreviation: "EDM"),
    TeamDefinition(id: "26", sport: .nhl, city: "Florida", name: "Panthers", displayName: "Florida Panthers", abbreviation: "FLA"),
    TeamDefinition(id: "8", sport: .nhl, city: "Los Angeles", name: "Kings", displayName: "Los Angeles Kings", abbreviation: "LA"),
    TeamDefinition(id: "30", sport: .nhl, city: "Minnesota", name: "Wild", displayName: "Minnesota Wild", abbreviation: "MIN"),
    TeamDefinition(id: "10", sport: .nhl, city: "Montreal", name: "Canadiens", displayName: "Montreal Canadiens", abbreviation: "MTL"),
    TeamDefinition(id: "27", sport: .nhl, city: "Nashville", name: "Predators", displayName: "Nashville Predators", abbreviation: "NSH"),
    TeamDefinition(id: "11", sport: .nhl, city: "New Jersey", name: "Devils", displayName: "New Jersey Devils", abbreviation: "NJ"),
    TeamDefinition(id: "12", sport: .nhl, city: "New York", name: "Islanders", displayName: "New York Islanders", abbreviation: "NYI"),
    TeamDefinition(id: "13", sport: .nhl, city: "New York", name: "Rangers", displayName: "New York Rangers", abbreviation: "NYR"),
    TeamDefinition(id: "14", sport: .nhl, city: "Ottawa", name: "Senators", displayName: "Ottawa Senators", abbreviation: "OTT"),
    TeamDefinition(id: "15", sport: .nhl, city: "Philadelphia", name: "Flyers", displayName: "Philadelphia Flyers", abbreviation: "PHI"),
    TeamDefinition(id: "16", sport: .nhl, city: "Pittsburgh", name: "Penguins", displayName: "Pittsburgh Penguins", abbreviation: "PIT"),
    TeamDefinition(id: "18", sport: .nhl, city: "San Jose", name: "Sharks", displayName: "San Jose Sharks", abbreviation: "SJ"),
    TeamDefinition(id: "124292", sport: .nhl, city: "Seattle", name: "Kraken", displayName: "Seattle Kraken", abbreviation: "SEA"),
    TeamDefinition(id: "19", sport: .nhl, city: "St. Louis", name: "Blues", displayName: "St. Louis Blues", abbreviation: "STL"),
    TeamDefinition(id: "20", sport: .nhl, city: "Tampa Bay", name: "Lightning", displayName: "Tampa Bay Lightning", abbreviation: "TB"),
    TeamDefinition(id: "21", sport: .nhl, city: "Toronto", name: "Maple Leafs", displayName: "Toronto Maple Leafs", abbreviation: "TOR"),
    TeamDefinition(id: "129764", sport: .nhl, city: "Utah", name: "Mammoth", displayName: "Utah Mammoth", abbreviation: "UTAH"),
    TeamDefinition(id: "22", sport: .nhl, city: "Vancouver", name: "Canucks", displayName: "Vancouver Canucks", abbreviation: "VAN"),
    TeamDefinition(id: "37", sport: .nhl, city: "Vegas", name: "Golden Knights", displayName: "Vegas Golden Knights", abbreviation: "VGK"),
    TeamDefinition(id: "23", sport: .nhl, city: "Washington", name: "Capitals", displayName: "Washington Capitals", abbreviation: "WSH"),
    TeamDefinition(id: "28", sport: .nhl, city: "Winnipeg", name: "Jets", displayName: "Winnipeg Jets", abbreviation: "WPG"),
    TeamDefinition(id: "29", sport: .mlb, city: "Arizona", name: "Diamondbacks", displayName: "Arizona Diamondbacks", abbreviation: "ARI"),
    TeamDefinition(id: "11", sport: .mlb, city: "Athletics", name: "Athletics", displayName: "Athletics", abbreviation: "ATH"),
    TeamDefinition(id: "15", sport: .mlb, city: "Atlanta", name: "Braves", displayName: "Atlanta Braves", abbreviation: "ATL"),
    TeamDefinition(id: "1", sport: .mlb, city: "Baltimore", name: "Orioles", displayName: "Baltimore Orioles", abbreviation: "BAL"),
    TeamDefinition(id: "2", sport: .mlb, city: "Boston", name: "Red Sox", displayName: "Boston Red Sox", abbreviation: "BOS"),
    TeamDefinition(id: "16", sport: .mlb, city: "Chicago", name: "Cubs", displayName: "Chicago Cubs", abbreviation: "CHC"),
    TeamDefinition(id: "4", sport: .mlb, city: "Chicago", name: "White Sox", displayName: "Chicago White Sox", abbreviation: "CHW"),
    TeamDefinition(id: "17", sport: .mlb, city: "Cincinnati", name: "Reds", displayName: "Cincinnati Reds", abbreviation: "CIN"),
    TeamDefinition(id: "5", sport: .mlb, city: "Cleveland", name: "Guardians", displayName: "Cleveland Guardians", abbreviation: "CLE"),
    TeamDefinition(id: "27", sport: .mlb, city: "Colorado", name: "Rockies", displayName: "Colorado Rockies", abbreviation: "COL"),
    TeamDefinition(id: "6", sport: .mlb, city: "Detroit", name: "Tigers", displayName: "Detroit Tigers", abbreviation: "DET"),
    TeamDefinition(id: "18", sport: .mlb, city: "Houston", name: "Astros", displayName: "Houston Astros", abbreviation: "HOU"),
    TeamDefinition(id: "7", sport: .mlb, city: "Kansas City", name: "Royals", displayName: "Kansas City Royals", abbreviation: "KC"),
    TeamDefinition(id: "3", sport: .mlb, city: "Los Angeles", name: "Angels", displayName: "Los Angeles Angels", abbreviation: "LAA"),
    TeamDefinition(id: "19", sport: .mlb, city: "Los Angeles", name: "Dodgers", displayName: "Los Angeles Dodgers", abbreviation: "LAD"),
    TeamDefinition(id: "28", sport: .mlb, city: "Miami", name: "Marlins", displayName: "Miami Marlins", abbreviation: "MIA"),
    TeamDefinition(id: "8", sport: .mlb, city: "Milwaukee", name: "Brewers", displayName: "Milwaukee Brewers", abbreviation: "MIL"),
    TeamDefinition(id: "9", sport: .mlb, city: "Minnesota", name: "Twins", displayName: "Minnesota Twins", abbreviation: "MIN"),
    TeamDefinition(id: "21", sport: .mlb, city: "New York", name: "Mets", displayName: "New York Mets", abbreviation: "NYM"),
    TeamDefinition(id: "10", sport: .mlb, city: "New York", name: "Yankees", displayName: "New York Yankees", abbreviation: "NYY"),
    TeamDefinition(id: "22", sport: .mlb, city: "Philadelphia", name: "Phillies", displayName: "Philadelphia Phillies", abbreviation: "PHI"),
    TeamDefinition(id: "23", sport: .mlb, city: "Pittsburgh", name: "Pirates", displayName: "Pittsburgh Pirates", abbreviation: "PIT"),
    TeamDefinition(id: "25", sport: .mlb, city: "San Diego", name: "Padres", displayName: "San Diego Padres", abbreviation: "SD"),
    TeamDefinition(id: "26", sport: .mlb, city: "San Francisco", name: "Giants", displayName: "San Francisco Giants", abbreviation: "SF"),
    TeamDefinition(id: "12", sport: .mlb, city: "Seattle", name: "Mariners", displayName: "Seattle Mariners", abbreviation: "SEA"),
    TeamDefinition(id: "24", sport: .mlb, city: "St. Louis", name: "Cardinals", displayName: "St. Louis Cardinals", abbreviation: "STL"),
    TeamDefinition(id: "30", sport: .mlb, city: "Tampa Bay", name: "Rays", displayName: "Tampa Bay Rays", abbreviation: "TB"),
    TeamDefinition(id: "13", sport: .mlb, city: "Texas", name: "Rangers", displayName: "Texas Rangers", abbreviation: "TEX"),
    TeamDefinition(id: "14", sport: .mlb, city: "Toronto", name: "Blue Jays", displayName: "Toronto Blue Jays", abbreviation: "TOR"),
    TeamDefinition(id: "20", sport: .mlb, city: "Washington", name: "Nationals", displayName: "Washington Nationals", abbreviation: "WSH"),
    TeamDefinition(id: "22", sport: .nfl, city: "Arizona", name: "Cardinals", displayName: "Arizona Cardinals", abbreviation: "ARI"),
    TeamDefinition(id: "1", sport: .nfl, city: "Atlanta", name: "Falcons", displayName: "Atlanta Falcons", abbreviation: "ATL"),
    TeamDefinition(id: "33", sport: .nfl, city: "Baltimore", name: "Ravens", displayName: "Baltimore Ravens", abbreviation: "BAL"),
    TeamDefinition(id: "2", sport: .nfl, city: "Buffalo", name: "Bills", displayName: "Buffalo Bills", abbreviation: "BUF"),
    TeamDefinition(id: "29", sport: .nfl, city: "Carolina", name: "Panthers", displayName: "Carolina Panthers", abbreviation: "CAR"),
    TeamDefinition(id: "3", sport: .nfl, city: "Chicago", name: "Bears", displayName: "Chicago Bears", abbreviation: "CHI"),
    TeamDefinition(id: "4", sport: .nfl, city: "Cincinnati", name: "Bengals", displayName: "Cincinnati Bengals", abbreviation: "CIN"),
    TeamDefinition(id: "5", sport: .nfl, city: "Cleveland", name: "Browns", displayName: "Cleveland Browns", abbreviation: "CLE"),
    TeamDefinition(id: "6", sport: .nfl, city: "Dallas", name: "Cowboys", displayName: "Dallas Cowboys", abbreviation: "DAL"),
    TeamDefinition(id: "7", sport: .nfl, city: "Denver", name: "Broncos", displayName: "Denver Broncos", abbreviation: "DEN"),
    TeamDefinition(id: "8", sport: .nfl, city: "Detroit", name: "Lions", displayName: "Detroit Lions", abbreviation: "DET"),
    TeamDefinition(id: "9", sport: .nfl, city: "Green Bay", name: "Packers", displayName: "Green Bay Packers", abbreviation: "GB"),
    TeamDefinition(id: "34", sport: .nfl, city: "Houston", name: "Texans", displayName: "Houston Texans", abbreviation: "HOU"),
    TeamDefinition(id: "11", sport: .nfl, city: "Indianapolis", name: "Colts", displayName: "Indianapolis Colts", abbreviation: "IND"),
    TeamDefinition(id: "30", sport: .nfl, city: "Jacksonville", name: "Jaguars", displayName: "Jacksonville Jaguars", abbreviation: "JAX"),
    TeamDefinition(id: "12", sport: .nfl, city: "Kansas City", name: "Chiefs", displayName: "Kansas City Chiefs", abbreviation: "KC"),
    TeamDefinition(id: "13", sport: .nfl, city: "Las Vegas", name: "Raiders", displayName: "Las Vegas Raiders", abbreviation: "LV"),
    TeamDefinition(id: "24", sport: .nfl, city: "Los Angeles", name: "Chargers", displayName: "Los Angeles Chargers", abbreviation: "LAC"),
    TeamDefinition(id: "14", sport: .nfl, city: "Los Angeles", name: "Rams", displayName: "Los Angeles Rams", abbreviation: "LAR"),
    TeamDefinition(id: "15", sport: .nfl, city: "Miami", name: "Dolphins", displayName: "Miami Dolphins", abbreviation: "MIA"),
    TeamDefinition(id: "16", sport: .nfl, city: "Minnesota", name: "Vikings", displayName: "Minnesota Vikings", abbreviation: "MIN"),
    TeamDefinition(id: "17", sport: .nfl, city: "New England", name: "Patriots", displayName: "New England Patriots", abbreviation: "NE"),
    TeamDefinition(id: "18", sport: .nfl, city: "New Orleans", name: "Saints", displayName: "New Orleans Saints", abbreviation: "NO"),
    TeamDefinition(id: "19", sport: .nfl, city: "New York", name: "Giants", displayName: "New York Giants", abbreviation: "NYG"),
    TeamDefinition(id: "20", sport: .nfl, city: "New York", name: "Jets", displayName: "New York Jets", abbreviation: "NYJ"),
    TeamDefinition(id: "21", sport: .nfl, city: "Philadelphia", name: "Eagles", displayName: "Philadelphia Eagles", abbreviation: "PHI"),
    TeamDefinition(id: "23", sport: .nfl, city: "Pittsburgh", name: "Steelers", displayName: "Pittsburgh Steelers", abbreviation: "PIT"),
    TeamDefinition(id: "25", sport: .nfl, city: "San Francisco", name: "49ers", displayName: "San Francisco 49ers", abbreviation: "SF"),
    TeamDefinition(id: "26", sport: .nfl, city: "Seattle", name: "Seahawks", displayName: "Seattle Seahawks", abbreviation: "SEA"),
    TeamDefinition(id: "27", sport: .nfl, city: "Tampa Bay", name: "Buccaneers", displayName: "Tampa Bay Buccaneers", abbreviation: "TB"),
    TeamDefinition(id: "10", sport: .nfl, city: "Tennessee", name: "Titans", displayName: "Tennessee Titans", abbreviation: "TEN"),
    TeamDefinition(id: "28", sport: .nfl, city: "Washington", name: "Commanders", displayName: "Washington Commanders", abbreviation: "WSH"),
    TeamDefinition(id: "1", sport: .nba, city: "Atlanta", name: "Hawks", displayName: "Atlanta Hawks", abbreviation: "ATL"),
    TeamDefinition(id: "2", sport: .nba, city: "Boston", name: "Celtics", displayName: "Boston Celtics", abbreviation: "BOS"),
    TeamDefinition(id: "17", sport: .nba, city: "Brooklyn", name: "Nets", displayName: "Brooklyn Nets", abbreviation: "BKN"),
    TeamDefinition(id: "30", sport: .nba, city: "Charlotte", name: "Hornets", displayName: "Charlotte Hornets", abbreviation: "CHA"),
    TeamDefinition(id: "4", sport: .nba, city: "Chicago", name: "Bulls", displayName: "Chicago Bulls", abbreviation: "CHI"),
    TeamDefinition(id: "5", sport: .nba, city: "Cleveland", name: "Cavaliers", displayName: "Cleveland Cavaliers", abbreviation: "CLE"),
    TeamDefinition(id: "6", sport: .nba, city: "Dallas", name: "Mavericks", displayName: "Dallas Mavericks", abbreviation: "DAL"),
    TeamDefinition(id: "7", sport: .nba, city: "Denver", name: "Nuggets", displayName: "Denver Nuggets", abbreviation: "DEN"),
    TeamDefinition(id: "8", sport: .nba, city: "Detroit", name: "Pistons", displayName: "Detroit Pistons", abbreviation: "DET"),
    TeamDefinition(id: "9", sport: .nba, city: "Golden State", name: "Warriors", displayName: "Golden State Warriors", abbreviation: "GS"),
    TeamDefinition(id: "10", sport: .nba, city: "Houston", name: "Rockets", displayName: "Houston Rockets", abbreviation: "HOU"),
    TeamDefinition(id: "11", sport: .nba, city: "Indiana", name: "Pacers", displayName: "Indiana Pacers", abbreviation: "IND"),
    TeamDefinition(id: "12", sport: .nba, city: "LA", name: "Clippers", displayName: "LA Clippers", abbreviation: "LAC"),
    TeamDefinition(id: "13", sport: .nba, city: "Los Angeles", name: "Lakers", displayName: "Los Angeles Lakers", abbreviation: "LAL"),
    TeamDefinition(id: "29", sport: .nba, city: "Memphis", name: "Grizzlies", displayName: "Memphis Grizzlies", abbreviation: "MEM"),
    TeamDefinition(id: "14", sport: .nba, city: "Miami", name: "Heat", displayName: "Miami Heat", abbreviation: "MIA"),
    TeamDefinition(id: "15", sport: .nba, city: "Milwaukee", name: "Bucks", displayName: "Milwaukee Bucks", abbreviation: "MIL"),
    TeamDefinition(id: "16", sport: .nba, city: "Minnesota", name: "Timberwolves", displayName: "Minnesota Timberwolves", abbreviation: "MIN"),
    TeamDefinition(id: "3", sport: .nba, city: "New Orleans", name: "Pelicans", displayName: "New Orleans Pelicans", abbreviation: "NO"),
    TeamDefinition(id: "18", sport: .nba, city: "New York", name: "Knicks", displayName: "New York Knicks", abbreviation: "NY"),
    TeamDefinition(id: "25", sport: .nba, city: "Oklahoma City", name: "Thunder", displayName: "Oklahoma City Thunder", abbreviation: "OKC"),
    TeamDefinition(id: "19", sport: .nba, city: "Orlando", name: "Magic", displayName: "Orlando Magic", abbreviation: "ORL"),
    TeamDefinition(id: "20", sport: .nba, city: "Philadelphia", name: "76ers", displayName: "Philadelphia 76ers", abbreviation: "PHI"),
    TeamDefinition(id: "21", sport: .nba, city: "Phoenix", name: "Suns", displayName: "Phoenix Suns", abbreviation: "PHX"),
    TeamDefinition(id: "22", sport: .nba, city: "Portland", name: "Trail Blazers", displayName: "Portland Trail Blazers", abbreviation: "POR"),
    TeamDefinition(id: "23", sport: .nba, city: "Sacramento", name: "Kings", displayName: "Sacramento Kings", abbreviation: "SAC"),
    TeamDefinition(id: "24", sport: .nba, city: "San Antonio", name: "Spurs", displayName: "San Antonio Spurs", abbreviation: "SA"),
    TeamDefinition(id: "28", sport: .nba, city: "Toronto", name: "Raptors", displayName: "Toronto Raptors", abbreviation: "TOR"),
    TeamDefinition(id: "26", sport: .nba, city: "Utah", name: "Jazz", displayName: "Utah Jazz", abbreviation: "UTAH"),
    TeamDefinition(id: "27", sport: .nba, city: "Washington", name: "Wizards", displayName: "Washington Wizards", abbreviation: "WSH"),
    TeamDefinition(id: "18418", sport: .mls, city: "Atlanta United FC", name: "Atlanta United FC", displayName: "Atlanta United FC", abbreviation: "ATL"),
    TeamDefinition(id: "20906", sport: .mls, city: "Austin FC", name: "Austin FC", displayName: "Austin FC", abbreviation: "ATX"),
    TeamDefinition(id: "9720", sport: .mls, city: "CF Montréal", name: "CF Montréal", displayName: "CF Montréal", abbreviation: "MTL"),
    TeamDefinition(id: "21300", sport: .mls, city: "Charlotte FC", name: "Charlotte FC", displayName: "Charlotte FC", abbreviation: "CLT"),
    TeamDefinition(id: "182", sport: .mls, city: "Chicago Fire FC", name: "Chicago Fire FC", displayName: "Chicago Fire FC", abbreviation: "CHI"),
    TeamDefinition(id: "184", sport: .mls, city: "Colorado Rapids", name: "Colorado Rapids", displayName: "Colorado Rapids", abbreviation: "COL"),
    TeamDefinition(id: "183", sport: .mls, city: "Columbus Crew", name: "Columbus Crew", displayName: "Columbus Crew", abbreviation: "CLB"),
    TeamDefinition(id: "193", sport: .mls, city: "D.C. United", name: "D.C. United", displayName: "D.C. United", abbreviation: "DC"),
    TeamDefinition(id: "18267", sport: .mls, city: "FC Cincinnati", name: "FC Cincinnati", displayName: "FC Cincinnati", abbreviation: "CIN"),
    TeamDefinition(id: "185", sport: .mls, city: "FC Dallas", name: "FC Dallas", displayName: "FC Dallas", abbreviation: "DAL"),
    TeamDefinition(id: "6077", sport: .mls, city: "Houston Dynamo FC", name: "Houston Dynamo FC", displayName: "Houston Dynamo FC", abbreviation: "HOU"),
    TeamDefinition(id: "20232", sport: .mls, city: "Inter Miami CF", name: "Inter Miami CF", displayName: "Inter Miami CF", abbreviation: "MIA"),
    TeamDefinition(id: "187", sport: .mls, city: "LA Galaxy", name: "LA Galaxy", displayName: "LA Galaxy", abbreviation: "LA"),
    TeamDefinition(id: "18966", sport: .mls, city: "LAFC", name: "LAFC", displayName: "LAFC", abbreviation: "LAFC"),
    TeamDefinition(id: "17362", sport: .mls, city: "Minnesota United FC", name: "Minnesota United FC", displayName: "Minnesota United FC", abbreviation: "MIN"),
    TeamDefinition(id: "18986", sport: .mls, city: "Nashville SC", name: "Nashville SC", displayName: "Nashville SC", abbreviation: "NSH"),
    TeamDefinition(id: "189", sport: .mls, city: "New England Revolution", name: "New England Revolution", displayName: "New England Revolution", abbreviation: "NE"),
    TeamDefinition(id: "17606", sport: .mls, city: "New York City FC", name: "New York City FC", displayName: "New York City FC", abbreviation: "NYC"),
    TeamDefinition(id: "12011", sport: .mls, city: "Orlando City SC", name: "Orlando City SC", displayName: "Orlando City SC", abbreviation: "ORL"),
    TeamDefinition(id: "10739", sport: .mls, city: "Philadelphia Union", name: "Philadelphia Union", displayName: "Philadelphia Union", abbreviation: "PHI"),
    TeamDefinition(id: "9723", sport: .mls, city: "Portland Timbers", name: "Portland Timbers", displayName: "Portland Timbers", abbreviation: "POR"),
    TeamDefinition(id: "4771", sport: .mls, city: "Real Salt Lake", name: "Real Salt Lake", displayName: "Real Salt Lake", abbreviation: "RSL"),
    TeamDefinition(id: "190", sport: .mls, city: "Red Bull New York", name: "Red Bull New York", displayName: "Red Bull New York", abbreviation: "RBNY"),
    TeamDefinition(id: "22529", sport: .mls, city: "San Diego FC", name: "San Diego FC", displayName: "San Diego FC", abbreviation: "SD"),
    TeamDefinition(id: "191", sport: .mls, city: "San Jose Earthquakes", name: "San Jose Earthquakes", displayName: "San Jose Earthquakes", abbreviation: "SJ"),
    TeamDefinition(id: "9726", sport: .mls, city: "Seattle Sounders FC", name: "Seattle Sounders FC", displayName: "Seattle Sounders FC", abbreviation: "SEA"),
    TeamDefinition(id: "186", sport: .mls, city: "Sporting Kansas City", name: "Sporting Kansas City", displayName: "Sporting Kansas City", abbreviation: "SKC"),
    TeamDefinition(id: "21812", sport: .mls, city: "St. Louis CITY SC", name: "St. Louis CITY SC", displayName: "St. Louis CITY SC", abbreviation: "STL"),
    TeamDefinition(id: "7318", sport: .mls, city: "Toronto FC", name: "Toronto FC", displayName: "Toronto FC", abbreviation: "TOR"),
    TeamDefinition(id: "9727", sport: .mls, city: "Vancouver Whitecaps", name: "Vancouver Whitecaps", displayName: "Vancouver Whitecaps", abbreviation: "VAN"),
    TeamDefinition(id: "5503", sport: .f1, city: "G. Russell", name: "Mercedes", displayName: "G. Russell - Mercedes", abbreviation: "RUS"),
    TeamDefinition(id: "5829", sport: .f1, city: "K. Antonelli", name: "Mercedes", displayName: "K. Antonelli - Mercedes", abbreviation: "ANT"),
    TeamDefinition(id: "5498", sport: .f1, city: "C. Leclerc", name: "Ferrari", displayName: "C. Leclerc - Ferrari", abbreviation: "LEC"),
    TeamDefinition(id: "868", sport: .f1, city: "L. Hamilton", name: "Ferrari", displayName: "L. Hamilton - Ferrari", abbreviation: "HAM"),
    TeamDefinition(id: "5579", sport: .f1, city: "L. Norris", name: "McLaren", displayName: "L. Norris - McLaren", abbreviation: "NOR"),
    TeamDefinition(id: "5752", sport: .f1, city: "O. Piastri", name: "McLaren", displayName: "O. Piastri - McLaren", abbreviation: "PIA"),
    TeamDefinition(id: "4665", sport: .f1, city: "M. Verstappen", name: "Red Bull", displayName: "M. Verstappen - Red Bull", abbreviation: "VER"),
    TeamDefinition(id: "4472", sport: .f1, city: "S. Perez", name: "Red Bull", displayName: "S. Perez - Red Bull", abbreviation: "PER"),
    TeamDefinition(id: "5790", sport: .f1, city: "I. Hadjar", name: "Racing Bulls", displayName: "I. Hadjar - Racing Bulls", abbreviation: "HAD"),
    TeamDefinition(id: "5741", sport: .f1, city: "L. Lawson", name: "Racing Bulls", displayName: "L. Lawson - Racing Bulls", abbreviation: "LAW"),
    TeamDefinition(id: "5592", sport: .f1, city: "A. Albon", name: "Williams", displayName: "A. Albon - Williams", abbreviation: "ALB"),
    TeamDefinition(id: "4686", sport: .f1, city: "C. Sainz", name: "Williams", displayName: "C. Sainz - Williams", abbreviation: "SAI"),
    TeamDefinition(id: "4678", sport: .f1, city: "E. Ocon", name: "Haas", displayName: "E. Ocon - Haas", abbreviation: "OCO"),
    TeamDefinition(id: "5789", sport: .f1, city: "O. Bearman", name: "Haas", displayName: "O. Bearman - Haas", abbreviation: "BEA"),
    TeamDefinition(id: "5501", sport: .f1, city: "P. Gasly", name: "Alpine", displayName: "P. Gasly - Alpine", abbreviation: "GAS"),
    TeamDefinition(id: "5823", sport: .f1, city: "F. Colapinto", name: "Alpine", displayName: "F. Colapinto - Alpine", abbreviation: "COL"),
    TeamDefinition(id: "5835", sport: .f1, city: "G. Bortoleto", name: "Audi", displayName: "G. Bortoleto - Audi", abbreviation: "BOR"),
    TeamDefinition(id: "4396", sport: .f1, city: "N. Hulkenberg", name: "Audi", displayName: "N. Hulkenberg - Audi", abbreviation: "HUL"),
    TeamDefinition(id: "4775", sport: .f1, city: "L. Stroll", name: "Aston Martin", displayName: "L. Stroll - Aston Martin", abbreviation: "STR"),
    TeamDefinition(id: "4520", sport: .f1, city: "V. Bottas", name: "Aston Martin", displayName: "V. Bottas - Aston Martin", abbreviation: "BOT"),
    TeamDefinition(id: "5855", sport: .f1, city: "A. Lindblad", name: "Cadillac", displayName: "A. Lindblad - Cadillac", abbreviation: "LIN"),
    TeamDefinition(id: "mgp-mmarquez", sport: .motogp, city: "Marc Marquez", name: "Ducati", displayName: "Marc Marquez - Ducati", abbreviation: "MM93"),
    TeamDefinition(id: "mgp-fbagnaia", sport: .motogp, city: "Francesco Bagnaia", name: "Ducati", displayName: "Francesco Bagnaia - Ducati", abbreviation: "FB63"),
    TeamDefinition(id: "mgp-jmartin", sport: .motogp, city: "Jorge Martin", name: "Aprilia", displayName: "Jorge Martin - Aprilia", abbreviation: "JM89"),
    TeamDefinition(id: "mgp-aespargaro", sport: .motogp, city: "Aleix Espargaro", name: "Aprilia", displayName: "Aleix Espargaro - Aprilia", abbreviation: "AE41"),
    TeamDefinition(id: "mgp-bbinder", sport: .motogp, city: "Brad Binder", name: "KTM", displayName: "Brad Binder - KTM", abbreviation: "BB33"),
    TeamDefinition(id: "mgp-pacosta", sport: .motogp, city: "Pedro Acosta", name: "KTM", displayName: "Pedro Acosta - KTM", abbreviation: "PA31"),
    TeamDefinition(id: "mgp-fquartararo", sport: .motogp, city: "Fabio Quartararo", name: "Yamaha", displayName: "Fabio Quartararo - Yamaha", abbreviation: "FQ20"),
    TeamDefinition(id: "mgp-arins", sport: .motogp, city: "Alex Rins", name: "Yamaha", displayName: "Alex Rins - Yamaha", abbreviation: "AR42"),
    TeamDefinition(id: "mgp-jmir", sport: .motogp, city: "Joan Mir", name: "Honda", displayName: "Joan Mir - Honda", abbreviation: "JM36"),
    TeamDefinition(id: "mgp-lmarini", sport: .motogp, city: "Luca Marini", name: "Honda", displayName: "Luca Marini - Honda", abbreviation: "LM10"),
    TeamDefinition(id: "349", sport: .premierLeague, city: "AFC Bournemouth", name: "AFC Bournemouth", displayName: "AFC Bournemouth", abbreviation: "BOU"),
    TeamDefinition(id: "359", sport: .premierLeague, city: "Arsenal", name: "Arsenal", displayName: "Arsenal", abbreviation: "ARS"),
    TeamDefinition(id: "362", sport: .premierLeague, city: "Aston Villa", name: "Aston Villa", displayName: "Aston Villa", abbreviation: "AVL"),
    TeamDefinition(id: "337", sport: .premierLeague, city: "Brentford", name: "Brentford", displayName: "Brentford", abbreviation: "BRE"),
    TeamDefinition(id: "331", sport: .premierLeague, city: "Brighton & Hove Albion", name: "Brighton & Hove Albion", displayName: "Brighton & Hove Albion", abbreviation: "BHA"),
    TeamDefinition(id: "379", sport: .premierLeague, city: "Burnley", name: "Burnley", displayName: "Burnley", abbreviation: "BUR"),
    TeamDefinition(id: "363", sport: .premierLeague, city: "Chelsea", name: "Chelsea", displayName: "Chelsea", abbreviation: "CHE"),
    TeamDefinition(id: "384", sport: .premierLeague, city: "Crystal Palace", name: "Crystal Palace", displayName: "Crystal Palace", abbreviation: "CRY"),
    TeamDefinition(id: "368", sport: .premierLeague, city: "Everton", name: "Everton", displayName: "Everton", abbreviation: "EVE"),
    TeamDefinition(id: "370", sport: .premierLeague, city: "Fulham", name: "Fulham", displayName: "Fulham", abbreviation: "FUL"),
    TeamDefinition(id: "357", sport: .premierLeague, city: "Leeds United", name: "Leeds United", displayName: "Leeds United", abbreviation: "LEE"),
    TeamDefinition(id: "364", sport: .premierLeague, city: "Liverpool", name: "Liverpool", displayName: "Liverpool", abbreviation: "LIV"),
    TeamDefinition(id: "382", sport: .premierLeague, city: "Manchester City", name: "Manchester City", displayName: "Manchester City", abbreviation: "MNC"),
    TeamDefinition(id: "360", sport: .premierLeague, city: "Manchester United", name: "Manchester United", displayName: "Manchester United", abbreviation: "MAN"),
    TeamDefinition(id: "361", sport: .premierLeague, city: "Newcastle United", name: "Newcastle United", displayName: "Newcastle United", abbreviation: "NEW"),
    TeamDefinition(id: "393", sport: .premierLeague, city: "Nottingham Forest", name: "Nottingham Forest", displayName: "Nottingham Forest", abbreviation: "NFO"),
    TeamDefinition(id: "366", sport: .premierLeague, city: "Sunderland", name: "Sunderland", displayName: "Sunderland", abbreviation: "SUN"),
    TeamDefinition(id: "367", sport: .premierLeague, city: "Tottenham Hotspur", name: "Tottenham Hotspur", displayName: "Tottenham Hotspur", abbreviation: "TOT"),
    TeamDefinition(id: "371", sport: .premierLeague, city: "West Ham United", name: "West Ham United", displayName: "West Ham United", abbreviation: "WHU"),
    TeamDefinition(id: "380", sport: .premierLeague, city: "Wolverhampton Wanderers", name: "Wolverhampton Wanderers", displayName: "Wolverhampton Wanderers", abbreviation: "WOL"),
  ]

  static func canonicalCompositeID(for identifier: String?) -> String? {
    guard let identifier else { return nil }
    let normalized = normalizedIdentifier(identifier)
    guard !normalized.isEmpty else {
      return nil
    }

    if let direct = teams.first(where: { normalizedIdentifier($0.compositeID) == normalized }) {
      return direct.compositeID
    }

    if let legacyMapped = legacyCompositeIDMap[normalized] {
      return legacyMapped
    }

    if
      let parsed = parseSportAndID(from: normalized),
      let typed = teams.first(where: { $0.sport == parsed.sport && normalizedIdentifier($0.id) == parsed.id })
    {
      return typed.compositeID
    }

    if let uniqueByID = uniqueMatch(where: { normalizedIdentifier($0.id) == normalized }) {
      return uniqueByID.compositeID
    }

    if let uniqueByDisplay = uniqueMatch(where: { normalizedIdentifier($0.displayName) == normalized }) {
      return uniqueByDisplay.compositeID
    }

    return nil
  }

  static func team(withCompositeID compositeID: String?) -> TeamDefinition? {
    guard let canonical = canonicalCompositeID(for: compositeID) else {
      return nil
    }
    return teams.first(where: { $0.compositeID == canonical })
  }

  static func preferredWidgetFallbackTeam(
    settings: AppSettings,
    hasSnapshotData: (String) -> Bool = { compositeID in
      let snapshot = SharedScheduleStore().load(for: compositeID)
      return !(snapshot?.games.isEmpty ?? true)
    }
  ) -> TeamDefinition? {
    let favorites = dedupe(settings.favoriteTeamCompositeIDs).compactMap(team(withCompositeID:))
    if let favoriteWithData = favorites.first(where: { hasSnapshotData($0.compositeID) }) {
      return favoriteWithData
    }
    if let firstFavorite = favorites.first {
      return firstFavorite
    }
    return nil
  }

  static func resolveWidgetSelectionTeam(
    configuredCompositeID: String?,
    settings: AppSettings
  ) -> TeamDefinition {
    if let configured = team(withCompositeID: configuredCompositeID) {
      return configured
    }

    if let preferred = preferredWidgetFallbackTeam(settings: settings) {
      return preferred
    }

    return defaultTeam()
  }

  static func widgetConfigurationTeams(settings: AppSettings) -> [TeamDefinition] {
    canonicalizedCompositeIDs(settings.favoriteTeamCompositeIDs)
      .compactMap(team(withCompositeID:))
  }

  static func prioritizedWidgetConfigurationTeams(
    from teams: [TeamDefinition],
    settings: AppSettings,
    pinnedCompositeIDs: [String] = []
  ) -> [TeamDefinition] {
    var pinned = canonicalizedCompositeIDs(pinnedCompositeIDs)
    for compositeID in canonicalizedCompositeIDs(settings.favoriteTeamCompositeIDs) where !pinned.contains(compositeID) {
      pinned.append(compositeID)
    }
    for compositeID in canonicalizedCompositeIDs(settings.recentTeamCompositeIDs) where !pinned.contains(compositeID) {
      pinned.append(compositeID)
    }

    let pinnedIndex = Dictionary(uniqueKeysWithValues: pinned.enumerated().map { ($1, $0) })

    return teams.sorted { lhs, rhs in
      let leftPinned = pinnedIndex[lhs.compositeID]
      let rightPinned = pinnedIndex[rhs.compositeID]

      switch (leftPinned, rightPinned) {
      case let (left?, right?):
        return left < right
      case (_?, nil):
        return true
      case (nil, _?):
        return false
      case (nil, nil):
        if lhs.sport.displayName != rhs.sport.displayName {
          return lhs.sport.displayName < rhs.sport.displayName
        }
        return lhs.displayName < rhs.displayName
      }
    }
  }

  static func defaultTeam() -> TeamDefinition {
    team(withCompositeID: defaultTeamCompositeID) ?? teams.first!
  }

  static func teams(for sport: SupportedSport) -> [TeamDefinition] {
    teams.filter { $0.sport == sport }
  }

  static func search(query: String, sport: SupportedSport?) -> [TeamDefinition] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let base = sport.map { teams(for: $0) } ?? teams
    guard !normalized.isEmpty else { return base }
    return base.filter { $0.searchText.contains(normalized) }
  }

  private static func dedupe(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for value in values {
      let normalized = normalizedIdentifier(value)
      guard !normalized.isEmpty else {
        continue
      }
      if seen.insert(normalized).inserted {
        ordered.append(value)
      }
    }
    return ordered
  }

  private static func canonicalizedCompositeIDs(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []

    for value in values {
      guard let canonical = canonicalCompositeID(for: value) else {
        continue
      }
      if seen.insert(canonical).inserted {
        ordered.append(canonical)
      }
    }

    return ordered
  }

  private static func uniqueMatch(where predicate: (TeamDefinition) -> Bool) -> TeamDefinition? {
    let matches = teams.filter(predicate)
    guard matches.count == 1 else {
      return nil
    }
    return matches.first
  }

  private static func normalizedIdentifier(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private static func parseSportAndID(from normalizedIdentifier: String) -> (sport: SupportedSport, id: String)? {
    for separator in [":", "_", "-"] {
      let parts = normalizedIdentifier.split(separator: Character(separator), maxSplits: 1).map(String.init)
      guard parts.count == 2 else {
        continue
      }

      let sportPart = parts[0]
      let idPart = parts[1]
      guard !idPart.isEmpty, let sport = sport(for: sportPart) else {
        continue
      }

      return (sport: sport, id: idPart)
    }

    return nil
  }

  private static func sport(for token: String) -> SupportedSport? {
    switch token {
    case "nhl", "hockey":
      return .nhl
    case "mlb", "baseball":
      return .mlb
    case "nfl", "football":
      return .nfl
    case "nba", "basketball":
      return .nba
    case "mls", "soccer":
      return .mls
    case "f1", "formula1", "formula-1", "formula_1":
      return .f1
    case "motogp", "moto-gp", "moto_gp":
      return .motogp
    case "premierleague", "premier-league", "premier_league", "epl", "eng.1":
      return .premierLeague
    default:
      return nil
    }
  }

  private static let legacyCompositeIDMap: [String: String] = [
    "caps": "nhl:23",
    "washington capitals": "nhl:23",
    "washington-capitals": "nhl:23",
    "washington_capitals": "nhl:23",
  ]
}
