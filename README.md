# PlatformAgent

The platform layer of an iOS + macOS app, done by editing its Xcode project, shipped as a
[Granite](https://github.com/riteshpakala/Granite) agent package: Info keys and URL schemes, App Transport Security,
entitlements and the macOS sandbox, the app delegate, macOS menu commands, and app extensions (an Action or Share
extension with its app group, and the inbox the app reads what it left from). A call says what the app needs in a
few short lines; the package edits `project.pbxproj` as text, merges into the Info.plists and entitlements already
there, and writes the Swift the app answers with.

It is one of the [Rao Craft Agents](https://github.com/Rao-Craft-Agents): independent packages that, tagged in prompts
along the life of a project, build an app of [Loom](https://github.com/riteshpakala/Loom)'s quality. `platform` is
Loom's `AppDelegate`, its two Info.plists and entitlements, and its `Action/SetInstance` extension, said generally.

## How an app finds it

PlatformAgent is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let platformRecord: GraniteRoster.Record = { GraniteRoster.record(PlatformAgent.self) }
```

In [Craft](https://github.com/riteshpakala/Craft), install it from the Agent Store or with
`craft agents add https://github.com/Rao-Craft-Agents/PlatformAgent.git`, then say `$platform` in a request:

```
$platform the recipe app takes photos of dishes, opens recipes:// links, lets people save a link or
a photo to it from the share sheet, and has New Recipe and Start Timer in the Mac menu bar
```

The model writes the call; it shows on Craft's agent map as `platform-1`, and the files it names are built and tested
with the turn.

## What a call takes and answers

| Field | | |
|---|---|---|
| `keys` | optional | one Info key a line: `camera: "takes photos of the dishes you cook"`, `category: lifestyle`, `queries: maps, comgooglemaps`, `bonjour: _recipes._tcp`, or an Info.plist key by its own name (`UIBackgroundModes: [fetch]`) |
| `schemes` | optional | URL schemes that open the app: `recipes` |
| `ats` | optional | `default` (HTTPS only), `arbitrary` (any host), `domains` (HTTP to `atsDomains`) |
| `atsDomains` | optional | hosts `ats: domains` lets the app reach over HTTP, subdomains included |
| `groups` | optional | app groups: `group.com.example.recipes` |
| `keychain` | optional | keychain access groups: `com.example.recipes.shared` |
| `sandbox` | optional | the macOS sandbox: `network`, `server`, `files`, `camera`, `photos`, `usb` |
| `commands` | optional | macOS menu commands, one a line: `New Recipe ⌘N`, `Kitchen > Start Timer ⇧⌘T` |
| `extensions` | optional | iOS app extensions, one a line: `action SaveRecipe "Save to Recipes" accepts url,image` |
| `delegate` | optional | what the app delegate does: `urls`, `appearance`, `monitors` |
| `app` | optional | the app's name, when the folder holds several projects; the project's name when left out |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model |

The answer is a `PlatformResult`: every file written (`path`, `paths`, absolute), a phrase a change
(`URL scheme recipes`, `extension SaveRecipeAction (action: url, image)`), and a sentence for each assumption and for
how the app answers what was added. A call that finds everything already there writes nothing and says so.

## The lines

```
keys:        camera: "takes photos of the dishes you cook"     → INFOPLIST_KEY_NSCameraUsageDescription, iOS and macOS
             faceID: "unlocks your private recipes"           → iOS only
             category: lifestyle                              → public.app-category.lifestyle
             queries: maps, comgooglemaps                     → LSApplicationQueriesSchemes in iOS/Info.plist
commands:    New Recipe ⌘N                                    → File (replaces New Window, which held ⌘N)
             Refresh ⌘R                                       → View
             Kitchen > Start Timer ⇧⌘T                        → a Kitchen menu of the app's own
extensions:  action SaveRecipe "Save to Recipes" accepts url,image
             share ShareToKitchen "Kitchen" accepts text
```

- A key is a word this agent knows (camera, microphone, photos, photosAdd, localNetwork, location, contacts,
  calendars, reminders, faceID, bluetooth, speech, motion, tracking, appleEvents, category, displayName, copyright,
  encryption, fullScreen, queries, bonjour) or an Info.plist key by its own name. A why is made a sentence. A key
  Xcode has a setting for is written as `INFOPLIST_KEY_<key>` on the app targets it applies to; a list, or a key
  with no setting, goes in that platform's Info.plist.
- A command is `Menu > Title shortcut`, the shortcut as the menu shows it (`⇧⌘T`) or as typed (`cmd+shift+t`).
  With no menu, the title's first word places it (New, Open, Save → File; Show, Hide, Toggle, Refresh → View; Find,
  Search → Edit; Go, Next, Previous → Go); a title that says nothing of where is refused. ⌘Q, ⌘W, ⌘H, ⌘M, ⌘, and the
  edit shortcuts are the system's and are refused.
- An extension is `action` or `share`, an UpperCamelCase name, the title the share sheet shows (the name's words when
  left out), and what it accepts: url, image, text (url when left out).
- A line it cannot read, or anything the project cannot take (a menu with no macOS target, an extension with no iOS
  target), is refused with the reason, every one at once, and nothing is written.

## How the project is edited

| What | Where |
|---|---|
| Info keys | `INFOPLIST_KEY_*` build settings on each app target the key applies to |
| Schemes, ATS, lists | `iOS/Info.plist`, `macOS/Info.plist` (or the file `INFOPLIST_FILE` already names), merged; `INFOPLIST_FILE` set, and the file kept out of its synchronized folder's target so it is not copied into the app |
| Entitlements | `iOS/<App>.entitlements`, `macOS/<App>.entitlements` (or the file `CODE_SIGN_ENTITLEMENTS` names), merged; on macOS the `ENABLE_*` sandbox settings set to agree with the file, since Xcode signs both |
| The delegate | `Shared/AppDelegate.swift`, replaced: one file, iOS and macOS behind `#if os()`; opened URLs to `AppURL` (on iOS through a scene delegate, where URLs arrive), `UITextView` appearance, macOS click monitors posting `WindowClick` under Granite's names; no app state |
| URLs | `Shared/Utility/AppURL.swift` (a URL waits for the first view that takes it, so one that launched the app is not lost) and `.onOpenAppURL { url in }` |
| Menu commands | `Shared/Utility/AppCommand.swift` (a case a command), `.onAppCommand(.newRecipe) { }`, and `macOS/AppCommands.swift`, replaced; an earlier call's commands are read back and kept |
| Extensions | a target per line (`SaveRecipeAction`, embedded in the iOS app by an Embed Foundation Extensions phase, its folder `Action/SaveRecipe/` synchronized): its UIKit view controller reads what was shared, leaves it in the app group and opens the app by its scheme; its Info.plist names the extension point, the activation rule and the principal class; its entitlements hold the app group, which the iOS app gets too. The app reads them with `Shared/Utility/SharedInbox.swift` and `.onSharedInbox { items in }` |
| Checks | every object found by name before one is added, ids 24 hex digits never already in the project, the edited project read back with every reference defined, Swift parsed with `swiftc -parse`, everything staged and moved into place together |

No model is asked: the same call makes the same files every time, and the same call twice writes nothing. Projects
made by `granite` (objectVersion 77, synchronized folders, a target per platform) take everything; an older project
takes keys, schemes, entitlements and the Swift files, with a note naming the files to add to its targets, and is
refused an extension.

## Testing

```
swift test                                                  # the record, the schema, the lines, the project text, the calls
PLATFORM_BUILD=1 swift test --filter PlatformBuildTests     # every input on a fixture project, built for macOS and the iOS
                                                            # simulator (Swift 5 and 6), the built Info.plists, entitlements
                                                            # and embedded .appex read, the notifications run
```

MIT licensed.
