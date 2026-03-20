import SwiftUI
import UniformTypeIdentifiers

struct HomeTeamSettingsView: View {
  @EnvironmentObject private var settingsViewModel: AppSettingsViewModel
  @EnvironmentObject private var loginItemManager: LoginItemManager

  @State private var selection: HomeTeamSettingsSection = .favoriteTeams
  @State private var showingResetSetupConfirmation = false
  @State private var selectedSport: SupportedSport = .nhl
  @State private var selectedTeamCompositeID: String = TeamCatalog.defaultTeamCompositeID
  @State private var draggedTeamCompositeID: String?

  private let serviceColumns = [GridItem(.adaptive(minimum: 170), spacing: 8)]

  private var selectedFavoriteTeams: [TeamDefinition] {
    settingsViewModel.settings.favoriteTeamCompositeIDs.compactMap(TeamCatalog.team(withCompositeID:))
  }

  private var availableTeamsForSport: [TeamDefinition] {
    TeamCatalog.teams(for: selectedSport).sorted { $0.displayName < $1.displayName }
  }

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Divider()
      detail
    }
    .frame(minWidth: 860, minHeight: 640)
    .accessibilityIdentifier("settings.root")
    .onAppear {
      resetSelectedTeamIfNeeded()
      applyPendingSectionIfNeeded()
    }
    .onChange(of: selectedSport) { _ in
      resetSelectedTeamIfNeeded()
    }
    .onChange(of: settingsViewModel.pendingSettingsSection) { _ in
      applyPendingSectionIfNeeded()
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Settings")
        .font(.title3.weight(.bold))
        .padding(.horizontal, 14)
        .padding(.top, 14)

      ForEach(HomeTeamSettingsSection.allCases) { section in
        Button {
          selection = section
        } label: {
          HStack {
            Text(section.rawValue)
              .font(.system(size: 13, weight: .medium))
            Spacer()
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .contentShape(Rectangle())
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(selection == section ? Color.accentColor.opacity(0.18) : .clear)
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(section.sidebarAccessibilityIdentifier)
        .padding(.horizontal, 10)
      }

      Spacer()
    }
    .frame(width: 220, alignment: .topLeading)
  }

  private var detail: some View {
    Group {
      switch selection {
      case .favoriteTeams:
        favoriteTeamsSection
      case .streamingServices:
        streamingServicesSection
      case .location:
        locationSection
      case .notifications:
        notificationsSection
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
  }

  private var favoriteTeamsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Favorite Teams")
          .font(.title2.weight(.bold))
          .accessibilityIdentifier(HomeTeamSettingsSection.favoriteTeams.headingAccessibilityIdentifier)

        Spacer()

        Button("Reset Setup...", role: .destructive) {
          showingResetSetupConfirmation = true
        }
        .help("Clear favorites and streaming services to show onboarding again.")
      }

      Text("Drag to reorder. The order is used across the app and saved automatically.")
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(selectedFavoriteTeams) { team in
          FavoriteTeamOrderRow(
            team: team,
            hideDuringOffseason: settingsViewModel.isHideDuringOffseasonEnabled(for: team),
            onToggleHideDuringOffseason: { settingsViewModel.setHideDuringOffseason($0, for: team) },
            canDelete: selectedFavoriteTeams.count > 1,
            onDelete: { settingsViewModel.setFavoriteTeam(team, isSelected: false) }
          )
          .onDrag {
            draggedTeamCompositeID = team.compositeID
            return NSItemProvider(object: team.compositeID as NSString)
          }
          .onDrop(
            of: [UTType.text],
            delegate: FavoriteTeamReorderDropDelegate(
              targetCompositeID: team.compositeID,
              draggedCompositeID: $draggedTeamCompositeID
            ) { sourceID, destinationID in
              settingsViewModel.moveFavoriteTeam(
                sourceCompositeID: sourceID,
                destinationCompositeID: destinationID
              )
            }
          )
        }
      }

      Divider()

      HStack(spacing: 10) {
        Picker("Sport", selection: $selectedSport) {
          ForEach(SupportedSport.allCases, id: \.self) { sport in
            Text(sport.displayName).tag(sport)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("settings.favoriteTeams.sportPicker")
        .frame(width: 160)

        Picker("Team / Driver", selection: $selectedTeamCompositeID) {
          ForEach(availableTeamsForSport, id: \.compositeID) { team in
            Text(team.displayName).tag(team.compositeID)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("settings.favoriteTeams.teamPicker")
        .frame(maxWidth: 340)

        Button("Add Team") {
          addSelectedTeam()
        }
        .accessibilityIdentifier("settings.favoriteTeams.addTeam")
      }

      Spacer(minLength: 0)
    }
    .confirmationDialog(
      "Reset setup?",
      isPresented: $showingResetSetupConfirmation
    ) {
      Button("Reset Setup", role: .destructive) {
        settingsViewModel.resetSetupForOnboarding()
      }

      Button("Cancel", role: .cancel) { }
    } message: {
      Text("This clears Favorite Teams and Streaming Services so onboarding appears again.")
    }
  }

  private var streamingServicesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Streaming Services")
        .font(.title2.weight(.bold))
        .accessibilityIdentifier(HomeTeamSettingsSection.streamingServices.headingAccessibilityIdentifier)

      Text("Selected: \(settingsViewModel.selectedServiceCount)")
        .font(.caption)
        .foregroundStyle(.secondary)

      LazyVGrid(columns: serviceColumns, alignment: .leading, spacing: 8) {
        ForEach(settingsViewModel.sortedStreamingProviders) { provider in
          Toggle(isOn: Binding(
            get: { settingsViewModel.isStreamingServiceSelected(provider) },
            set: { settingsViewModel.setStreamingService(provider, isSelected: $0) }
          )) {
            Text(provider.name)
          }
          .toggleStyle(.checkbox)
        }
      }

      Spacer(minLength: 0)
    }
  }

  private var locationSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Location")
        .font(.title2.weight(.bold))
        .accessibilityIdentifier(HomeTeamSettingsSection.location.headingAccessibilityIdentifier)

      Text("ZIP Code")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField("Enter ZIP", text: Binding(
        get: { settingsViewModel.settings.zipCode },
        set: { settingsViewModel.updateZipCode($0) }
      ))
      .textFieldStyle(.roundedBorder)
      .frame(width: 150)

      if settingsViewModel.isResolvingZipCode {
        Text("Resolving ZIP...")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text("Current: \(settingsViewModel.settings.locationSummary)")
        .font(.subheadline)

      if let locationMessage = settingsViewModel.locationMessage {
        Text(locationMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
  }

  private var notificationsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Notifications")
        .font(.title2.weight(.bold))
        .accessibilityIdentifier(HomeTeamSettingsSection.notifications.headingAccessibilityIdentifier)

      Toggle(isOn: Binding(
        get: { settingsViewModel.settings.notifications.gameStartReminders },
        set: { settingsViewModel.setGameStartReminders($0) }
      )) {
        Text("Game Start Reminders (Watchable Only)")
      }

      Toggle(isOn: Binding(
        get: { settingsViewModel.settings.notifications.finalScores },
        set: { settingsViewModel.setFinalScores($0) }
      )) {
        Text("Final Scores (All Games)")
      }

      Divider()

      Toggle("Open at Login", isOn: Binding(
        get: { loginItemManager.openAtLogin },
        set: { loginItemManager.setOpenAtLogin($0) }
      ))

      if let message = loginItemManager.message {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
  }

  private func addSelectedTeam() {
    guard let team = TeamCatalog.team(withCompositeID: selectedTeamCompositeID) else {
      return
    }

    settingsViewModel.setFavoriteTeam(team, isSelected: true)
  }

  private func resetSelectedTeamIfNeeded() {
    guard let firstTeam = availableTeamsForSport.first else {
      selectedTeamCompositeID = TeamCatalog.defaultTeamCompositeID
      return
    }

    if !availableTeamsForSport.contains(where: { $0.compositeID == selectedTeamCompositeID }) {
      selectedTeamCompositeID = firstTeam.compositeID
    }
  }

  private func applyPendingSectionIfNeeded() {
    guard let pending = settingsViewModel.pendingSettingsSection else {
      return
    }

    selection = pending
    settingsViewModel.clearPendingSettingsSection()
  }
}

private struct FavoriteTeamOrderRow: View {
  let team: TeamDefinition
  let hideDuringOffseason: Bool
  let onToggleHideDuringOffseason: (Bool) -> Void
  let canDelete: Bool
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "line.3.horizontal")
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 2) {
        Text(team.displayName)
          .font(.subheadline.weight(.semibold))
        Text(team.sport.displayName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      Toggle("Hide During Off-season", isOn: Binding(
        get: { hideDuringOffseason },
        set: onToggleHideDuringOffseason
      ))
      .toggleStyle(.checkbox)
      .font(.caption)

      if canDelete {
        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.secondary.opacity(0.10))
    )
  }
}

private struct FavoriteTeamReorderDropDelegate: DropDelegate {
  let targetCompositeID: String
  @Binding var draggedCompositeID: String?
  let onMove: (String, String) -> Void

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func dropEntered(info: DropInfo) {
    guard let draggedCompositeID, draggedCompositeID != targetCompositeID else {
      return
    }

    onMove(draggedCompositeID, targetCompositeID)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggedCompositeID = nil
    return true
  }
}
