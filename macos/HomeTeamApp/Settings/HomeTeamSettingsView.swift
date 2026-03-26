import SwiftUI

struct HomeTeamSettingsView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    TabView(selection: $appState.activeSettingsTab) {
      TeamsSettingsTab()
        .tabItem { Label("Teams", systemImage: "star.fill") }
        .tag(AppState.SettingsTab.teams)

      StreamingSettingsTab()
        .tabItem { Label("Streaming", systemImage: "play.tv") }
        .tag(AppState.SettingsTab.streaming)

      NotificationsSettingsTab()
        .tabItem { Label("Notifications", systemImage: "bell.fill") }
        .tag(AppState.SettingsTab.notifications)

      AdvancedSettingsTab()
        .tabItem { Label("Advanced", systemImage: "gearshape.2") }
        .tag(AppState.SettingsTab.advanced)
    }
    .padding()
  }
}

// MARK: - Teams tab

struct TeamsSettingsTab: View {
  @EnvironmentObject var settings: AppSettingsStore

  @State private var searchText = ""
  @State private var selectedSport: SupportedSport? = nil

  var body: some View {
    VStack(spacing: 12) {
      TextField("Search teams…", text: $searchText)
        .textFieldStyle(.roundedBorder)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          sportFilterButton(label: "All", sport: nil)
          ForEach(SupportedSport.allCases) { sport in
            sportFilterButton(label: sport.displayName, sport: sport)
          }
        }
        .padding(.horizontal, 2)
      }

      List {
        ForEach(filteredTeams) { team in
          TeamRowView(team: team)
        }
      }
      .listStyle(.inset(alternatesRowBackgrounds: true))

      Text("\(settings.settings.favoriteTeamCompositeIDs.count) teams selected")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private func sportFilterButton(label: String, sport: SupportedSport?) -> some View {
    Button { selectedSport = sport } label: {
      Text(label)
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(selectedSport == sport ? Color.accentColor : Color.secondary.opacity(0.15))
        .foregroundColor(selectedSport == sport ? .white : .primary)
        .cornerRadius(6)
    }
    .buttonStyle(.plain)
  }

  private var filteredTeams: [TeamDefinition] {
    let favorites = Set(settings.settings.favoriteTeamCompositeIDs)
    var teams = TeamCatalog.all
    if let sport = selectedSport {
      teams = teams.filter { $0.sport == sport }
    }
    if !searchText.isEmpty {
      let q = searchText.lowercased()
      teams = teams.filter { $0.searchText.contains(q) }
    }
    // Favorites float to top, rest alphabetical
    return teams.sorted { lhs, rhs in
      let lf = favorites.contains(lhs.compositeID)
      let rf = favorites.contains(rhs.compositeID)
      if lf != rf { return lf }
      return lhs.displayName < rhs.displayName
    }
  }
}

private struct TeamRowView: View {
  @EnvironmentObject var settings: AppSettingsStore
  let team: TeamDefinition

  var isFavorite: Bool { settings.settings.favoriteTeamCompositeIDs.contains(team.compositeID) }
  var isHidden: Bool   { settings.settings.hideDuringOffseasonTeamCompositeIDs.contains(team.compositeID) }

  var body: some View {
    HStack(spacing: 10) {
      // Logo
      if let url = team.logoURL {
        AsyncImage(url: url) { phase in
          if case .success(let img) = phase {
            img.resizable().scaledToFit()
          } else {
            Color.clear
          }
        }
        .frame(width: 28, height: 28)
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(team.sport.isRacing ? team.raceLabel : team.displayName)
          .font(.system(size: 13, weight: .medium))
        Text(team.sport.displayName)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      // Hide during off-season toggle (only shown when favorite)
      if isFavorite {
        Toggle("Hide off-season", isOn: Binding(
          get: { isHidden },
          set: { on in
            settings.update { s in
              if on { s.hideDuringOffseasonTeamCompositeIDs.append(team.compositeID) }
              else  { s.hideDuringOffseasonTeamCompositeIDs.removeAll { $0 == team.compositeID } }
            }
          }
        ))
        .toggleStyle(.checkbox)
        .font(.caption)
      }

      // Favorite star
      Button {
        settings.update { s in
          if isFavorite { s.favoriteTeamCompositeIDs.removeAll { $0 == team.compositeID } }
          else          { s.favoriteTeamCompositeIDs.append(team.compositeID) }
        }
      } label: {
        Image(systemName: isFavorite ? "star.fill" : "star")
          .foregroundColor(isFavorite ? .yellow : .secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 2)
  }
}

// MARK: - Streaming tab

struct StreamingSettingsTab: View {
  @EnvironmentObject var settings: AppSettingsStore

  private let services = StreamingProviderCatalog.all

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Only show games available on your services.")
        .font(.caption)
        .foregroundColor(.secondary)

      List(services) { provider in
        StreamingRowView(provider: provider)
      }
      .listStyle(.inset(alternatesRowBackgrounds: true))

      Text("Select none to show all games.")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
  }
}

private struct StreamingRowView: View {
  @EnvironmentObject var settings: AppSettingsStore
  let provider: StreamingProvider

  var isSelected: Bool { settings.settings.selectedStreamingServices.contains(provider.canonicalKey) }

  var body: some View {
    HStack {
      Toggle(isOn: Binding(
        get: { isSelected },
        set: { on in
          settings.update { s in
            if on { s.selectedStreamingServices.append(provider.canonicalKey) }
            else  { s.selectedStreamingServices.removeAll { $0 == provider.canonicalKey } }
          }
        }
      )) {
        HStack(spacing: 8) {
          if let url = provider.logoURL {
            AsyncImage(url: url) { phase in
              if case .success(let img) = phase { img.resizable().scaledToFit() }
              else { Color.secondary.opacity(0.2) }
            }
            .frame(width: 32, height: 20)
            .cornerRadius(3)
          }
          Text(provider.displayName)
        }
      }
      .toggleStyle(.checkbox)
    }
    .padding(.vertical, 2)
  }
}

// MARK: - Notifications tab

struct NotificationsSettingsTab: View {
  @EnvironmentObject var settings: AppSettingsStore

  var body: some View {
    Form {
      Toggle("Game starting soon", isOn: Binding(
        get: { settings.settings.notifications.gameStarting },
        set: { v in settings.update { $0.notifications.gameStarting = v } }
      ))
      Toggle("Score updates (live)", isOn: Binding(
        get: { settings.settings.notifications.scoreUpdates },
        set: { v in settings.update { $0.notifications.scoreUpdates = v } }
      ))
      Toggle("Final scores", isOn: Binding(
        get: { settings.settings.notifications.finalScore },
        set: { v in settings.update { $0.notifications.finalScore = v } }
      ))
    }
    .formStyle(.grouped)
  }
}

// MARK: - Advanced tab

struct AdvancedSettingsTab: View {
  @EnvironmentObject var settings: AppSettingsStore

  var body: some View {
    Form {
      Section("Location") {
        TextField("ZIP Code", text: Binding(
          get: { settings.settings.zipCode },
          set: { v in settings.update { $0.zipCode = v } }
        ))
      }
    }
    .formStyle(.grouped)
  }
}
