import SwiftUI

struct HomeTeamOnboardingView: View {
  @EnvironmentObject private var settingsViewModel: AppSettingsViewModel
  let onOpenSettingsSection: (HomeTeamSettingsSection) -> Void
  let onRefreshCompletion: () -> Void

  private var hasFavoriteTeam: Bool {
    !settingsViewModel.settings.favoriteTeamCompositeIDs.isEmpty
  }

  private var hasStreamingProvider: Bool {
    !settingsViewModel.settings.selectedStreamingServices.isEmpty
  }

  private var hasResolvedLocation: Bool {
    settingsViewModel.settings.zipCode.count == 5
      && settingsViewModel.settings.city != nil
      && settingsViewModel.settings.state != nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Get Started")
        .font(.title2.weight(.bold))
        .accessibilityIdentifier("onboarding.title")

      Text("Setup is managed in Settings. Use these quick links to complete required steps.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(spacing: 10) {
        OnboardingChecklistRow(
          title: "Favorite Teams",
          subtitle: hasFavoriteTeam ? "At least one favorite is selected." : "Required",
          isComplete: hasFavoriteTeam,
          buttonTitle: "Open Favorite Teams",
          buttonAccessibilityIdentifier: "onboarding.openFavoriteTeams",
          action: { onOpenSettingsSection(.favoriteTeams) }
        )

        OnboardingChecklistRow(
          title: "Streaming Services",
          subtitle: hasStreamingProvider ? "At least one provider is selected." : "Required",
          isComplete: hasStreamingProvider,
          buttonTitle: "Open Streaming Services",
          buttonAccessibilityIdentifier: "onboarding.openStreamingServices",
          action: { onOpenSettingsSection(.streamingServices) }
        )

        OnboardingChecklistRow(
          title: "Location",
          subtitle: hasResolvedLocation ? settingsViewModel.settings.locationSummary : "Optional for onboarding",
          isComplete: hasResolvedLocation,
          buttonTitle: "Open Location",
          buttonAccessibilityIdentifier: "onboarding.openLocation",
          action: { onOpenSettingsSection(.location) }
        )
      }

      Text("Required to continue: Favorite Teams and Streaming Services.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Button("Open Settings") {
          onOpenSettingsSection(.favoriteTeams)
        }
        .accessibilityIdentifier("onboarding.openSettings")

        Button("Refresh Setup Status") {
          onRefreshCompletion()
        }
        .accessibilityIdentifier("onboarding.refreshStatus")
        .help("Use this after updating settings from another window.")

        Spacer()
      }
    }
    .padding(22)
    .frame(maxWidth: 640)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(nsColor: .windowBackgroundColor))
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    )
    .onAppear(perform: onRefreshCompletion)
  }
}

private struct OnboardingChecklistRow: View {
  let title: String
  let subtitle: String
  let isComplete: Bool
  let buttonTitle: String
  let buttonAccessibilityIdentifier: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(isComplete ? Color.green : Color.secondary)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      Button(buttonTitle, action: action)
        .accessibilityIdentifier(buttonAccessibilityIdentifier)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.secondary.opacity(0.10))
    )
  }
}
