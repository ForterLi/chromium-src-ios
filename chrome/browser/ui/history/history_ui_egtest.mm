// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#include "base/ios/ios_util.h"
#include "base/strings/stringprintf.h"
#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#import "ios/chrome/browser/ui/history/history_ui_constants.h"
#import "ios/chrome/browser/ui/popup_menu/popup_menu_constants.h"
#import "ios/chrome/browser/ui/settings/cells/clear_browsing_data_constants.h"
#import "ios/chrome/browser/ui/table_view/feature_flags.h"
#import "ios/chrome/browser/ui/table_view/table_view_constants.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"
#include "ios/chrome/common/string_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "net/base/mac/url_conversions.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::HistoryEntry;
using chrome_test_util::NavigationBarDoneButton;
using chrome_test_util::OpenLinkInNewWindowButton;
using chrome_test_util::DeleteButton;
using chrome_test_util::WindowWithNumber;

namespace {
char kURL1[] = "/firstURL";
char kURL2[] = "/secondURL";
char kURL3[] = "/thirdURL";
char kTitle1[] = "Page 1";
char kTitle2[] = "Page 2";
char kResponse1[] = "Test Page 1 content";
char kResponse2[] = "Test Page 2 content";
char kResponse3[] = "Test Page 3 content";

// Matcher for the history button in the tools menu.
id<GREYMatcher> HistoryButton() {
  return grey_accessibilityID(kToolsMenuHistoryId);
}
// Matcher for the edit button in the navigation bar.
id<GREYMatcher> NavigationEditButton() {
  return grey_accessibilityID(kHistoryToolbarEditButtonIdentifier);
}
// Matcher for the delete button.
id<GREYMatcher> DeleteHistoryEntriesButton() {
  return grey_accessibilityID(kHistoryToolbarDeleteButtonIdentifier);
}
// Matcher for the search button.
id<GREYMatcher> SearchIconButton() {
    return grey_accessibilityID(kHistorySearchControllerSearchBarIdentifier);
}
// Matcher for the cancel button.
id<GREYMatcher> CancelButton() {
  return grey_accessibilityID(kHistoryToolbarCancelButtonIdentifier);
}
// Matcher for the empty TableView background
id<GREYMatcher> EmptyTableViewBackground() {
  return grey_accessibilityID(kTableViewEmptyViewID);
}
// Matcher for the empty TableView illustrated background
id<GREYMatcher> EmptyIllustratedTableViewBackground() {
  return grey_accessibilityID(kTableViewIllustratedEmptyViewID);
}

// Provides responses for URLs.
std::unique_ptr<net::test_server::HttpResponse> StandardResponse(
    const net::test_server::HttpRequest& request) {
  std::unique_ptr<net::test_server::BasicHttpResponse> http_response =
      std::make_unique<net::test_server::BasicHttpResponse>();
  http_response->set_code(net::HTTP_OK);

  const char kPageFormat[] = "<head><title>%s</title></head><body>%s</body>";
  if (request.relative_url == kURL1) {
    std::string page_html =
        base::StringPrintf(kPageFormat, kTitle1, kResponse1);
    http_response->set_content(page_html);
  } else if (request.relative_url == kURL2) {
    std::string page_html =
        base::StringPrintf(kPageFormat, kTitle2, kResponse2);
    http_response->set_content(page_html);
  } else if (request.relative_url == kURL3) {
    http_response->set_content(
        base::StringPrintf("<body>%s</body>", kResponse3));
  } else {
    return nullptr;
  }

  return std::move(http_response);
}

}  // namespace

// History UI tests.
@interface HistoryUITestCase : ChromeTestCase {
  GURL _URL1;
  GURL _URL2;
  GURL _URL3;
}

// Loads three test URLs.
- (void)loadTestURLs;
// Displays the history UI.
- (void)openHistoryPanel;

@end

@implementation HistoryUITestCase

- (void)setUp {
  [super setUp];
  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&StandardResponse));
  GREYAssertTrue(self.testServer->Start(), @"Server did not start.");

  _URL1 = self.testServer->GetURL(kURL1);
  _URL2 = self.testServer->GetURL(kURL2);
  _URL3 = self.testServer->GetURL(kURL3);

  [ChromeEarlGrey clearBrowsingHistory];
  // Some tests rely on a clean state for the "Clear Browsing Data" settings
  // screen.
  [ChromeEarlGrey resetBrowsingDataPrefs];
}

- (void)tearDown {
  // No-op if only one window presents.
  [ChromeEarlGrey closeAllExtraWindows];
  [EarlGrey setRootMatcherForSubsequentInteractions:nil];

  NSError* error = nil;
  // Dismiss search bar by pressing cancel, if present. Passing error prevents
  // failure if the element is not found.
  [[EarlGrey selectElementWithMatcher:CancelButton()] performAction:grey_tap()
                                                              error:&error];
  // Dismiss history panel by pressing done, if present. Passing error prevents
  // failure if the element is not found.
  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()
              error:&error];

  // Some tests change the default values for the "Clear Browsing Data" settings
  // screen.
  [ChromeEarlGrey resetBrowsingDataPrefs];
  [super tearDown];
}

#pragma mark Tests

// Tests that no history is shown if there has been no navigation.
- (void)testDisplayNoHistory {
  [self openHistoryPanel];
  [ChromeEarlGreyUI assertHistoryHasNoEntries];
}

// Tests that the history panel displays navigation history.
- (void)testDisplayHistory {
  [self loadTestURLs];
  [self openHistoryPanel];

  // Assert that history displays three entries.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Tap a history entry and assert that navigation to that entry's URL occurs.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_tap()];
  [ChromeEarlGrey waitForWebStateContainingText:kResponse1];
}

// Tests that history is not changed after performing back navigation.
- (void)testHistoryUpdateAfterBackNavigation {
  [ChromeEarlGrey loadURL:_URL1];
  [ChromeEarlGrey loadURL:_URL2];

  [[EarlGrey selectElementWithMatcher:chrome_test_util::BackButton()]
      performAction:grey_tap()];
  [ChromeEarlGrey waitForWebStateContainingText:kResponse1];

  [self openHistoryPanel];

  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
}

// Tests that searching history displays only entries matching the search term.
- (void)testSearchHistory {
  // TODO(crbug.com/753098): Re-enable this test on iPad once grey_typeText
  // works on iOS 11.
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_DISABLED(@"Test disabled on iPad.");
  }

  [self loadTestURLs];
  [self openHistoryPanel];
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

    // Verify that scrim is visible.
    [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                            kHistorySearchScrimIdentifier)]
        assertWithMatcher:grey_notNil()];

  NSString* searchString =
      [NSString stringWithFormat:@"%s", _URL1.path().c_str()];

  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(searchString)];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistorySearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];

  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_nil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_nil()];
}

// Tests that long press on scrim while search box is enabled dismisses the
// search controller.
- (void)testSearchLongPressOnScrimCancelsSearchController {
  [self loadTestURLs];
  [self openHistoryPanel];
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

  // Try long press.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  // Verify context menu is not visible.
  [[EarlGrey
      selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                   IDS_IOS_CONTENT_CONTEXT_OPENLINKNEWTAB)]
      assertWithMatcher:grey_nil()];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistorySearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];

  // Verifiy we went back to original folder content.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests deletion of history entries.
- (void)testDeleteHistory {
  [self loadTestURLs];
  [self openHistoryPanel];

  // Assert that three history elements are present.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Enter edit mode, select a history element, and press delete.
  [[EarlGrey selectElementWithMatcher:NavigationEditButton()]
      performAction:grey_tap()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:DeleteHistoryEntriesButton()]
      performAction:grey_tap()];

  // Assert that the deleted entry is gone and the other two remain.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_nil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Enter edit mode, select both remaining entries, and press delete.
  [[EarlGrey selectElementWithMatcher:NavigationEditButton()]
      performAction:grey_tap()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:DeleteHistoryEntriesButton()]
      performAction:grey_tap()];

  [ChromeEarlGreyUI assertHistoryHasNoEntries];
}

// Tests clear browsing history.
- (void)testClearBrowsingHistory {
  [self loadTestURLs];
  [self openHistoryPanel];

  [ChromeEarlGreyUI openAndClearBrowsingDataFromHistory];
  [ChromeEarlGreyUI assertHistoryHasNoEntries];
}

// Tests clear browsing history.
- (void)testClearBrowsingHistorySwipeDownDismiss {
  if (!base::ios::IsRunningOnOrLater(13, 0, 0)) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on iOS 12 and lower.");
  }
  if (!IsCollectionsCardPresentationStyleEnabled()) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on when feature flag is off.");
  }

  [self loadTestURLs];
  [self openHistoryPanel];

  // Open Clear Browsing Data
  [[EarlGrey selectElementWithMatcher:chrome_test_util::
                                          HistoryClearBrowsingDataButton()]
      performAction:grey_tap()];

  // Check that the TableView is presented.
  [[EarlGrey
      selectElementWithMatcher:
          grey_accessibilityID(kClearBrowsingDataViewAccessibilityIdentifier)]
      assertWithMatcher:grey_notNil()];

  // Swipe TableView down.
  [[EarlGrey
      selectElementWithMatcher:
          grey_accessibilityID(kClearBrowsingDataViewAccessibilityIdentifier)]
      performAction:grey_swipeFastInDirection(kGREYDirectionDown)];

  // Check that the TableView has been dismissed.
  [[EarlGrey
      selectElementWithMatcher:
          grey_accessibilityID(kClearBrowsingDataViewAccessibilityIdentifier)]
      assertWithMatcher:grey_nil()];
}

// Tests display and selection of 'Open in New Tab' in a context menu on a
// history entry.
- (void)testContextMenuOpenInNewTab {
  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  // Select "Open in New Tab" and confirm that new tab is opened with selected
  // URL.
  [ChromeEarlGrey verifyOpenInNewTabActionWithURL:_URL1.GetContent()];
}

// Tests display and selection of 'Open in New Window' in a context menu on a
// history entry.
- (void)testContextMenuOpenInNewWindow {
  if (![ChromeEarlGrey areMultipleWindowsSupported])
    EARL_GREY_TEST_DISABLED(@"Multiple windows can't be opened.");

  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  [ChromeEarlGrey verifyOpenInNewWindowActionWithContent:kResponse1];
}

// Tests display and selection of 'Open in New Incognito Tab' in a context menu
// on a history entry.
- (void)testContextMenuOpenInNewIncognitoTab {
  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  // Select "Open in New Incognito Tab" and confirm that new tab is opened in
  // incognito with the selected URL.
  [ChromeEarlGrey
      verifyOpenInIncognitoActionWithURL:_URL1.GetContent()
                            useNewString:[ChromeEarlGrey
                                             isNativeContextMenusEnabled]];
}

// Tests display and selection of 'Copy URL' in a context menu on a history
// entry.
- (void)testContextMenuCopy {
  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  // Tap "Copy URL" and wait for the URL to be copied to the pasteboard.
  [ChromeEarlGrey
      verifyCopyLinkActionWithText:[NSString stringWithUTF8String:_URL1.spec()
                                                                      .c_str()]
                      useNewString:[ChromeEarlGrey
                                       isNativeContextMenusEnabled]];
}

// Tests display and selection of "Share" in the context menu for a history
// entry.
- (void)testContextMenuShare {
  if (![ChromeEarlGrey isNativeContextMenusEnabled]) {
    EARL_GREY_TEST_SKIPPED(
        @"Test disabled when Native Context Menus feature flag is off.");
  }

  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  [ChromeEarlGrey
      verifyShareActionWithPageTitle:[NSString stringWithUTF8String:kTitle1]];
}

// Tests the Delete context menu action for a History entry.
- (void)testContextMenuDelete {
  if (![ChromeEarlGrey isNativeContextMenusEnabled]) {
    EARL_GREY_TEST_SKIPPED(
        @"Test disabled when Native Context Menus feature flag is off.");
  }

  [self loadTestURLs];
  [self openHistoryPanel];

  // Long press on the history element.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  [[EarlGrey selectElementWithMatcher:DeleteButton()] performAction:grey_tap()];

  // Assert that the deleted entry is gone and the other two remain.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_nil()];

  // Wait for the animations to be done, then validate.
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:HistoryEntry(
                                                       _URL2.GetOrigin().spec(),
                                                       kTitle2)];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];
}

// Tests that the VC can be dismissed by swiping down.
- (void)testSwipeDownDismiss {
  if (!base::ios::IsRunningOnOrLater(13, 0, 0)) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on iOS 12 and lower.");
  }
  if (!IsCollectionsCardPresentationStyleEnabled()) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on when feature flag is off.");
  }
  [self loadTestURLs];
  [self openHistoryPanel];

  // Check that the TableView is presented.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      assertWithMatcher:grey_notNil()];

  // Swipe TableView down.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      performAction:grey_swipeFastInDirection(kGREYDirectionDown)];

  // Check that the TableView has been dismissed.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      assertWithMatcher:grey_nil()];
}

// Tests that the VC can be dismissed by swiping down while its searching.
- (void)testSwipeDownDismissWhileSearching {
// TODO(crbug.com/1078165): Test fails on iOS 13+ iPad devices.
#if !TARGET_IPHONE_SIMULATOR
  if ([ChromeEarlGrey isIPadIdiom] && base::ios::IsRunningOnIOS13OrLater()) {
    EARL_GREY_TEST_DISABLED(@"This test fails on iOS 13+ iPad device.");
  }
#endif

  if (!base::ios::IsRunningOnOrLater(13, 0, 0)) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on iOS 12 and lower.");
  }
  if (!IsCollectionsCardPresentationStyleEnabled()) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on when feature flag is off.");
  }
  [self loadTestURLs];
  [self openHistoryPanel];

  // Check that the TableView is presented.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      assertWithMatcher:grey_notNil()];

  // Search for the first URL.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];
  NSString* searchString =
      [NSString stringWithFormat:@"%s", _URL1.path().c_str()];
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(searchString)];

  // Swipe TableView down.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      performAction:grey_swipeFastInDirection(kGREYDirectionDown)];

  // Check that the TableView has been dismissed.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kHistoryTableViewIdentifier)]
      assertWithMatcher:grey_nil()];
}

// Navigates to history and checks elements for accessibility.
- (void)testAccessibilityOnHistory {
  [self loadTestURLs];
  [self openHistoryPanel];
  [ChromeEarlGrey verifyAccessibilityForCurrentScreen];
  // Close history.
    id<GREYMatcher> exitMatcher =
        grey_accessibilityID(kHistoryNavigationControllerDoneButtonIdentifier);
    [[EarlGrey selectElementWithMatcher:exitMatcher] performAction:grey_tap()];
}

- (void)testEmptyState {
  [self loadTestURLs];
  [self openHistoryPanel];

  // The toolbar should contain the CBD and edit buttons.
  [[EarlGrey selectElementWithMatcher:chrome_test_util::
                                          HistoryClearBrowsingDataButton()]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:NavigationEditButton()]
      assertWithMatcher:grey_notNil()];

  [ChromeEarlGreyUI openAndClearBrowsingDataFromHistory];

  if ([ChromeEarlGrey isIllustratedEmptyStatesEnabled]) {
    // Toolbar should only contain CBD button and the background should contain
    // the Illustrated empty view
    [[EarlGrey selectElementWithMatcher:chrome_test_util::
                                            HistoryClearBrowsingDataButton()]
        assertWithMatcher:grey_notNil()];
    [[EarlGrey selectElementWithMatcher:NavigationEditButton()]
        assertWithMatcher:grey_nil()];
    [[EarlGrey selectElementWithMatcher:EmptyIllustratedTableViewBackground()]
        assertWithMatcher:grey_notNil()];
  } else {
    // The toolbar should still contain the CBD and Edit buttons and the
    // background should contain the empty view
    [[EarlGrey selectElementWithMatcher:chrome_test_util::
                                            HistoryClearBrowsingDataButton()]
        assertWithMatcher:grey_notNil()];
    [[EarlGrey selectElementWithMatcher:NavigationEditButton()]
        assertWithMatcher:grey_notNil()];
    [[EarlGrey selectElementWithMatcher:EmptyTableViewBackground()]
        assertWithMatcher:grey_notNil()];
  }
}

#pragma mark Multiwindow

- (void)testHistorySyncInMultiwindow {
  if (![ChromeEarlGrey areMultipleWindowsSupported])
    EARL_GREY_TEST_DISABLED(@"Multiple windows can't be opened.");

  // Create history in first window.
  [self loadTestURLs];

  // Open history panel in a second window
  [ChromeEarlGrey openNewWindow];
  [ChromeEarlGrey waitForForegroundWindowCount:2];

  [EarlGrey setRootMatcherForSubsequentInteractions:WindowWithNumber(1)];
  [self openHistoryPanel];

  // Assert that three history elements are present in second window.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Open history panel in first window also.
  [EarlGrey setRootMatcherForSubsequentInteractions:WindowWithNumber(0)];
  [self openHistoryPanel];

  // Assert that three history elements are present in first window.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL2.GetOrigin().spec(), kTitle2)]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:HistoryEntry(_URL3.GetOrigin().spec(),
                                                   _URL3.GetContent())]
      assertWithMatcher:grey_notNil()];

  // Delete item 1 from first window.
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      performAction:grey_longPress()];

  [[EarlGrey selectElementWithMatcher:DeleteButton()] performAction:grey_tap()];

  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_nil()];

  // And make sure it has disappeared from second window.
  [EarlGrey setRootMatcherForSubsequentInteractions:WindowWithNumber(1)];
  [[EarlGrey
      selectElementWithMatcher:HistoryEntry(_URL1.GetOrigin().spec(), kTitle1)]
      assertWithMatcher:grey_nil()];
}

#pragma mark Helper Methods

- (void)loadTestURLs {
  [ChromeEarlGrey loadURL:_URL1];
  [ChromeEarlGrey waitForWebStateContainingText:kResponse1];

  [ChromeEarlGrey loadURL:_URL2];
  [ChromeEarlGrey waitForWebStateContainingText:kResponse2];

  [ChromeEarlGrey loadURL:_URL3];
  [ChromeEarlGrey waitForWebStateContainingText:kResponse3];
}

- (void)openHistoryPanel {
  [ChromeEarlGreyUI openToolsMenu];
  [ChromeEarlGreyUI tapToolsMenuButton:HistoryButton()];
}

@end
