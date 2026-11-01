//  WHAT: The Info keys a key line may name by a short word (`camera`, `localNetwork`, `category`), what each is in
//        Info.plist and on which platforms it applies; the keys Xcode writes from an `INFOPLIST_KEY_` build
//        setting; and the app categories the App Store knows.
//  PIN:  THE SETTINGS ARE XCODE'S OWN LIST (Xcode 27.1, CoreBuildSystem.xcspec). A key on it is a build setting,
//        so it shows in Xcode's Info tab; any other key goes in the platform's Info.plist, where Xcode merges it.

import Foundation

enum InfoVocabulary {
    /// How a key's value is read and written.
    enum Kind: Equatable, Sendable {
        /// Why the app asks for a permission: a sentence, capitalised, ending in a period.
        case usage
        /// Text as written.
        case text
        /// An App Store category: `lifestyle` → `public.app-category.lifestyle`.
        case category
        /// Yes or no.
        case boolean
        /// Several values, split by commas.
        case list
    }

    struct Word: Sendable {
        let key: String
        let kind: Kind
        let platforms: Set<AppPlatform>
    }

    static let both: Set<AppPlatform> = [.iOS, .macOS]

    /// The short words, by their folded form (lowercase, no spaces, dashes or underscores).
    static let words: [String: Word] = [
        "camera": Word(key: "NSCameraUsageDescription", kind: .usage, platforms: both),
        "microphone": Word(key: "NSMicrophoneUsageDescription", kind: .usage, platforms: both),
        "photos": Word(key: "NSPhotoLibraryUsageDescription", kind: .usage, platforms: both),
        "photolibrary": Word(key: "NSPhotoLibraryUsageDescription", kind: .usage, platforms: both),
        "photosadd": Word(key: "NSPhotoLibraryAddUsageDescription", kind: .usage, platforms: both),
        "savephotos": Word(key: "NSPhotoLibraryAddUsageDescription", kind: .usage, platforms: both),
        "localnetwork": Word(key: "NSLocalNetworkUsageDescription", kind: .usage, platforms: both),
        "location": Word(key: "NSLocationWhenInUseUsageDescription", kind: .usage, platforms: both),
        "contacts": Word(key: "NSContactsUsageDescription", kind: .usage, platforms: both),
        "calendars": Word(key: "NSCalendarsFullAccessUsageDescription", kind: .usage, platforms: both),
        "reminders": Word(key: "NSRemindersFullAccessUsageDescription", kind: .usage, platforms: both),
        "faceid": Word(key: "NSFaceIDUsageDescription", kind: .usage, platforms: [.iOS]),
        "bluetooth": Word(key: "NSBluetoothAlwaysUsageDescription", kind: .usage, platforms: both),
        "speech": Word(key: "NSSpeechRecognitionUsageDescription", kind: .usage, platforms: both),
        "motion": Word(key: "NSMotionUsageDescription", kind: .usage, platforms: [.iOS]),
        "tracking": Word(key: "NSUserTrackingUsageDescription", kind: .usage, platforms: both),
        "appleevents": Word(key: "NSAppleEventsUsageDescription", kind: .usage, platforms: [.macOS]),
        "category": Word(key: "LSApplicationCategoryType", kind: .category, platforms: both),
        "displayname": Word(key: "CFBundleDisplayName", kind: .text, platforms: both),
        "copyright": Word(key: "NSHumanReadableCopyright", kind: .text, platforms: [.macOS]),
        "encryption": Word(key: "ITSAppUsesNonExemptEncryption", kind: .boolean, platforms: both),
        "fullscreen": Word(key: "UIRequiresFullScreen", kind: .boolean, platforms: [.iOS]),
        "queries": Word(key: "LSApplicationQueriesSchemes", kind: .list, platforms: [.iOS]),
        "bonjour": Word(key: "NSBonjourServices", kind: .list, platforms: both),
    ]

    /// The short words as the guide and a refusal list them.
    static let named = ["camera", "microphone", "photos", "photosAdd", "localNetwork", "location", "contacts", "calendars",
                        "reminders", "faceID", "bluetooth", "speech", "motion", "tracking", "appleEvents", "category",
                        "displayName", "copyright", "encryption", "fullScreen", "queries", "bonjour"]

    /// `localNetwork`, `local network` and `local_network` alike.
    static func fold(_ word: String) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// The Info.plist keys Xcode writes from `INFOPLIST_KEY_<key>`.
    static let settings: Set<String> = [
        "CFBundleDisplayName", "ITSAppUsesNonExemptEncryption", "ITSEncryptionExportComplianceCode", "LSApplicationCategoryType",
        "LSBackgroundOnly", "LSSupportsOpeningDocumentsInPlace", "LSUIElement", "NFCReaderUsageDescription",
        "NSAccessoryTrackingUsageDescription", "NSAppDataUsageDescription", "NSAppleEventsUsageDescription",
        "NSAppleMusicUsageDescription", "NSBluetoothAlwaysUsageDescription", "NSBluetoothPeripheralUsageDescription",
        "NSBluetoothWhileInUseUsageDescription", "NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription",
        "NSCalendarsWriteOnlyAccessUsageDescription", "NSCameraUsageDescription", "NSContactsUsageDescription",
        "NSCriticalMessagingUsageDescription", "NSDesktopFolderUsageDescription", "NSDocumentsFolderUsageDescription",
        "NSDownloadsFolderUsageDescription", "NSFaceIDUsageDescription", "NSFallDetectionUsageDescription",
        "NSFileProviderDomainUsageDescription", "NSFileProviderPresenceUsageDescription", "NSFinancialDataUsageDescription",
        "NSFocusStatusUsageDescription", "NSGKFriendListUsageDescription", "NSHandsTrackingUsageDescription",
        "NSHealthClinicalHealthRecordsShareUsageDescription", "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription",
        "NSHomeKitUsageDescription", "NSHumanReadableCopyright", "NSIdentityUsageDescription", "NSLocalNetworkUsageDescription",
        "NSLocationAlwaysAndWhenInUseUsageDescription", "NSLocationAlwaysUsageDescription", "NSLocationUsageDescription",
        "NSLocationWhenInUseUsageDescription", "NSMainCameraUsageDescription", "NSMicrophoneUsageDescription",
        "NSMotionUsageDescription", "NSNearbyInteractionAllowOnceUsageDescription", "NSNearbyInteractionUsageDescription",
        "NSNetworkVolumesUsageDescription", "NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription",
        "NSRemindersFullAccessUsageDescription", "NSRemindersUsageDescription", "NSRemovableVolumesUsageDescription",
        "NSSensorKitPrivacyPolicyURL", "NSSensorKitUsageDescription", "NSSiriUsageDescription", "NSSpeechRecognitionUsageDescription",
        "NSSupportsLiveActivities", "NSSupportsLiveActivitiesFrequentUpdates", "NSSystemAdministrationUsageDescription",
        "NSSystemExtensionUsageDescription", "NSUserTrackingUsageDescription", "NSVideoSubscriberAccountUsageDescription",
        "NSVoIPUsageDescription", "NSWorldSensingUsageDescription", "OSBundleUsageDescription", "UIApplicationSupportsIndirectInputEvents",
        "UIRequiresFullScreen", "UIStatusBarHidden", "UIStatusBarStyle", "UISupportsDocumentBrowser", "UIUserInterfaceStyle",
    ]

    /// The `LSApplicationCategoryType` values, after `public.app-category.`.
    static let categories: [String] = [
        "business", "developer-tools", "education", "entertainment", "finance", "games", "graphics-design", "healthcare-fitness",
        "lifestyle", "medical", "music", "news", "photography", "productivity", "reference", "social-networking", "sports",
        "travel", "utilities", "video", "weather", "action-games", "adventure-games", "arcade-games", "board-games", "card-games",
        "casino-games", "dice-games", "educational-games", "family-games", "kids-games", "music-games", "puzzle-games",
        "racing-games", "role-playing-games", "simulation-games", "sports-games", "strategy-games", "trivia-games", "word-games",
    ]
}
