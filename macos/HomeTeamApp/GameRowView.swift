import SwiftUI

// MARK: - Single game row in the menu-bar list

struct GameRowView: View {
  @EnvironmentObject var settings: AppSettingsStore
  let game: HomeTeamGame

  var body: some View {
    HStack(spacing: 8) {
      // Team logos zone — sport icon when no logos, logos otherwise (no ZStack bleed-through)
      logoArea
        .frame(width: 52, height: 24)
        .clipped()

      VStack(alignment: .leading, spacing: 2) {
        // Teams
        Text(game.title)
          .font(.system(size: 12, weight: .medium))
          .lineLimit(1)

        // Subtitle: time / score / status
        Text(game.subtitle)
          .font(.system(size: 11))
          .foregroundColor(game.status == .live ? .green : .secondary)
          .lineLimit(1)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        // Show the network the user actually has, not just the first listed
        if let net = matchedNetwork {
          Text(net)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }

        // Calendar button
        Button {
          openCalendar()
        } label: {
          Image(systemName: "calendar.badge.plus")
            .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .help("Add to Calendar")
        .opacity(game.status == .scheduled ? 1 : 0)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }

  // MARK: - Helpers

  /// Logo area: sport wordmark for racing, two team logos for team sports, sport icon as fallback.
  @ViewBuilder private var logoArea: some View {
    let homeURL = logoURL(for: game.homeTeamID, sport: game.sport)
    let awayURL = logoURL(for: game.awayTeamID, sport: game.sport)
    if homeURL == nil && awayURL == nil {
      if let wm = game.sport.wordmarkURL {
        // Racing: show sport wordmark. F1 logo runs large so pull it in 20%.
        AsyncImage(url: wm) { phase in
          switch phase {
          case .success(let img):
            img.resizable().scaledToFit()
              .padding(game.sport == .f1 ? 3 : 0)
          default:
            sportIcon
          }
        }
      } else {
        sportIcon
      }
    } else {
      HStack(spacing: 4) {
        asyncLogo(homeURL)
        asyncLogo(awayURL)
      }
    }
  }

  private func logoURL(for teamID: String, sport: SupportedSport) -> URL? {
    TeamCatalog.teams(for: sport).first(where: { $0.espnTeamID == teamID })?.logoURL
  }

  private func asyncLogo(_ url: URL?) -> some View {
    Group {
      if let url {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let img):
            img.resizable().scaledToFit().frame(width: 24, height: 24)
          default:
            Color.clear.frame(width: 24, height: 24)
          }
        }
        .frame(width: 24, height: 24)
      } else {
        Color.clear.frame(width: 24, height: 24)
      }
    }
  }

  /// The display name for the first network the user actually subscribes to.
  /// Falls back to the first listed network if nothing matches (no filter set, or unrecognized).
  private var matchedNetwork: String? {
    let selected = Set(settings.settings.selectedStreamingServices)
    let nets = game.broadcastNetworks
    guard !nets.isEmpty else { return nil }
    if !selected.isEmpty,
       let hit = nets.first(where: { StreamingServiceMatcher.isMatch(rawName: $0, selectedKeys: selected) }) {
      return displayName(for: hit)
    }
    return displayName(for: nets[0])
  }

  private func displayName(for rawNetwork: String) -> String {
    guard let key = StreamingServiceMatcher.canonicalKey(for: rawNetwork),
          let provider = StreamingProviderCatalog.all.first(where: { $0.canonicalKey == key })
    else { return rawNetwork }
    return provider.displayName
  }

  private var sportIcon: some View {
    Image(systemName: game.sport.systemImageName)
      .font(.system(size: 14))
      .foregroundColor(.secondary)
  }

  private func openCalendar() {
    let title = game.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let dates = ISO8601DateFormatter().string(from: game.scheduledAt)
    let end   = ISO8601DateFormatter().string(from: game.scheduledAt.addingTimeInterval(3 * 3600))
    let urlStr = "https://calendar.google.com/calendar/render?action=TEMPLATE&text=\(title)&dates=\(dates)/\(end)"
    if let url = URL(string: urlStr) {
      NSWorkspace.shared.open(url)
    }
  }
}

// SupportedSport.systemImageName is defined in TeamCatalog.swift
