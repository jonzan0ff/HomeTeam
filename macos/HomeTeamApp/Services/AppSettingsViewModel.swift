import Foundation
import CoreLocation
import WidgetKit

struct ZipCodeLocation: Equatable {
  let city: String
  let state: String
}

enum ZipCodeResolverError: LocalizedError {
  case invalidZipCode
  case notFound

  var errorDescription: String? {
    switch self {
    case .invalidZipCode:
      return "Enter a valid 5-digit ZIP code."
    case .notFound:
      return "ZIP code not found."
    }
  }
}

struct ZipCodeResolver {
  func resolve(zipCode: String) async throws -> ZipCodeLocation {
    let normalized = zipCode.filter(\.isNumber)
    guard normalized.count == 5 else {
      throw ZipCodeResolverError.invalidZipCode
    }

    do {
      return try await resolveViaZippopotam(zipCode: normalized)
    } catch {
      if let fallback = try? await resolveViaCLGeocoder(zipCode: normalized) {
        return fallback
      }
      throw error
    }
  }

  private func resolveViaZippopotam(zipCode: String) async throws -> ZipCodeLocation {
    guard let url = URL(string: "https://api.zippopotam.us/us/\(zipCode)") else {
      throw ZipCodeResolverError.invalidZipCode
    }

    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, http.statusCode == 404 {
      throw ZipCodeResolverError.notFound
    }

    let payload = try JSONDecoder().decode(ZipCodePayload.self, from: data)
    guard
      let place = payload.places.first,
      !place.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !place.stateAbbreviation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw ZipCodeResolverError.notFound
    }

    return ZipCodeLocation(city: place.placeName, state: place.stateAbbreviation)
  }

  private func resolveViaCLGeocoder(zipCode: String) async throws -> ZipCodeLocation {
    let placemark: CLPlacemark = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLPlacemark, Error>) in
      CLGeocoder().geocodeAddressString("\(zipCode), US") { placemarks, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        guard let first = placemarks?.first else {
          continuation.resume(throwing: ZipCodeResolverError.notFound)
          return
        }

        continuation.resume(returning: first)
      }
    }

    let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let state = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !city.isEmpty, !state.isEmpty else {
      throw ZipCodeResolverError.notFound
    }

    return ZipCodeLocation(city: city, state: state)
  }
}

enum HomeTeamSettingsSection: String, CaseIterable, Identifiable {
  case favoriteTeams = "Favorite Teams"
  case streamingServices = "Streaming Services"
  case location = "Location"
  case notifications = "Notifications"

  var id: String { rawValue }

  var sidebarAccessibilityIdentifier: String {
    switch self {
    case .favoriteTeams:
      return "settings.section.favoriteTeams"
    case .streamingServices:
      return "settings.section.streamingServices"
    case .location:
      return "settings.section.location"
    case .notifications:
      return "settings.section.notifications"
    }
  }

  var headingAccessibilityIdentifier: String {
    switch self {
    case .favoriteTeams:
      return "settings.heading.favoriteTeams"
    case .streamingServices:
      return "settings.heading.streamingServices"
    case .location:
      return "settings.heading.location"
    case .notifications:
      return "settings.heading.notifications"
    }
  }
}

@MainActor
final class AppSettingsViewModel: ObservableObject {
  @Published private(set) var settings: AppSettings
  @Published var locationMessage: String?
  @Published var isResolvingZipCode = false
  @Published var pendingSettingsSection: HomeTeamSettingsSection?

  private let store: AppSettingsStore
  private let zipCodeResolver: ZipCodeResolver
  private let widgetReloadEnabled: Bool
  private var cloudObserver: NSObjectProtocol?
  private var zipResolveTask: Task<Void, Never>?

  init(
    store: AppSettingsStore = AppSettingsStore(),
    zipCodeResolver: ZipCodeResolver = ZipCodeResolver(),
    widgetReloadEnabled: Bool = true
  ) {
    self.store = store
    self.zipCodeResolver = zipCodeResolver
    self.widgetReloadEnabled = widgetReloadEnabled
    settings = store.load()

    store.synchronizeCloudStore()
    observeCloudUpdates()
    applyCloudSettingsIfAvailable()
    scheduleZipResolveIfNeeded()
  }

  deinit {
    zipResolveTask?.cancel()
    if let cloudObserver {
      NotificationCenter.default.removeObserver(cloudObserver)
    }
  }

  var selectedServiceCount: Int {
    settings.selectedStreamingServices.count
  }

  var selectedTeamCount: Int {
    settings.favoriteTeamCompositeIDs.count
  }

  var preferredTeamCompositeID: String {
    settings.favoriteTeamCompositeIDs.first
      ?? settings.recentTeamCompositeIDs.first
      ?? TeamCatalog.defaultTeamCompositeID
  }

  var needsOnboarding: Bool {
    !settings.meetsOnboardingRequirements
  }

  var sortedStreamingProviders: [StreamingProvider] {
    StreamingProviderCatalog.providers.sorted { lhs, rhs in
      let lhsSelected = isStreamingServiceSelected(lhs)
      let rhsSelected = isStreamingServiceSelected(rhs)

      if lhsSelected != rhsSelected {
        return lhsSelected && !rhsSelected
      }

      return lhs.name < rhs.name
    }
  }

  func isStreamingServiceSelected(_ provider: StreamingProvider) -> Bool {
    settings.selectedServiceLookup.contains(AppSettings.normalizedServiceName(provider.name))
  }

  func setStreamingService(_ provider: StreamingProvider, isSelected: Bool) {
    var selected = settings.selectedServiceLookup
    let normalized = AppSettings.normalizedServiceName(provider.name)

    if isSelected {
      selected.insert(normalized)
    } else {
      selected.remove(normalized)
    }

    settings.selectedStreamingServices = StreamingProviderCatalog.providers
      .map(\.name)
      .filter { selected.contains(AppSettings.normalizedServiceName($0)) }

    persistSettings()
  }

  func setFavoriteTeam(_ team: TeamDefinition, isSelected: Bool) {
    var selected = settings.favoriteTeamCompositeIDs

    if isSelected {
      if !selected.contains(team.compositeID) {
        selected.append(team.compositeID)
      }
    } else {
      guard !(selected.count == 1 && selected.first == team.compositeID) else {
        return
      }
      selected.removeAll(where: { $0 == team.compositeID })
    }

    settings.favoriteTeamCompositeIDs = selected
    persistSettings()
  }

  func moveFavoriteTeam(sourceCompositeID: String, destinationCompositeID: String) {
    var ordered = settings.favoriteTeamCompositeIDs
    guard
      sourceCompositeID != destinationCompositeID,
      let sourceIndex = ordered.firstIndex(of: sourceCompositeID),
      let destinationIndex = ordered.firstIndex(of: destinationCompositeID)
    else {
      return
    }

    let moved = ordered.remove(at: sourceIndex)
    ordered.insert(moved, at: destinationIndex)

    guard ordered != settings.favoriteTeamCompositeIDs else {
      return
    }

    settings.favoriteTeamCompositeIDs = ordered
    persistSettings()
  }

  func isHideDuringOffseasonEnabled(for team: TeamDefinition) -> Bool {
    settings.hideDuringOffseasonTeamCompositeIDs.contains(team.compositeID)
  }

  func setHideDuringOffseason(_ isEnabled: Bool, for team: TeamDefinition) {
    var hidden = settings.hideDuringOffseasonTeamCompositeIDs
    if isEnabled {
      if !hidden.contains(team.compositeID) {
        hidden.append(team.compositeID)
      }
    } else {
      hidden.removeAll(where: { $0 == team.compositeID })
    }

    settings.hideDuringOffseasonTeamCompositeIDs = hidden
    persistSettings()
  }

  func updateZipCode(_ rawValue: String) {
    let normalized = String(rawValue.filter(\.isNumber).prefix(5))
    guard normalized != settings.zipCode else {
      return
    }

    settings.zipCode = normalized
    settings.city = nil
    settings.state = nil
    locationMessage = nil
    persistSettings()

    zipResolveTask?.cancel()
    guard normalized.count == 5 else {
      return
    }

    zipResolveTask = Task { [weak self] in
      guard let self else {
        return
      }
      await self.resolveZipCode()
    }
  }

  func resolveZipCode() async {
    guard settings.zipCode.count == 5 else {
      locationMessage = ZipCodeResolverError.invalidZipCode.localizedDescription
      return
    }

    isResolvingZipCode = true
    defer { isResolvingZipCode = false }

    do {
      let location = try await zipCodeResolver.resolve(zipCode: settings.zipCode)
      settings.city = location.city
      settings.state = location.state
      locationMessage = "Resolved to \(location.city), \(location.state)."
      persistSettings()
    } catch {
      locationMessage = error.localizedDescription
    }
  }

  func setGameStartReminders(_ isEnabled: Bool) {
    settings.notifications.gameStartReminders = isEnabled
    persistSettings()
  }

  func setFinalScores(_ isEnabled: Bool) {
    settings.notifications.finalScores = isEnabled
    persistSettings()
  }

  func resetSetupForOnboarding() {
    settings.favoriteTeamCompositeIDs = []
    settings.selectedStreamingServices = []
    settings.hideDuringOffseasonTeamCompositeIDs = []
    pendingSettingsSection = .favoriteTeams
    UserDefaults.standard.removeObject(forKey: "HomeTeam.didAutoOpenSettingsForOnboarding")
    persistSettings()
  }

  func requestSettingsSection(_ section: HomeTeamSettingsSection) {
    pendingSettingsSection = section
  }

  func clearPendingSettingsSection() {
    pendingSettingsSection = nil
  }

  private func persistSettings() {
    store.save(settings)
    if widgetReloadEnabled {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  private func applyCloudSettingsIfAvailable() {
    guard let cloud = store.loadFromCloud(), cloud != settings else {
      return
    }

    settings = cloud
    scheduleZipResolveIfNeeded()
  }

  func refreshFromStore() {
    settings = store.load()
    scheduleZipResolveIfNeeded()
  }

  private func observeCloudUpdates() {
    cloudObserver = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: NSUbiquitousKeyValueStore.default,
      queue: .main
    ) { [weak self] _ in
      guard let self else {
        return
      }

      Task { @MainActor in
        self.applyCloudSettingsIfAvailable()
      }
    }
  }

  private func scheduleZipResolveIfNeeded() {
    guard
      settings.zipCode.count == 5,
      (settings.city?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        || (settings.state?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    else {
      return
    }

    zipResolveTask?.cancel()
    zipResolveTask = Task { [weak self] in
      await self?.resolveZipCode()
    }
  }
}

private struct ZipCodePayload: Decodable {
  struct Place: Decodable {
    let placeName: String
    let stateAbbreviation: String

    enum CodingKeys: String, CodingKey {
      case placeName = "place name"
      case stateAbbreviation = "state abbreviation"
    }
  }

  let places: [Place]
}
