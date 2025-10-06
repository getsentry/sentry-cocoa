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
        // <UIWindow: 0x13291c150; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x600000daecd0>; layer = <UIWindowLayer: 0x600000dad260>>
        //   | <UITransitionView: 0x13291f9e0; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000282300>>
        //   |    | <UIDropShadowView: 0x1329204d0; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000282d60>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGS1_GS2_VS_4TextVS_14_PaddingLayout__GVS_24_BackgroundStyleModifierVS_5Color____: 0x10701de00; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x600000dad890>; backgroundColor = <UIDynamicSystemColor: 0x6000017c9a40; name = systemBackgroundColor>; layer = <SwiftUI.UIHostingViewDebugLayer: 0x60000027bb40>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x132916fe0; frame = (0 0; 120 79.6667); anchorPoint = (0, 0); autoresizesSubviews = NO; backgroundColor = UIExtendedSRGBColorSpace 0.203922 0.780392 0.34902 1; layer = <CALayer: 0x6000002a2ec0>>
        //   |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x1024274c0; frame = (20.3333 39.3333; 79.6667 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x600002640060>>
    }
    
    func testRedact_withSwiftUIText_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUITextFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.size.width, 152)
        XCTAssertEqual(region.size.height, 64)
        XCTAssertAffineTransformEqual(
            region.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 22, ty: 47.66666),
            accuracy: 0.1
        )
        
        let region2 = try XCTUnwrap(result.element(at: 1))
        XCTAssertNil(region2.color)
        XCTAssertEqual(region2.type, .redact)
        XCTAssertEqual(region2.size.width, 152)
        XCTAssertEqual(region2.size.height, 64)
        XCTAssertAffineTransformEqual(
            region2.transform,
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 22, ty: 47.66666),
            accuracy: 0.1
        )
        
        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }
    
    func testRedact_withSwiftUIText_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let window = setupSwiftUITextFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedact_withSwiftUIText_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let window = setupSwiftUITextFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
    }
    
    // MARK: - SwiftUI.Label Redaction
    
    private func setupSwiftUILabelFixture() -> UIWindow {
        let view = VStack {
            Label("Hello SwiftUI", systemImage: "house")
                .labelStyle(.titleAndIcon)
        }
        return hostSwiftUIViewInWindow(view, frame: CGRect(x: 20, y: 20, width: 120, height: 60))
        
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
        // <UIWindow: 0x105016ea0; frame = (20 20; 120 60); gestureRecognizers = <NSArray: 0x600000db46c0>; layer = <UIWindowLayer: 0x600000db42a0>>
        //   | <UITransitionView: 0x105019360; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000282b40>>
        //   |    | <UIDropShadowView: 0x105019c50; frame = (0 0; 120 60); autoresize = W+H; layer = <CALayer: 0x600000283520>>
        //   |    |    | <_TtGC7SwiftUI14_UIHostingViewGVS_6VStackGVS_15ModifiedContentGVS_5LabelVS_4TextVS_5Image_GVS_P10$1cd944ccc25LabelStyleWritingModifierVS_22TitleAndIconLabelStyle____: 0x128829000; frame = (0 0; 120 60); autoresize = W+H; gestureRecognizers = <NSArray: 0x600000db37e0>; backgroundColor = <UIDynamicSystemColor: 0x6000017c4e40; name = systemBackgroundColor>; layer = <SwiftUI.UIHostingViewDebugLayer: 0x6000002792e0>>
        //   |    |    |    | <SwiftUI._UIGraphicsView: 0x105117c90; frame = (4.33333 40.3333; 20 17.6667); anchorPoint = (0, 0); autoresizesSubviews = NO; layer = <SwiftUI.ImageLayer: 0x600000255ac0>>
        //   |    |    |    | <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView: 0x105118520; frame = (34.3333 39.3333; 83.3333 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtCOCV7SwiftUI11DisplayList11ViewUpdater8PlatformP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x60000261f840>>
    }
    
    @available(iOS 14.5, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        
        // Assert that there are no other regions
        XCTAssertEqual(result.count, 2)
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllTextDisabled_shouldNotRedactView() {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func testRedact_withSwiftUILabel_withMaskAllImagesDisabled_shouldRedactView() {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: false)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
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
    }
    
    func testRedact_withSwiftUIList_withMaskAllTextEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color)
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        
        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
    }
    
    func testRedact_withSwiftUIList_withMaskAllTextDisabled_shouldNotRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 0)
    }
    
    func testRedact_withSwiftUIList_withMaskAllImagesDisabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUILabelFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
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
    
    func testRedact_withSwiftUIImage_withMaskAllImagesEnabled_shouldRedactView() throws {
        // -- Arrange --
        let window = setupSwiftUIImageFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        
        let region = try XCTUnwrap(result.element(at: 0))
        XCTAssertNil(region.color) // The text color of UITextView is not used for redaction
        XCTAssertEqual(region.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(region.type, .redact)
        XCTAssertEqual(region.transform, CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20))
        
        // Assert that there are no other regions
        XCTAssertEqual(result.count, 1)
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
    
    func testRedact_withSwiftUIImage_withMaskAllTextDisabled_shouldRedactView() {
        // -- Arrange --
        let window = setupSwiftUIImageFixture()
        
        // -- Act --
        let sut = getSut(maskAllText: false, maskAllImages: true)
        let result = sut.redactRegionsFor(view: window)
        let masked = createMaskedScreenshot(view: window, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTAssertEqual(result.count, 1)
    }
    
    // MARK: - Ignore SwiftUI.List background view
    
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
    
    func testSwiftUIListDecorationBackground_doesNotUnmaskNavigationBarContent_elaborateHierarchy() throws {
        // -- Arrange --
        // Build a simplified but elaborate hierarchy inspired by the attached recursiveDescription.
        // The key actors are:
        // - A navigation bar label near the top that should be redacted
        // - A SwiftUI List area with a very large `_UICollectionViewListLayoutSectionBackgroundColorDecorationView`
        //   that extends well beyond the list bounds
        // This test captures the expected behavior (label remains redacted, no clipOut overshadowing),
        // but is marked as an expected failure to document the current bug.
        
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        
        // Navigation bar container and title label
        let navBar = UIView(frame: CGRect(x: 0, y: 56, width: 402, height: 96))
        navBar.backgroundColor = .clear
        let titleLabel = UILabel(frame: CGRect(x: 16, y: 8, width: 120, height: 40))
        titleLabel.text = "Flinky"
        navBar.addSubview(titleLabel)
        rootView.addSubview(navBar)
        
        // List container (mimics SwiftUI.UpdateCoalescingCollectionView)
        let listContainer = UIView(frame: CGRect(x: 0, y: 306, width: 402, height: 568))
        listContainer.clipsToBounds = true
        listContainer.backgroundColor = .systemGroupedBackground
        rootView.addSubview(listContainer)
        
        // Oversized decoration background view
        guard let decorationView = try createCollectionViewListBackgroundDecorationView(frame: .zero) else {
            throw XCTSkip("UICollectionView background decoration view is not available")
        }
        
        // Large frame similar to the debug output (-1135, 2336)
        decorationView.frame = CGRect(x: -20, y: -1_135.33, width: 442, height: 2_336)
        decorationView.backgroundColor = .systemGroupedBackground
        listContainer.addSubview(decorationView)
        
        // A representative list cell area (not strictly necessary for the bug but mirrors structure)
        let cell = UIView(frame: CGRect(x: 20, y: 0, width: 362, height: 45.33))
        cell.backgroundColor = .white
        listContainer.addSubview(cell)
        
        // View Hierarchy:
        // ---------------
        // <UIView: 0x11eb05d60; frame = (0 0; 402 874); layer = <CALayer: 0x600000ce7c30>>
        //   | <UIView: 0x11cb054f0; frame = (0 56; 402 96); backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <CALayer: 0x600000ce7b10>>
        //   |    | <UILabel: 0x11cb04ea0; frame = (16 8; 120 40); text = 'Flinky'; userInteractionEnabled = NO; backgroundColor = UIExtendedGrayColorSpace 0 0; layer = <_UILabelLayer: 0x600002c28d00>>
        //   | <UIView: 0x11cb047d0; frame = (0 306; 402 568); clipsToBounds = YES; backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x600000ce64c0>>
        //   |    | <_UICollectionViewListLayoutSectionBackgroundColorDecorationView: 0x11cb04aa0; frame = (-20 -1135.33; 442 2336); backgroundColor = <UIDynamicSystemColor: 0x600001746680; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x600000ce75d0>>
        //   |    | <UIView: 0x11cb059d0; frame = (20 0; 362 45.33); backgroundColor = UIExtendedGrayColorSpace 1 1; layer = <CALayer: 0x600000ce7e10>>
        
        // -- Act --
        let sut = getSut(maskAllText: true, maskAllImages: true)
        let result = sut.redactRegionsFor(view: rootView)
        let masked = createMaskedScreenshot(view: rootView, regions: result)
        
        // -- Assert --
        assertSnapshot(of: masked, as: .image)
        XCTExpectFailure("Decoration background may clear previous redactions due to oversized opaque frame covering root")
        
        // 1) Navigation title label should remain redacted (i.e., a redact region matching its size exists)
        XCTAssertTrue(result.contains(where: { $0.type == .redact && $0.size == titleLabel.bounds.size }),
                      "Navigation title label should remain redacted")
        
        // 2) No clipOut regions should be produced by the decoration background handling
        XCTAssertFalse(result.contains(where: { $0.type == .clipOut }),
                       "No clipOut regions expected; decoration view should not suppress unrelated masks")
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
