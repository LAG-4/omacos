import Foundation

/// Frozen visual and interaction values extracted from one exact Omarchy Quattro revision.
struct OMacOSShellContract: Codable, Equatable {
    let schemaVersion: Int
    let reference: Reference
    let bar: Bar
    let menu: Menu
    let typography: Typography
    let spacing: Spacing
    let controls: Controls
    let animation: Animation

    struct Reference: Codable, Equatable {
        let repository: String
        let branch: String
        let commit: String
        let sources: [String]
    }

    struct Bar: Codable, Equatable {
        let horizontalSize: Int
        let verticalSize: Int
        let iconSlot: Int
        let iconCanvas: Int
        let iconFont: Int
        let statusSlot: Int
        let centerAnchor: String
        let layout: Layout
    }

    struct Layout: Codable, Equatable {
        let left: [String]
        let center: [String]
        let right: [String]
    }

    struct Menu: Codable, Equatable {
        let width: Int
        let specialWidth: Int
        let panelPadding: Int
        let headerHeight: Int
        let rowHeight: Int
        let detailRowHeight: Int
        let rowPeekFraction: Double
        let rowSpacing: Int
        let contentSpacing: Int
        let screenEdgeGap: Int
        let cornerRadius: Int
        let maximumScreenHeightFraction: Double
        let scrimOpacity: Double
        let selectedBackgroundOpacity: Double
        let selectedBorderOpacity: Double
    }

    struct Typography: Codable, Equatable {
        let family: String
        let base: Int
        let caption: Int
        let bodySmall: Int
        let body: Int
        let subtitle: Int
        let title: Int
        let heading: Int
        let display: Int
        let displayLarge: Int
        let iconLarge: Int
    }

    struct Spacing: Codable, Equatable {
        let xxs: Int
        let xs: Int
        let sm: Int
        let md: Int
        let lg: Int
        let xl: Int
        let xxl: Int
        let xxxl: Int
        let huge: Int
        let windowInner: Int
        let windowOuter: Int
    }

    struct Controls: Codable, Equatable {
        let normalFillOpacity: Double
        let hoverFillOpacity: Double
        let selectedFillOpacity: Double
        let pressedFillOpacity: Double
        let selectionFillOpacity: Double
        let normalBorderOpacity: Double
        let hoverBorderOpacity: Double
    }

    struct Animation: Codable, Equatable {
        let themeColorMilliseconds: Int
        let interactionMilliseconds: Int
        let selectionColorMilliseconds: Int
        let panelIndicatorMilliseconds: Int
    }

    static let shared = OMacOSShellContract.loadBundled()

    /// Loads the packaged contract and fails early if a release omitted or corrupted it.
    static func loadBundled() -> OMacOSShellContract {
#if OMACOS_STANDALONE_TEST
        return quattroDefault
#else
        guard let url = Bundle.module.url(forResource: "omarchy-shell-contract", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let contract = try? JSONDecoder().decode(OMacOSShellContract.self, from: data),
              contract.schemaVersion == 1 else {
            fatalError("OMacOS shell contract is missing, invalid, or unsupported")
        }
        return contract
#endif
    }

    /// Keeps small standalone geometry tests independent of SwiftPM's generated resource bundle.
    private static let quattroDefault = OMacOSShellContract(
        schemaVersion: 1,
        reference: Reference(
            repository: "basecamp/omarchy",
            branch: "quattro",
            commit: "0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516",
            sources: []
        ),
        bar: Bar(
            horizontalSize: 26,
            verticalSize: 28,
            iconSlot: 27,
            iconCanvas: 16,
            iconFont: 13,
            statusSlot: 21,
            centerAnchor: "omarchy.clock",
            layout: Layout(left: ["omarchy.menu", "omarchy.workspaces"], center: [], right: [])
        ),
        menu: Menu(
            width: 300,
            specialWidth: 520,
            panelPadding: 18,
            headerHeight: 34,
            rowHeight: 50,
            detailRowHeight: 58,
            rowPeekFraction: 0.55,
            rowSpacing: 3,
            contentSpacing: 6,
            screenEdgeGap: 5,
            cornerRadius: 0,
            maximumScreenHeightFraction: 0.7,
            scrimOpacity: 0.5,
            selectedBackgroundOpacity: 0.08,
            selectedBorderOpacity: 0.25
        ),
        typography: Typography(
            family: "JetBrainsMono Nerd Font",
            base: 12,
            caption: 10,
            bodySmall: 11,
            body: 12,
            subtitle: 13,
            title: 14,
            heading: 16,
            display: 24,
            displayLarge: 28,
            iconLarge: 18
        ),
        spacing: Spacing(
            xxs: 2,
            xs: 3,
            sm: 4,
            md: 6,
            lg: 8,
            xl: 10,
            xxl: 12,
            xxxl: 14,
            huge: 18,
            windowInner: 5,
            windowOuter: 10
        ),
        controls: Controls(
            normalFillOpacity: 0.04,
            hoverFillOpacity: 0.08,
            selectedFillOpacity: 0.18,
            pressedFillOpacity: 0.22,
            selectionFillOpacity: 0.35,
            normalBorderOpacity: 0.4,
            hoverBorderOpacity: 0.25
        ),
        animation: Animation(
            themeColorMilliseconds: 420,
            interactionMilliseconds: 140,
            selectionColorMilliseconds: 60,
            panelIndicatorMilliseconds: 120
        )
    )
}
