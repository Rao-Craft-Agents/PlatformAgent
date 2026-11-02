# Testing PlatformAgent

## Conformance on Hearth

Level 1 of the regime: the call a model should write, sent straight to the installed runner over its wire
(granite-agent/1) with no model, on a copy of Hearth as the journey left it (services, mock data and loom's views
made), then checked by building, testing and screenshotting the app. A pass here means the agent can produce the
result deterministically; whether Craft's model writes this call is tested by the prompts above.

### Hearth's photo key, URL scheme and Mac menu commands

*2026-11-01 · straight to the runner, no model*

**The call**:

```json
{
  "keys": [
    "photos: \"attaches a photo of what you cooked to a post\"",
    "category: lifestyle"
  ],
  "schemes": [
    "hearth"
  ],
  "commands": [
    "New Post ⌘N",
    "Refresh ⌘R"
  ]
}
```

**Checks**:
- changes: Info NSPhotoLibraryUsageDescription, LSApplicationCategoryType, URL scheme hearth, delegate urls, File > New Post ⌘N, View > Refresh ⌘R
- macOS build: BUILD SUCCEEDED
