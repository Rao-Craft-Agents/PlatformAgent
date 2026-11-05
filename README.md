# PlatformAgent

Give an iOS and macOS app what it needs from the system by saying what the app does. Tell `platform` the app takes
photos, opens its own links, takes a link or a photo from the share sheet and has commands in the Mac menu bar, and it
edits the Xcode project to match: the Info keys with their reasons, URL schemes, App Transport Security, entitlements
and the Mac sandbox, the app delegate, menu commands and app extensions. It merges into the Info.plists and
entitlements the project already has, and writes the Swift your views use to answer what was added.

## What you can ask

```
$platform the recipe app takes photos of dishes and opens recipes:// links
$platform let people save a link or a photo to the recipe app from the share sheet
$platform New Recipe and Start Timer in the Mac menu bar, the timer in a Kitchen menu of its own
$platform the Mac app's sandbox lets it reach the network, and it shares an app group with its extension
```

Craft writes the call from your request, shows it on its agent map, and builds and tests what it changed with the turn.

## What you get

- **Info keys with their reasons.** Camera, photos, location, Face ID and the other privacy keys, each with a sentence
  saying why, on the iOS and macOS targets they apply to; the app's category, display name and the schemes it queries.
- **Links that open the app.** URL schemes in each platform's Info.plist, and `.onOpenAppURL { url in }` for your
  views; a link that launched the app waits for the first view that takes it, so it is not lost.
- **Entitlements, the sandbox and App Transport Security.** App groups, keychain groups, what the Mac sandbox lets the
  app reach (the network, a server, files, the camera, photos, USB), and HTTPS only, any host, or HTTP to the hosts you
  name.
- **Mac menu commands.** `New Recipe ⌘N` in File, `Refresh ⌘R` in View, or a menu of the app's own, each answered with
  `.onAppCommand`; the shortcuts that belong to the system are refused.
- **Share and Action extensions.** An iOS extension for each you name, with the title the share sheet shows and what it
  accepts (links, images, text), an app group it shares with the app, and `.onSharedInbox { items in }` for the app to
  read what it left.
- **An app delegate.** One file for iOS and macOS that hands opened URLs to the app, sets text view appearance and
  posts Mac window clicks, holding no app state.

## How it works

- No model is asked: the same request makes the same files every time, and asking for the same thing twice writes
  nothing.
- Every edit looks before it adds: plists and entitlements are merged, and an earlier call's menu commands are read
  back and kept.
- A line it cannot read, or anything the project cannot take (a menu with no macOS target, an extension with no iOS
  target), is refused with every reason at once, and nothing is written.
- The edited project is read back with every reference defined and the Swift parsed before anything lands.

## Works well with

`platform` is one of the Rao Craft Agents, packages you tag in requests along the life of a project to build an app of
[Loom](https://github.com/riteshpakala/Loom)'s quality. It is Loom's app delegate, its two Info.plists and
entitlements, and its Action extension, said generally for any app. A project made by `granite` takes everything it
writes.

## Get it

In Craft, install Platform from the Agent Store, or run
`craft agents add https://github.com/Rao-Craft-Agents/PlatformAgent.git`, then say `$platform` in a request.

## Requirements

- A Mac on macOS 14 or later, with Xcode.
- An app's Xcode project. A project made by `granite` (synchronized folders, a target per platform) takes everything;
  an older project takes keys, schemes, entitlements and the Swift files, with a note naming the files to add to its
  targets, and is refused an extension.
- Menu commands need a macOS target, and extensions an iOS target.
- MIT licensed.

## For developers

What a call takes and answers, the lines it reads and how each part of the project is edited are in the
[reference](Docs/Reference.md), and how it is measured is [TESTING.md](TESTING.md).
