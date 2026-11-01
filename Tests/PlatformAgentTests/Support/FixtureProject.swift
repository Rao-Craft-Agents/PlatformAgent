//  WHAT: A project shaped as Granite's app template makes one (objectVersion 77; Shared, Components, Services, iOS
//        and macOS as synchronized folders; an app target for iOS and one for macOS; shared schemes), with the
//        Granite package taken out so it builds offline, and the files granite writes that this agent replaces:
//        what the agent edits in tests.

import Foundation

enum FixtureProject {
    /// Writes a project named `name` into `folder`: the project file, its schemes, and the app's few files.
    static func make(in folder: URL, name: String = "Recipes", bundleID: String = "com.example.recipes") throws {
        let manager = FileManager.default
        let bundle = folder.appendingPathComponent("\(name).xcodeproj", isDirectory: true)
        try manager.createDirectory(at: bundle.appendingPathComponent("xcshareddata/xcschemes"), withIntermediateDirectories: true)
        try manager.createDirectory(at: bundle.appendingPathComponent("project.xcworkspace"), withIntermediateDirectories: true)
        func write(_ text: String, _ path: String) throws {
            let url = folder.appendingPathComponent(path)
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.replacingOccurrences(of: "__PROJECT_NAME__", with: name).replacingOccurrences(of: "__BUNDLE_ID__", with: bundleID)
                .write(to: url, atomically: true, encoding: .utf8)
        }
        try write(project, "\(name).xcodeproj/project.pbxproj")
        try write(workspace, "\(name).xcodeproj/project.xcworkspace/contents.xcworkspacedata")
        for (platform, id) in [("iOS", "170000000000000000000001"), ("macOS", "170000000000000000000002")] {
            try write(scheme.replacingOccurrences(of: "__TARGET_ID__", with: id).replacingOccurrences(of: "__PLATFORM__", with: platform),
                      "\(name).xcodeproj/xcshareddata/xcschemes/\(name)-\(platform).xcscheme")
        }
        try write(app, "Shared/App.swift")
        try write(delegate, "Shared/AppDelegate.swift")
        try write(commands, "macOS/AppCommands.swift")
        try write(home, "Components/Home/Home.swift")
        try write(service, "Services/RecipeService/RecipeService.swift")
        try manager.createDirectory(at: folder.appendingPathComponent("iOS"), withIntermediateDirectories: true)
    }

    /// The app, as granite's `Shared/App.swift` has it: the delegate adaptors, the root, the menu on macOS.
    static let app = #"""
        import SwiftUI

        @main
        struct __PROJECT_NAME__App: App {
            #if os(iOS)
            @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
            #elseif os(macOS)
            @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
            #endif

            var body: some Scene {
                WindowGroup {
                    Home()
                }
                #if os(macOS)
                .commands { AppCommands() }
                #endif
            }
        }

        """#

    /// Granite's placeholder delegate, which this agent replaces.
    static let delegate = #"""
        import Foundation

        #if os(iOS)
        import UIKit

        final class AppDelegate: NSObject, UIApplicationDelegate {
            func application(_ application: UIApplication,
                             didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
                true
            }
        }
        #elseif os(macOS)
        import AppKit

        final class AppDelegate: NSObject, NSApplicationDelegate {
            func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
                true
            }
        }
        #endif

        """#

    /// Granite's placeholder menu, which this agent replaces.
    static let commands = #"""
        import SwiftUI

        struct AppCommands: Commands {
            var body: some Commands {
                EmptyCommands()
            }
        }

        """#

    static let home = #"""
        import SwiftUI

        struct Home: View {
            var body: some View {
                Text("Recipes")
            }
        }

        """#

    static let service = #"""
        import Foundation

        struct RecipeService {
            var titles: [String] = []
        }

        """#

    static let workspace = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
           <FileRef
              location = "self:">
           </FileRef>
        </Workspace>

        """#

    static let scheme = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "2660"
           version = "1.7">
           <BuildAction
              parallelizeBuildables = "YES"
              buildImplicitDependencies = "YES"
              buildArchitectures = "Automatic">
              <BuildActionEntries>
                 <BuildActionEntry
                    buildForTesting = "YES"
                    buildForRunning = "YES"
                    buildForProfiling = "YES"
                    buildForArchiving = "YES"
                    buildForAnalyzing = "YES">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "__TARGET_ID__"
                       BuildableName = "__PROJECT_NAME__.app"
                       BlueprintName = "__PROJECT_NAME__-__PLATFORM__"
                       ReferencedContainer = "container:__PROJECT_NAME__.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES"
              shouldAutocreateTestPlan = "YES">
           </TestAction>
           <LaunchAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              launchStyle = "0"
              useCustomWorkingDirectory = "NO"
              ignoresPersistentStateOnLaunch = "NO"
              debugDocumentVersioning = "YES"
              debugServiceExtension = "internal"
              allowLocationSimulation = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "__TARGET_ID__"
                    BuildableName = "__PROJECT_NAME__.app"
                    BlueprintName = "__PROJECT_NAME__-__PLATFORM__"
                    ReferencedContainer = "container:__PROJECT_NAME__.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </LaunchAction>
           <ProfileAction
              buildConfiguration = "Release"
              shouldUseLaunchSchemeArgsEnv = "YES"
              savedToolIdentifier = ""
              useCustomWorkingDirectory = "NO"
              debugDocumentVersioning = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "__TARGET_ID__"
                    BuildableName = "__PROJECT_NAME__.app"
                    BlueprintName = "__PROJECT_NAME__-__PLATFORM__"
                    ReferencedContainer = "container:__PROJECT_NAME__.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </ProfileAction>
           <AnalyzeAction
              buildConfiguration = "Debug">
           </AnalyzeAction>
           <ArchiveAction
              buildConfiguration = "Release"
              revealArchiveInOrganizer = "YES">
           </ArchiveAction>
        </Scheme>

        """#

    static let project = #"""
        // !$*UTF8*$!
        {
        	archiveVersion = 1;
        	classes = {
        	};
        	objectVersion = 77;
        	objects = {

        /* Begin PBXFileReference section */
        		130000000000000000000001 /* __PROJECT_NAME__.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = __PROJECT_NAME__.app; sourceTree = BUILT_PRODUCTS_DIR; };
        		130000000000000000000002 /* __PROJECT_NAME__.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = __PROJECT_NAME__.app; sourceTree = BUILT_PRODUCTS_DIR; };
        /* End PBXFileReference section */

        /* Begin PBXFileSystemSynchronizedRootGroup section */
        		140000000000000000000001 /* Shared */ = {
        			isa = PBXFileSystemSynchronizedRootGroup;
        			path = Shared;
        			sourceTree = "<group>";
        		};
        		140000000000000000000002 /* iOS */ = {
        			isa = PBXFileSystemSynchronizedRootGroup;
        			path = iOS;
        			sourceTree = "<group>";
        		};
        		140000000000000000000003 /* macOS */ = {
        			isa = PBXFileSystemSynchronizedRootGroup;
        			path = macOS;
        			sourceTree = "<group>";
        		};
        		140000000000000000000004 /* Components */ = {
        			isa = PBXFileSystemSynchronizedRootGroup;
        			path = Components;
        			sourceTree = "<group>";
        		};
        		140000000000000000000005 /* Services */ = {
        			isa = PBXFileSystemSynchronizedRootGroup;
        			path = Services;
        			sourceTree = "<group>";
        		};
        /* End PBXFileSystemSynchronizedRootGroup section */

        /* Begin PBXFrameworksBuildPhase section */
        		150000000000000000000001 /* Frameworks */ = {
        			isa = PBXFrameworksBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        		150000000000000000000002 /* Frameworks */ = {
        			isa = PBXFrameworksBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        /* End PBXFrameworksBuildPhase section */

        /* Begin PBXGroup section */
        		160000000000000000000001 = {
        			isa = PBXGroup;
        			children = (
        				140000000000000000000001 /* Shared */,
        				140000000000000000000004 /* Components */,
        				140000000000000000000005 /* Services */,
        				140000000000000000000002 /* iOS */,
        				140000000000000000000003 /* macOS */,
        				160000000000000000000002 /* Products */,
        			);
        			sourceTree = "<group>";
        		};
        		160000000000000000000002 /* Products */ = {
        			isa = PBXGroup;
        			children = (
        				130000000000000000000001 /* __PROJECT_NAME__.app */,
        				130000000000000000000002 /* __PROJECT_NAME__.app */,
        			);
        			name = Products;
        			sourceTree = "<group>";
        		};
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
        		170000000000000000000001 /* __PROJECT_NAME__-iOS */ = {
        			isa = PBXNativeTarget;
        			buildConfigurationList = 180000000000000000000002 /* Build configuration list for PBXNativeTarget "__PROJECT_NAME__-iOS" */;
        			buildPhases = (
        				190000000000000000000001 /* Sources */,
        				150000000000000000000001 /* Frameworks */,
        				1A0000000000000000000001 /* Resources */,
        			);
        			buildRules = (
        			);
        			dependencies = (
        			);
        			fileSystemSynchronizedGroups = (
        				140000000000000000000001 /* Shared */,
        				140000000000000000000004 /* Components */,
        				140000000000000000000005 /* Services */,
        				140000000000000000000002 /* iOS */,
        			);
        			name = __PROJECT_NAME__-iOS;
        			packageProductDependencies = (
        			);
        			productName = __PROJECT_NAME__;
        			productReference = 130000000000000000000001 /* __PROJECT_NAME__.app */;
        			productType = "com.apple.product-type.application";
        		};
        		170000000000000000000002 /* __PROJECT_NAME__-macOS */ = {
        			isa = PBXNativeTarget;
        			buildConfigurationList = 180000000000000000000003 /* Build configuration list for PBXNativeTarget "__PROJECT_NAME__-macOS" */;
        			buildPhases = (
        				190000000000000000000002 /* Sources */,
        				150000000000000000000002 /* Frameworks */,
        				1A0000000000000000000002 /* Resources */,
        			);
        			buildRules = (
        			);
        			dependencies = (
        			);
        			fileSystemSynchronizedGroups = (
        				140000000000000000000001 /* Shared */,
        				140000000000000000000004 /* Components */,
        				140000000000000000000005 /* Services */,
        				140000000000000000000003 /* macOS */,
        			);
        			name = __PROJECT_NAME__-macOS;
        			packageProductDependencies = (
        			);
        			productName = __PROJECT_NAME__;
        			productReference = 130000000000000000000002 /* __PROJECT_NAME__.app */;
        			productType = "com.apple.product-type.application";
        		};
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
        		1B0000000000000000000001 /* Project object */ = {
        			isa = PBXProject;
        			attributes = {
        				BuildIndependentTargetsInParallel = 1;
        				LastSwiftUpdateCheck = 2660;
        				LastUpgradeCheck = 2660;
        				TargetAttributes = {
        					170000000000000000000001 = {
        						CreatedOnToolsVersion = 26.0;
        					};
        					170000000000000000000002 = {
        						CreatedOnToolsVersion = 26.0;
        					};
        				};
        			};
        			buildConfigurationList = 180000000000000000000001 /* Build configuration list for PBXProject "__PROJECT_NAME__" */;
        			developmentRegion = en;
        			hasScannedForEncodings = 0;
        			knownRegions = (
        				en,
        				Base,
        			);
        			mainGroup = 160000000000000000000001;
        			minimizedProjectReferenceProxies = 1;
        			preferredProjectObjectVersion = 77;
        			productRefGroup = 160000000000000000000002 /* Products */;
        			projectDirPath = "";
        			projectRoot = "";
        			targets = (
        				170000000000000000000001 /* __PROJECT_NAME__-iOS */,
        				170000000000000000000002 /* __PROJECT_NAME__-macOS */,
        			);
        		};
        /* End PBXProject section */

        /* Begin PBXResourcesBuildPhase section */
        		1A0000000000000000000001 /* Resources */ = {
        			isa = PBXResourcesBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        		1A0000000000000000000002 /* Resources */ = {
        			isa = PBXResourcesBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        /* End PBXResourcesBuildPhase section */

        /* Begin PBXSourcesBuildPhase section */
        		190000000000000000000001 /* Sources */ = {
        			isa = PBXSourcesBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        		190000000000000000000002 /* Sources */ = {
        			isa = PBXSourcesBuildPhase;
        			buildActionMask = 2147483647;
        			files = (
        			);
        			runOnlyForDeploymentPostprocessing = 0;
        		};
        /* End PBXSourcesBuildPhase section */

        /* Begin XCBuildConfiguration section */
        		1D0000000000000000000001 /* Debug */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ALWAYS_SEARCH_USER_PATHS = NO;
        				CLANG_ANALYZER_NONNULL = YES;
        				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
        				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
        				CLANG_ENABLE_MODULES = YES;
        				CLANG_ENABLE_OBJC_ARC = YES;
        				CLANG_ENABLE_OBJC_WEAK = YES;
        				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
        				CLANG_WARN_BOOL_CONVERSION = YES;
        				CLANG_WARN_COMMA = YES;
        				CLANG_WARN_CONSTANT_CONVERSION = YES;
        				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
        				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
        				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
        				CLANG_WARN_EMPTY_BODY = YES;
        				CLANG_WARN_ENUM_CONVERSION = YES;
        				CLANG_WARN_INFINITE_RECURSION = YES;
        				CLANG_WARN_INT_CONVERSION = YES;
        				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
        				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
        				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
        				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
        				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
        				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
        				CLANG_WARN_STRICT_PROTOTYPES = YES;
        				CLANG_WARN_SUSPICIOUS_MOVE = YES;
        				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
        				CLANG_WARN_UNREACHABLE_CODE = YES;
        				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
        				COPY_PHASE_STRIP = NO;
        				DEBUG_INFORMATION_FORMAT = dwarf;
        				DEVELOPMENT_TEAM = "";
        				ENABLE_STRICT_OBJC_MSGSEND = YES;
        				ENABLE_TESTABILITY = YES;
        				ENABLE_USER_SCRIPT_SANDBOXING = YES;
        				GCC_C_LANGUAGE_STANDARD = gnu17;
        				GCC_DYNAMIC_NO_PIC = NO;
        				GCC_NO_COMMON_BLOCKS = YES;
        				GCC_OPTIMIZATION_LEVEL = 0;
        				GCC_PREPROCESSOR_DEFINITIONS = (
        					"DEBUG=1",
        					"$(inherited)",
        				);
        				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
        				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
        				GCC_WARN_UNDECLARED_SELECTOR = YES;
        				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
        				GCC_WARN_UNUSED_FUNCTION = YES;
        				GCC_WARN_UNUSED_VARIABLE = YES;
        				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
        				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
        				MTL_FAST_MATH = YES;
        				ONLY_ACTIVE_ARCH = YES;
        				SDKROOT = auto;
        				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
        				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
        			};
        			name = Debug;
        		};
        		1D0000000000000000000002 /* Release */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ALWAYS_SEARCH_USER_PATHS = NO;
        				CLANG_ANALYZER_NONNULL = YES;
        				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
        				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
        				CLANG_ENABLE_MODULES = YES;
        				CLANG_ENABLE_OBJC_ARC = YES;
        				CLANG_ENABLE_OBJC_WEAK = YES;
        				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
        				CLANG_WARN_BOOL_CONVERSION = YES;
        				CLANG_WARN_COMMA = YES;
        				CLANG_WARN_CONSTANT_CONVERSION = YES;
        				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
        				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
        				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
        				CLANG_WARN_EMPTY_BODY = YES;
        				CLANG_WARN_ENUM_CONVERSION = YES;
        				CLANG_WARN_INFINITE_RECURSION = YES;
        				CLANG_WARN_INT_CONVERSION = YES;
        				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
        				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
        				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
        				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
        				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
        				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
        				CLANG_WARN_STRICT_PROTOTYPES = YES;
        				CLANG_WARN_SUSPICIOUS_MOVE = YES;
        				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
        				CLANG_WARN_UNREACHABLE_CODE = YES;
        				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
        				COPY_PHASE_STRIP = NO;
        				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
        				DEVELOPMENT_TEAM = "";
        				ENABLE_NS_ASSERTIONS = NO;
        				ENABLE_STRICT_OBJC_MSGSEND = YES;
        				ENABLE_USER_SCRIPT_SANDBOXING = YES;
        				GCC_C_LANGUAGE_STANDARD = gnu17;
        				GCC_NO_COMMON_BLOCKS = YES;
        				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
        				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
        				GCC_WARN_UNDECLARED_SELECTOR = YES;
        				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
        				GCC_WARN_UNUSED_FUNCTION = YES;
        				GCC_WARN_UNUSED_VARIABLE = YES;
        				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
        				MTL_ENABLE_DEBUG_INFO = NO;
        				MTL_FAST_MATH = YES;
        				SDKROOT = auto;
        				SWIFT_COMPILATION_MODE = wholemodule;
        			};
        			name = Release;
        		};
        		1D0000000000000000000003 /* Debug */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        				CODE_SIGN_STYLE = Automatic;
        				CURRENT_PROJECT_VERSION = 1;
        				DEVELOPMENT_TEAM = "";
        				ENABLE_PREVIEWS = YES;
        				GENERATE_INFOPLIST_FILE = YES;
        				INFOPLIST_KEY_CFBundleDisplayName = __PROJECT_NAME__;
        				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
        				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
        				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
        				LD_RUNPATH_SEARCH_PATHS = (
        					"$(inherited)",
        					"@executable_path/Frameworks",
        				);
        				MARKETING_VERSION = 1.0;
        				PRODUCT_BUNDLE_IDENTIFIER = __BUNDLE_ID__;
        				PRODUCT_NAME = __PROJECT_NAME__;
        				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        				SUPPORTS_MACCATALYST = NO;
        				SWIFT_EMIT_LOC_STRINGS = YES;
        				SWIFT_STRICT_CONCURRENCY = complete;
        				SWIFT_VERSION = 5.0;
        				TARGETED_DEVICE_FAMILY = "1,2";
        			};
        			name = Debug;
        		};
        		1D0000000000000000000004 /* Release */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        				CODE_SIGN_STYLE = Automatic;
        				CURRENT_PROJECT_VERSION = 1;
        				DEVELOPMENT_TEAM = "";
        				ENABLE_PREVIEWS = YES;
        				GENERATE_INFOPLIST_FILE = YES;
        				INFOPLIST_KEY_CFBundleDisplayName = __PROJECT_NAME__;
        				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
        				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
        				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
        				LD_RUNPATH_SEARCH_PATHS = (
        					"$(inherited)",
        					"@executable_path/Frameworks",
        				);
        				MARKETING_VERSION = 1.0;
        				PRODUCT_BUNDLE_IDENTIFIER = __BUNDLE_ID__;
        				PRODUCT_NAME = __PROJECT_NAME__;
        				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        				SUPPORTS_MACCATALYST = NO;
        				SWIFT_EMIT_LOC_STRINGS = YES;
        				SWIFT_STRICT_CONCURRENCY = complete;
        				SWIFT_VERSION = 5.0;
        				TARGETED_DEVICE_FAMILY = "1,2";
        				VALIDATE_PRODUCT = YES;
        			};
        			name = Release;
        		};
        		1D0000000000000000000005 /* Debug */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        				CODE_SIGN_STYLE = Automatic;
        				COMBINE_HIDPI_IMAGES = YES;
        				CURRENT_PROJECT_VERSION = 1;
        				DEVELOPMENT_TEAM = "";
        				ENABLE_APP_SANDBOX = YES;
        				ENABLE_HARDENED_RUNTIME = YES;
        				ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
        				ENABLE_PREVIEWS = YES;
        				ENABLE_USER_SELECTED_FILES = readonly;
        				GENERATE_INFOPLIST_FILE = YES;
        				INFOPLIST_KEY_CFBundleDisplayName = __PROJECT_NAME__;
        				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
        				LD_RUNPATH_SEARCH_PATHS = (
        					"$(inherited)",
        					"@executable_path/../Frameworks",
        				);
        				MACOSX_DEPLOYMENT_TARGET = 14.0;
        				MARKETING_VERSION = 1.0;
        				PRODUCT_BUNDLE_IDENTIFIER = __BUNDLE_ID__;
        				PRODUCT_NAME = __PROJECT_NAME__;
        				SDKROOT = macosx;
        				SWIFT_EMIT_LOC_STRINGS = YES;
        				SWIFT_STRICT_CONCURRENCY = complete;
        				SWIFT_VERSION = 5.0;
        			};
        			name = Debug;
        		};
        		1D0000000000000000000006 /* Release */ = {
        			isa = XCBuildConfiguration;
        			buildSettings = {
        				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        				CODE_SIGN_STYLE = Automatic;
        				COMBINE_HIDPI_IMAGES = YES;
        				CURRENT_PROJECT_VERSION = 1;
        				DEVELOPMENT_TEAM = "";
        				ENABLE_APP_SANDBOX = YES;
        				ENABLE_HARDENED_RUNTIME = YES;
        				ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
        				ENABLE_PREVIEWS = YES;
        				ENABLE_USER_SELECTED_FILES = readonly;
        				GENERATE_INFOPLIST_FILE = YES;
        				INFOPLIST_KEY_CFBundleDisplayName = __PROJECT_NAME__;
        				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
        				LD_RUNPATH_SEARCH_PATHS = (
        					"$(inherited)",
        					"@executable_path/../Frameworks",
        				);
        				MACOSX_DEPLOYMENT_TARGET = 14.0;
        				MARKETING_VERSION = 1.0;
        				PRODUCT_BUNDLE_IDENTIFIER = __BUNDLE_ID__;
        				PRODUCT_NAME = __PROJECT_NAME__;
        				SDKROOT = macosx;
        				SWIFT_EMIT_LOC_STRINGS = YES;
        				SWIFT_STRICT_CONCURRENCY = complete;
        				SWIFT_VERSION = 5.0;
        				VALIDATE_PRODUCT = YES;
        			};
        			name = Release;
        		};
        /* End XCBuildConfiguration section */

        /* Begin XCConfigurationList section */
        		180000000000000000000001 /* Build configuration list for PBXProject "__PROJECT_NAME__" */ = {
        			isa = XCConfigurationList;
        			buildConfigurations = (
        				1D0000000000000000000001 /* Debug */,
        				1D0000000000000000000002 /* Release */,
        			);
        			defaultConfigurationIsVisible = 0;
        			defaultConfigurationName = Release;
        		};
        		180000000000000000000002 /* Build configuration list for PBXNativeTarget "__PROJECT_NAME__-iOS" */ = {
        			isa = XCConfigurationList;
        			buildConfigurations = (
        				1D0000000000000000000003 /* Debug */,
        				1D0000000000000000000004 /* Release */,
        			);
        			defaultConfigurationIsVisible = 0;
        			defaultConfigurationName = Release;
        		};
        		180000000000000000000003 /* Build configuration list for PBXNativeTarget "__PROJECT_NAME__-macOS" */ = {
        			isa = XCConfigurationList;
        			buildConfigurations = (
        				1D0000000000000000000005 /* Debug */,
        				1D0000000000000000000006 /* Release */,
        			);
        			defaultConfigurationIsVisible = 0;
        			defaultConfigurationName = Release;
        		};
        /* End XCConfigurationList section */
        	};
        	rootObject = 1B0000000000000000000001 /* Project object */;
        }

        """#
}
