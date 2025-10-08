#if os(iOS)
import AVKit
import Foundation
import PDFKit
import SafariServices
@_spi(Private) @testable import Sentry
import SentryTestUtils
import SnapshotTesting
import SwiftUI
import UIKit
import WebKit
import XCTest

// The following command was used to derive the view hierarchy:
//
// ```
// (lldb) po rootView.value(forKey: "recursiveDescription")!
// ```
class SentryUIRedactBuilderTests_SwiftUI: SentryUIRedactBuilderTests {
    private func getSut(maskAllText: Bool, maskAllImages: Bool, maskedViewClasses: [AnyClass] = []) -> SentryUIRedactBuilder {
        return SentryUIRedactBuilder(options: TestRedactOptions(
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses
        ))
    }

    // MARK: - SwiftUI.Text Redaction

    private func setupSwiftUITextFixture() -> UIWindow {
        let view = VStack {
            VStack {
                Text("Hello SwiftUI")
                    .padding(20)
            }
            .background(Color.green)
            .font(.system(size: 20)) // Use a fixed font size as defaults could change frame
        }
        return hostSwiftUIViewInWindow(view, frame: CGRect(x: 0, y: 0, width: 250, height: 250))

        // View Hierarchy:
        // ---------------
        // == iOS 26 ==
        // <UIWindow: 0x10d23d120; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x600000ce6760>; layer = <UIWindowLayer: 0x600001729f80>>
        //   | <UITransitionView: 0x10d419a10; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000ce6460>>
        //   |    | <UIDropShadowView: 0x10d32b950; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000cd62b0>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGS1_GS2_VS_4TextVS_14_PaddingLayout__GVS_24_BackgroundStyleModifierVS_5Color____: 0x10900bc00; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x60000002c850>; backgroundColor = <UIDynamicSystemColor: 0x600001748a80; name = systemBackgroundColor>; layer = <CALayer: 0x600000cb0d50>>
        //   |    |    |    | <CALayer: 0x600000ceccf0> (layer)
        //   |    |    |    | <_TtC7SwiftUIP33_863CCF9D49B535DAEB1C7D61BEE53B5914CGDrawingLayer: 0x600002c21e80> (layer)
        //
        // == iOS 18 ==
        // <UIWindow: 0x104f3cce0; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x600000286360>; layer = <UIWindowLayer: 0x600000d982d0>>
        //   | <UITransitionView: 0x107a2c080; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000259de0>>
        //   |    | <UIDropShadowView: 0x107a2d500; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x60000025bc80>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGS1_GS2_VS_4TextVS_14_PaddingLayout__GVS_24_BackgroundStyleModifierVS_5Color____: 0x104c27a00; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x600000029520>; backgroundColor = <UIDynamicSystemColor: 0x6000017a7f40; name = systemBackgroundColor>; layer = <SwiftUI.UIHostingViewDebugLayer: 0x600000282f00>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x107a2f4e0; frame = (0 0; 120 81.3333); anchorPoint = (0, 0); autoresizesSubviews = NO; backgroundColor = UIExtendedSRGBColorSpace 0.203922 0.780392 0.34902 1; layer = <CALayer: 0x6000002b7060>>
        //   |    |    |    | <SwiftUI.CGDrawingView: 0x107a315a0; frame = (20.3333 41; 79.6667 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtC7SwiftUIP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x60000264d920>>
        //
        // == iOS 17 & 16 ==
        // <UIWindow: 0x130904a80; frame = (0 0; 250 250); gestureRecognizers = <NSArray: 0x60000287d530>; layer = <UIWindowLayer: 0x60000287d470>>
        //   | <UITransitionView: 0x130905370; frame = (0 0; 250 250); autoresize = W+H; layer = <CALayer: 0x6000026385e0>>
        //   |    | <UIDropShadowView: 0x130906020; frame = (0 0; 250 250); autoresize = W+H; layer = <CALayer: 0x60000263a800>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGS2_GS1_GS2_VS_4TextVS_14_PaddingLayout__GVS_24_BackgroundStyleModifierVS_5Color__GVS_30_EnvironmentKeyWritingModifierGSqVS_4Font_____: 0x14781e800; frame = (0 0; 250 250); autoresize = W+H; gestureRecognizers = <NSArray: 0x6000028603c0>; backgroundColor = <UIDynamicSystemColor: 0x600003350600; name = systemBackgroundColor>; layer = <CALayer: 0x60000264ca80>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x130809d20; frame = (48.6667 122.667; 152.667 64); anchorPoint = (0, 0); autoresizesSubviews = NO; backgroundColor = UIExtendedSRGBColorSpace 0.203922 0.780392 0.34902 1; layer = <CALayer: 0x600002682b80>>
        //   |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x141204280; frame = (68.6667 142.667; 112.667 24); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x600000228000>>
    }

    private func assertSwiftUITextRegions(regions: [SentryRedactRegion]) throws {
        let region = try XCTUnwrap(regions.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.type, .redact)
        XCTAssertCGSizeEqual(region.size, CGSize(width: 112.666, height: 24), accuracy: 0.01)
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 68.666, ty: 142.666),
            accuracy: 0.01
        )

        let region2 = try XCTUnwrap(regions.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.type, .clipOut)
        XCTAssertCGSizeEqual(region.size, CGSize(width: 112.666, height: 24), accuracy: 0.01)
        XCTAssertAffineTransformEqual(
            region2.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 48.666, ty: 122.666),
            accuracy: 0.01
        )

        // Assert that there are no other regions
        XCTAssertEqual(regions.count, 2)
    }

    func testRedact_withSwiftUIText_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUITextFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUITextRegions(regions: result)
    }

    func testRedact_withSwiftUIText_withMaskAllTextDisabled_shouldNotRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUITextFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)

        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.type, .clipOut)
        XCTAssertCGSizeEqual(region.size, CGSize(width: 152.666, height: 64), accuracy: 0.01)
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 48.666, ty: 122.666),
            accuracy: 0.01
        )

        // Assert no other regions
        XCTAssertEqual(result.count, 1)
    }

    func testRedact_withSwiftUIText_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUITextFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUITextRegions(regions: result)
    }

    // MARK: - SwiftUI.Label Redaction

    private func setupSwiftUILabelFixture() -> UIWindow {
        let view = VStack {
            Label("Hello SwiftUI", systemImage: "house")
                .labelStyle(.titleAndIcon)
        }
        return hostSwiftUIViewInWindow(view, frame: CGRect(x: 0, y: 0, width: 300, height: 300))

        // View Hierarchy:
        // ---------------
        // == iOS 26 ==
        // <UIWindow: 0x1078553c0; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x600000ce8270>; layer = <UIWindowLayer: 0x600001752d80>>
        //   | <UITransitionView: 0x103714e20; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000c74a20>>
        //   |    | <UIDropShadowView: 0x103716060; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000c74c60>>
        //        |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGVS_5LabelVS_4TextVS_5Image_GVS_P10$1d976f51025LabelStyleWritingModifierVS_22TitleAndIconLabelStyle____: 0x107853850; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x6000000219a0>; backgroundColor = <UIDynamicSystemColor: 0x60000174d480; name = systemBackgroundColor>; layer = <CALayer: 0x600000ce1d10>>
        //   |    |    |    | <SwiftUI.ImageLayer: 0x600000c23cf0> (layer)
        //   |    |    |    | <_TtC7SwiftUIP33_863CCF9D49B535DAEB1C7D61BEE53B5914CGDrawingLayer: 0x600002c26680> (layer)
        //
        // == iOS 18 ==
        // <UIWindow: 0x104941fa0; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x60000026ef60>; layer = <UIWindowLayer: 0x600000d98f60>>
        //   | <UITransitionView: 0x104857a40; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x60000026f9e0>>
        //   |    | <UIDropShadowView: 0x104858b30; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x60000027bc60>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGVS_5LabelVS_4TextVS_5Image_GVS_P10$1d433610c25LabelStyleWritingModifierVS_22TitleAndIconLabelStyle____: 0x1049414e0; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x60000000d9c0>; backgroundColor = <UIDynamicSystemColor: 0x6000017b1bc0; name = systemBackgroundColor>; layer = <SwiftUI.UIHostingViewDebugLayer: 0x6000002812e0>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x104b3edb0; frame = (4.33333 42.3333; 20 17.6667); anchorPoint = (0, 0); autoresizesSubviews = NO; layer = <SwiftUI.ImageLayer: 0x6000002bcaa0>>
        //   |    |    |    | <SwiftUI.CGDrawingView: 0x104b3f130; frame = (34.3333 41; 83.3333 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtC7SwiftUIP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x60000264c3c0>>
        //
        // == iOS 17 & 16 ==
        // <UIWindow: 0x14073c7e0; frame = (0 0; 300 300); gestureRecognizers = <NSArray: 0x6000003c7cf0>; layer = <UIWindowLayer: 0x6000003c7e10>>
        //   | <UITransitionView: 0x140645ae0; frame = (0 0; 300 300); autoresize = W+H; layer = <CALayer: 0x600000cc5540>>
        //   |    | <UIDropShadowView: 0x1406464d0; frame = (0 0; 300 300); autoresize = W+H; layer = <CALayer: 0x600000cc7b60>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGVS_5LabelVS_4TextVS_5Image_GVS_P10$11e37ba8025LabelStyleWritingModifierVS_22TitleAndIconLabelStyle____: 0x130524b10; frame = (0 0; 300 300); autoresize = W+H; gestureRecognizers = <NSArray: 0x6000003c7840>; backgroundColor = <UIDynamicSystemColor: 0x6000019073c0; name = systemBackgroundColor>; layer = <CALayer: 0x600000cce560>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x14071bb00; frame = (87 170.333; 20 17.6667); anchorPoint = (0, 0); autoresizesSubviews = NO; layer = <SwiftUI.ImageLayer: 0x600000c389a0>>
        //   |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x14073f040; frame = (117 169.333; 98 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x6000028e1020>>
    }

    private func assertSwiftUILabelRegions(regions: [SentryRedactRegion], expectText: Bool, expectImage: Bool) throws {
        func assertTextRegion(region: SentryRedactRegion) {
            XCTAssertNil(region.color)
            XCTAssertEqual(region.type, .redact)
            XCTAssertCGSizeEqual(region.size, CGSize(width: 98, height: 20.333), accuracy: 0.01)
            XCTAssertAffineTransformEqual(
                region.transform,
                CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 117, ty: 169.333),
                accuracy: 0.01
            )
        }

        func assertImageRegion(region: SentryRedactRegion) {
            XCTAssertNil(region.color)
            XCTAssertEqual(region.type, .redact)
            XCTAssertCGSizeEqual(region.size, CGSize(width: 20, height: 17.666), accuracy: 0.01)
            XCTAssertAffineTransformEqual(
                region.transform,
                CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 87, ty: 170.333),
                accuracy: 0.01
            )
        }

        if expectText && expectImage {
            assertTextRegion(region: try XCTUnwrap(regions.element(at: 0)))
            assertImageRegion(region: try XCTUnwrap(regions.element(at: 1)))

            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 2)
        } else if expectText {
            assertTextRegion(region: try XCTUnwrap(regions.element(at: 0)))

            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 1)
        } else if expectImage {
            assertImageRegion(region: try XCTUnwrap(regions.element(at: 0)))

            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 1)
        } else {
            // Assert that there are no other regions
            XCTAssertEqual(regions.count, 0)
        }
    }

    @available(iOS 14.5, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextEnabled_withMaskAllImagesEnabled_shouldRedactTextAndImage() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUILabelRegions(regions: result, expectText: true, expectImage: true)
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextEnabled_withMaskAllImagesDisabled_shouldRedactText() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUILabelRegions(regions: result, expectText: true, expectImage: false)
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextDisabled_withMaskAllImagesEnabled_shouldRedactImage() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUILabelRegions(regions: result, expectText: false, expectImage: true)
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextDisabled_withMaskAllImagesDisabled_shouldRedactText() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUILabelRegions(regions: result, expectText: false, expectImage: false)
    }

    // MARK: - SwiftUI.List Redaction

    private func setupSwiftUIListFixture() -> UIWindow {
        let view = VStack {
            List {
                Section("Section 1") {
                    Text("Item 1")
                }
                Section {
                    Text("Item 2")
                }
            }
        }
        return hostSwiftUIViewInWindow(view, frame: CGRect(x: 0, y: 0, width: 300, height: 500))

        // View Hierarchy:
        // ---------------
        // === 16 ===
        // <UIWindow: 0x13f61bdd0; frame = (0 0; 300 500); gestureRecognizers = <NSArray: 0x600003e63900>; layer = <UIWindowLayer: 0x600003e63570>>
        //   | <UITransitionView: 0x13f61c330; frame = (0 0; 300 500); autoresize = W+H; layer = <CALayer: 0x6000031402c0>>
        //   |    | <UIDropShadowView: 0x13f61aa60; frame = (0 0; 300 500); autoresize = W+H; layer = <CALayer: 0x600003141140>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_4ListOs5NeverGVS_9TupleViewTGVS_7SectionVS_4TextS6_VS_9EmptyView_GS5_S7_S6_S7_______: 0x12f811200; frame = (0 0; 300 500); autoresize = W+H; gestureRecognizers = <NSArray: 0x600003e631b0>; backgroundColor = <UIDynamicSystemColor: 0x600002484bc0; name = systemBackgroundColor>; layer = <CALayer: 0x600003151800>>
        //   |    |    |    | <_TtGC7SwiftUI16PlatformViewHostGVS_P10$111818dc817ListRepresentableGVS_28CollectionViewListDataSourceOs5Never_GOS_19SelectionManagerBoxS3____: 0x12f514910; baseClass = _UIConstraintBasedLayoutHostingView; frame = (0 0; 300 500); anchorPoint = (0, 0); tintColor = UIExtendedSRGBColorSpace 0 0.478431 1 1; layer = <CALayer: 0x6000031ad620>>
        //   |    |    |    |    | <SwiftUI.UpdateCoalescingCollectionView: 0x15f836400; baseClass = UICollectionView; frame = (0 0; 300 500); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600003e7b300>; backgroundColor = <UIDynamicSystemColor: 0x6000024f1800; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x6000031ac6c0>; contentOffset: {0, -59}; contentSize: {300, 182}; adjustedContentInset: {59, 0, 0, 0}; layout: <UICollectionViewCompositionalLayout: 0x15f54a2a0>; dataSource: <_TtGC7SwiftUI31UICollectionViewListCoordinatorGVS_28CollectionViewListDataSourceOs5Never_GOS_19SelectionManagerBoxS2___: 0x15f549e70>>
        //   |    |    |    |    |    | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x12f514bc0; frame = (-16 -1000; 332 1100.33); userInteractionEnabled = NO; backgroundColor = <UIDynamicSystemColor: 0x6000024f1800; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x6000031ad740>>
        //   |    |    |    |    |    | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x12f512940; frame = (-16 100.333; 332 1081.67); userInteractionEnabled = NO; backgroundColor = <UIDynamicSystemColor: 0x6000024f1800; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x6000031ad780>>
        //   |    |    |    |    |    | <SwiftUI.ListCollectionViewCell: 0x14f895000; baseClass = UICollectionViewListCell; frame = (16 38.6667; 268 44); clipsToBounds = YES; layer = <CALayer: 0x6000031a8480>>
        //   |    |    |    |    |    |    | <_UISystemBackgroundView: 0x14f5544e0; frame = (0 0; 268 44); layer = <CALayer: 0x6000031a87c0>; configuration = <UIBackgroundConfiguration: 0x600000431d40; Base Style = List Grouped Cell; backgroundColor = <UIDynamicSystemColor: 0x6000024f2080; name = tableCellGroupedBackgroundColor>>>
        //   |    |    |    |    |    |    |    | <UIView: 0x14f5548b0; frame = (0 0; 268 44); backgroundColor = <UIDynamicSystemColor: 0x6000024f2080; name = tableCellGroupedBackgroundColor>; layer = <CALayer: 0x6000031a87e0>>
        //   |    |    |    |    |    |    | <_UICollectionViewListCellContentView: 0x14f553b80; frame = (0 0; 268 44); gestureRecognizers = <NSArray: 0x600003e46850>; layer = <CALayer: 0x6000031a8520>>
        //   |    |    |    |    |    |    |    | <_TtGC7SwiftUI15CellHostingViewGVS_15ModifiedContentVS_14_ViewList_ViewVS_26CollectionViewCellModifier__: 0x13f81a800; frame = (0 0; 268 44); autoresize = W+H; gestureRecognizers = <NSArray: 0x600003e46c70>; layer = <CALayer: 0x6000031a8ea0>>
        //   |    |    |    |    |    |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x13a9053c0; frame = (16 12; 45.3333 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x600001500540>>
        //   |    |    |    |    |    | <SwiftUI.ListCollectionViewCell: 0x14801b800; baseClass = UICollectionViewListCell; frame = (16 118; 268 44); clipsToBounds = YES; layer = <CALayer: 0x600003194e40>>
        //   |    |    |    |    |    |    | <_UISystemBackgroundView: 0x13f624100; frame = (0 0; 268 44); layer = <CALayer: 0x600003194ea0>; configuration = <UIBackgroundConfiguration: 0x6000004389c0; Base Style = List Grouped Cell; backgroundColor = <UIDynamicSystemColor: 0x6000024f2080; name = tableCellGroupedBackgroundColor>>>
        //   |    |    |    |    |    |    |    | <UIView: 0x13f6242d0; frame = (0 0; 268 44); backgroundColor = <UIDynamicSystemColor: 0x6000024f2080; name = tableCellGroupedBackgroundColor>; layer = <CALayer: 0x600003194ec0>>
        //   |    |    |    |    |    |    | <_UICollectionViewListCellContentView: 0x13f623da0; frame = (0 0; 268 44); gestureRecognizers = <NSArray: 0x600003e420d0>; layer = <CALayer: 0x600003194e60>>
        //   |    |    |    |    |    |    |    | <_TtGC7SwiftUI15CellHostingViewGVS_15ModifiedContentVS_14_ViewList_ViewVS_26CollectionViewCellModifier__: 0x14802f600; frame = (0 0; 268 44); autoresize = W+H; gestureRecognizers = <NSArray: 0x600003e42250>; layer = <CALayer: 0x6000031950e0>>
        //   |    |    |    |    |    |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x13a904cf0; frame = (16 12; 47.6667 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x6000015000c0>>
        //   |    |    |    |    |    | <SwiftUI.ListCollectionViewCell: 0x14801c000; baseClass = UICollectionViewListCell; frame = (16 0; 268 38.6667); layer = <CALayer: 0x600003194fa0>>
        //   |    |    |    |    |    |    | <_UISystemBackgroundView: 0x13f6274d0; frame = (0 0; 268 38.6667); layer = <CALayer: 0x600003195280>; configuration = <UIBackgroundConfiguration: 0x600000438fc0; Base Style = List Grouped Header/Footer; cornerRadius = 10>>
        //   |    |    |    |    |    |    | <_UICollectionViewListCellContentView: 0x13f626f00; frame = (0 0; 268 38.6667); gestureRecognizers = <NSArray: 0x600003e425b0>; layer = <CALayer: 0x6000031951c0>>
        //   |    |    |    |    |    |    |    | <_TtGC7SwiftUI15CellHostingViewGVS_15ModifiedContentVS_14_ViewList_ViewVS_26CollectionViewCellModifier__: 0x148026000; frame = (0 0; 268 38.6667); autoresize = W+H; gestureRecognizers = <NSArray: 0x600003e427c0>; layer = <CALayer: 0x600003195820>>
        //   |    |    |    |    |    |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x13f521ef0; frame = (16 17; 65.6667 15.6667); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x60000150d020>>
        //   |    |    |    |    |    | <_UIScrollViewScrollIndicator: 0x14f525ce0; frame = (294 431; 3 7); alpha = 0; autoresize = LM; layer = <CALayer: 0x6000031a21c0>>
        //   |    |    |    |    |    |    | <UIView: 0x14f516da0; frame = (0 0; 3 7); backgroundColor = UIExtendedGrayColorSpace 0 0.35; layer = <CALayer: 0x6000031a21e0>>
        //   |    |    |    |    |    | <_UIScrollViewScrollIndicator: 0x14f551a80; frame = (290 435; 7 3); alpha = 0; autoresize = TM; layer = <CALayer: 0x6000031a2180>>
        //   |    |    |    |    |    |    | <UIView: 0x14f547ee0; frame = (0 0; 7 3); backgroundColor = UIExtendedGrayColorSpace 0 0.35; layer = <CALayer: 0x6000031a21a0>>
    }

    private func assertSwiftUIListRegions(regions: [SentryRedactRegion], expectText: Bool) throws {
        var offset = 0

        let region0 = try XCTUnwrap(regions.element(at: offset + 0)) // clipBegin for main collection view
        XCTAssertNil(region0.color)
        XCTAssertCGSizeEqual(region0.size, CGSize(width: 300, height: 500), accuracy: 0.01)
        XCTAssertEqual(region0.type, .clipBegin)
        XCTAssertAffineTransformEqual(
            region0.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
            accuracy: 0.01
        )

        if expectText {
            let region1 = try XCTUnwrap(regions.element(at: offset + 1)) // redact for first cell's text
            XCTAssertNil(region1.color)
            XCTAssertCGSizeEqual(region1.size, CGSize(width: 65.6667, height: 15.6667), accuracy: 0.01)
            XCTAssertEqual(region1.type, .redact)
            XCTAssertAffineTransformEqual(
                region1.transform,
                CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 32, ty: 76),
                accuracy: 0.01
            )
            offset += 1
        }

        let region2 = try XCTUnwrap(regions.element(at: offset + 1)) // clipBegin for second cell
        XCTAssertNil(region2.color)
        XCTAssertCGSizeEqual(region2.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region2.type, .clipBegin)
        XCTAssertAffineTransformEqual(
            region2.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 177),
            accuracy: 0.01
        )

        if expectText {
            let region3 = try XCTUnwrap(regions.element(at: offset + 2)) // redact for second cell's text
            XCTAssertNil(region3.color)
            XCTAssertCGSizeEqual(region3.size, CGSize(width: 47.6667, height: 20.3333), accuracy: 0.01)
            XCTAssertEqual(region3.type, .redact)
            XCTAssertAffineTransformEqual(
                region3.transform,
                CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 32, ty: 189),
                accuracy: 0.01
            )
            offset += 1
        }

        let region4 = try XCTUnwrap(regions.element(at: offset + 2)) // clipOut for second cell
        XCTAssertNil(region4.color)
        XCTAssertCGSizeEqual(region4.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region4.type, .clipOut)
        XCTAssertAffineTransformEqual(
            region4.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 177),
            accuracy: 0.01
        )

        let region5 = try XCTUnwrap(regions.element(at: offset + 3)) // clipEnd for second cell
        XCTAssertNil(region5.color)
        XCTAssertCGSizeEqual(region5.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region5.type, .clipEnd)
        XCTAssertAffineTransformEqual(
            region5.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 177),
            accuracy: 0.01
        )

        let region6 = try XCTUnwrap(regions.element(at: offset + 4)) // clipBegin for first cell
        XCTAssertNil(region6.color)
        XCTAssertCGSizeEqual(region6.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region6.type, .clipBegin)
        XCTAssertAffineTransformEqual(
            region6.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 97.6667),
            accuracy: 0.01
        )

        if expectText {
            let region7 = try XCTUnwrap(regions.element(at: offset + 5)) // redact for first cell's text
            XCTAssertNil(region7.color)
            XCTAssertCGSizeEqual(region7.size, CGSize(width: 45.3333, height: 20.3333), accuracy: 0.01)
            XCTAssertEqual(region7.type, .redact)
            XCTAssertAffineTransformEqual(
                region7.transform,
                CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 32, ty: 109.6667),
                accuracy: 0.01
            )
            offset += 1
        }

        let region8 = try XCTUnwrap(regions.element(at: offset + 5)) // clipOut for first cell
        XCTAssertNil(region8.color)
        XCTAssertCGSizeEqual(region8.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region8.type, .clipOut)
        XCTAssertAffineTransformEqual(
            region8.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 97.6667),
            accuracy: 0.01
        )

        let region9 = try XCTUnwrap(regions.element(at: offset + 6)) // clipEnd for first cell
        XCTAssertNil(region9.color)
        XCTAssertCGSizeEqual(region9.size, CGSize(width: 268, height: 44), accuracy: 0.01)
        XCTAssertEqual(region9.type, .clipEnd)
        XCTAssertAffineTransformEqual(
            region9.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 16, ty: 97.6667),
            accuracy: 0.01
        )

        let region10 = try XCTUnwrap(regions.element(at: offset + 7)) // redact for section background (bottom)
        XCTAssertNil(region10.color)
        XCTAssertCGSizeEqual(region10.size, CGSize(width: 332, height: 1081.6667), accuracy: 0.01)
        XCTAssertEqual(region10.type, .redact)
        XCTAssertAffineTransformEqual(
            region10.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: -16, ty: 159.3333),
            accuracy: 0.01
        )

        let region11 = try XCTUnwrap(regions.element(at: offset + 8)) // redact for section background (top)
        XCTAssertNil(region11.color)
        XCTAssertCGSizeEqual(region11.size, CGSize(width: 332, height: 1100.3333), accuracy: 0.01)
        XCTAssertEqual(region11.type, .redact)
        XCTAssertAffineTransformEqual(
            region11.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: -16, ty: -941),
            accuracy: 0.01
        )

        let region12 = try XCTUnwrap(regions.element(at: offset + 9)) // clipEnd for main collection view
        XCTAssertNil(region12.color)
        XCTAssertCGSizeEqual(region12.size, CGSize(width: 300, height: 500), accuracy: 0.01)
        XCTAssertEqual(region12.type, .clipEnd)
        XCTAssertAffineTransformEqual(
            region12.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
            accuracy: 0.01
        )

        // Assert that there are no other regions
        XCTAssertEqual(regions.count, offset + 10)
    }

    func testRedact_withSwiftUIList_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIListFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIListRegions(regions: result, expectText: true)
    }

    func testRedact_withSwiftUIList_withMaskAllTextDisabled_withMaskAllImagesEnabled_shouldNotRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIListFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIListRegions(regions: result, expectText: false)
    }

    func testRedact_withSwiftUIList_withMaskAllTextEnabled_withMaskAllImagesDisabled_shouldNotRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIListFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIListRegions(regions: result, expectText: false)
    }

    func testRedact_withSwiftUIList_withMaskAllTextDisabled_withMaskAllImagesDisabled_shouldNotRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIListFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: window, as: .image)
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIListRegions(regions: result, expectText: false)
    }

    // MARK: Ignore background view

    func testCollectionViewListBackgroundDecorationView_isIgnoredSubtree_redactsAndDoesNotClipOut() throws {
        // -- Arrange --
        // The SwiftUI List uses an internal decoration view
        // `_UICollectionViewListLayoutSectionBackgroundColorDecorationView` which may have
        // an extremely large frame. We ensure our builder treats this as a special case and
        // redacts it directly instead of producing clip regions that could hide other masks.
        guard let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero) else {
            throw XCTSkip("UICollectionView background decoration view is not available")
        }

        // Configure a very large frame similar to what we see in production
        decorationView.frame = CGRect(x: -20, y: -1_100, width: 440, height: 2_300)
        decorationView.backgroundColor = .systemGroupedBackground

        // Add another redacted view that must remain redacted (no clip-out should hide it)
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 60, width: 120, height: 40))
        titleLabel.text = "Sample Text"

        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        rootView.addSubview(decorationView)
        rootView.addSubview(titleLabel)

        // View Hierarchy:
        // ---------------
        // <UIView: 0x119030c20; frame = (0 0; 402 874); layer = <CALayer: 0x6000012c02a0>>
        //   | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x119044de0; frame = (-20 -1100; 440 2300); backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x6000012c0450>>
        //   | <UILabel: 0x11905f7c0; frame = (16 60; 120 40); text = 'Sample Text'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c2cf00>>

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)

        // We should have at least two redact regions (label + decoration view)
        XCTAssertGreaterThanOrEqual(result.count, 2)
        // There must be no clipOut regions produced by the decoration view special-case
        XCTAssertFalse(result.contains(where: { $0.type == .clipOut }), "No clipOut regions expected for decoration background view")
        // Ensure we have at least one redact region that matches the large decoration view size
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == decorationView.bounds.size }))
    }

    // - MARK: - SwiftUI.Image Redaction

    private func setupSwiftUIImageFixture() -> UIWindow {
        let view = VStack {
            Image(systemName: "star.fill")
        }
        return hostSwiftUIViewInWindow(view, frame: CGRect(x: 20, y: 20, width: 240, height: 320))

        // View Hierarchy:
        // ---------------
        // == iOS 26 ==
        // <UIWindow: 0x10731f640; frame = (0 0; 0 0); gestureRecognizers = <NSArray: 0x600000ce1260>; layer = <UIWindowLayer: 0x600001746b40>>
        //   | <UITransitionView: 0x107626220; frame = (0 0; 0 0); autoresize = W+H; layer = <CALayer: 0x600000ce1d10>>
        //   |    | <UIDropShadowView: 0x107626d20; frame = (0 0; 0 0); autoresize = W+H; layer = <CALayer: 0x600000ce2550>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackVS_5Image__: 0x107623670; frame = (0 0; 0 0); autoresize = W+H; gestureRecognizers = <NSArray: 0x600000014a80>; backgroundColor = <UIDynamicSystemColor: 0x60000170e4c0; name = systemBackgroundColor>; layer = <CALayer: 0x600000ce83f0>>
        //   |    |    |    | <SwiftUI.ImageLayer: 0x600000cec390> (layer)
        //
        // == iOS 18 & 17 & 16 ==
        // <UIWindow: 0x12dd45860; frame = (20 20; 240 320); gestureRecognizers = <NSArray: 0x6000029a4c90>; layer = <UIWindowLayer: 0x6000029a4930>>
        //   | <UITransitionView: 0x13dd2f3d0; frame = (0 0; 240 320); autoresize = W+H; layer = <CALayer: 0x600002658a40>>
        //   |    | <UIDropShadowView: 0x13dd30920; frame = (0 0; 240 320); autoresize = W+H; layer = <CALayer: 0x6000026590a0>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackVS_5Image__: 0x13dd2fe30; frame = (0 0; 240 320); autoresize = W+H; gestureRecognizers = <NSArray: 0x6000029a4060>; backgroundColor = <UIDynamicSystemColor: 0x60000336c600; name = systemBackgroundColor>; layer = <CALayer: 0x6000026a4c00>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x13de22060; frame = (110.667 170.667; 18.6667 18); anchorPoint = (0, 0); autoresizesSubviews = NO; layer = <SwiftUI.ImageLayer: 0x60000265e2a0>>
    }

    private func assertSwiftUIImageRegions(regions: [SentryRedactRegion]) throws {
        let region = try XCTUnwrap(regions.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertCGSizeEqual(region.size, CGSize(width: 18.666, height: 18), accuracy: 0.01)
        XCTAssertEqual(region.type, .redact)
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 130.666, ty: 190.666),
            accuracy: 0.01
        )

        // Assert that there are no other regions
        XCTAssertEqual(regions.count, 1)
    }

    func testRedact_withSwiftUIImage_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIImageFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIImageRegions(regions: result)
    }

    func testRedact_withSwiftUIImage_withMaskAllImagesDisabled_shouldNotRedactView() {
        // -- Arrange --
        let window = setupSwiftUIImageFixture()

        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }

    func testRedact_withSwiftUIImage_withMaskAllTextDisabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIImageFixture()

        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)

        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        try assertSwiftUIImageRegions(regions: result)
    }

    // MARK: - Helper Methods

    /// Creates an instance of ``UIKit._UICollectionViewListLayoutSectionBackgroundColorDecorationView``
    ///
    /// - Parameter frame: The frame to set for the created view
    /// - Returns: The created view or `nil` if the type is absent
    private func createCollectionViewListBackgroundDecorationView(frame: CGRect) throws -> UIView? {
        return try createFakeView(
            type: UIView.self,
            name: "_UICollectionViewListLayoutSectionBackgroundColorDecorationView",
            frame: frame
        )
    }
}

#endif // os(iOS)
