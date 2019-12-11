// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#include "components/prefs/pref_service.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_earl_grey_utils.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_path_cache.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_ui_constants.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::CancelButton;

// Bookmark search integration tests for Chrome.
@interface BookmarksSearchTestCase : ChromeTestCase
@end

@implementation BookmarksSearchTestCase

- (void)setUp {
  [super setUp];

  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  [ChromeEarlGrey clearBookmarks];
}

// Tear down called once per test.
- (void)tearDown {
  [super tearDown];
  [ChromeEarlGrey clearBookmarks];
  // Clear position cache so that Bookmarks starts at the root folder in next
  // test.
  ios::ChromeBrowserState* browser_state =
      chrome_test_util::GetOriginalBrowserState();
  [BookmarkPathCache
      clearBookmarkTopMostRowCacheWithPrefService:browser_state->GetPrefs()];
}

#pragma mark - BookmarksSearchTestCase Tests

// Tests that the search bar is shown on root.
- (void)testSearchBarShownOnRoot {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];

  // Verify the search bar is shown.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      assertWithMatcher:grey_allOf(grey_sufficientlyVisible(),
                                   grey_userInteractionEnabled(), nil)];
}

// Tests that the search bar is shown on mobile list.
- (void)testSearchBarShownOnMobileBookmarks {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Verify the search bar is shown.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      assertWithMatcher:grey_allOf(grey_sufficientlyVisible(),
                                   grey_userInteractionEnabled(), nil)];
}

// Tests the search.
- (void)testSearchResults {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Verify we have our 3 items.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_notNil()];

  // Search 'o'.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"o")];

  // Verify that folders are not filtered out.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1")]
      assertWithMatcher:grey_notNil()];

  // Search 'on'.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"n")];

  // Verify we are left only with the "First" and "Second" one.
  // 'on' matches 'pony.html' and 'Second'
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_nil()];
  // Verify that folders are not filtered out.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1")]
      assertWithMatcher:grey_nil()];

  // Search again for 'ony'.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"y")];

  // Verify we are left only with the "First" one for 'pony.html'.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_nil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_nil()];
}

// Tests that you get 'No Results' when no matching bookmarks are found.
- (void)testSearchWithNoResults {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search 'zz'.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"zz\n")];

  // Verify that we have a 'No Results' label somewhere.
  [[EarlGrey selectElementWithMatcher:grey_text(l10n_util::GetNSString(
                                          IDS_HISTORY_NO_SEARCH_RESULTS))]
      assertWithMatcher:grey_notNil()];

  // Verify that Edit button is disabled.
  [[EarlGrey selectElementWithMatcher:ContextBarTrailingButtonWithLabel(
                                          [BookmarkEarlGreyUtils
                                              contextBarSelectString])]
      assertWithMatcher:grey_accessibilityTrait(
                            UIAccessibilityTraitNotEnabled)];
}

// Tests that scrim is shown while search box is enabled with no queries.
- (void)testSearchScrimShownWhenSearchBoxEnabled {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

  // Verify that scrim is visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_notNil()];

  // Searching.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"i")];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];

  // Go back to original folder content.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_clearText()];

  // Verify that scrim is visible again.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_notNil()];

  // Cancel.
  [[EarlGrey selectElementWithMatcher:CancelButton()] performAction:grey_tap()];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];
}

// Tests that tapping scrim while search box is enabled dismisses the search
// controller.
- (void)testSearchTapOnScrimCancelsSearchController {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

  // Tap on scrim.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      performAction:grey_tap()];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];

  // Verifiy we went back to original folder content.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_notNil()];
}

// Tests that long press on scrim while search box is enabled dismisses the
// search controller.
- (void)testSearchLongPressOnScrimCancelsSearchController {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

  // Try long press.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      performAction:grey_longPress()];

  // Verify context menu is not visible.
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_IOS_BOOKMARK_CONTEXT_MENU_EDIT)]
      assertWithMatcher:grey_nil()];

  // Verify that scrim is not visible.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeSearchScrimIdentifier)]
      assertWithMatcher:grey_nil()];

  // Verifiy we went back to original folder content.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_notNil()];
}

// Tests cancelling search restores the node's bookmarks.
- (void)testSearchCancelRestoresNodeBookmarks {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"X")];

  // Verify we have no items.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_nil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_nil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_nil()];

  // Cancel.
  [[EarlGrey selectElementWithMatcher:CancelButton()] performAction:grey_tap()];

  // Verify all items are back.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_notNil()];
}

// Tests that the navigation bar isn't shown when search is focused and empty.
- (void)testSearchHidesNavigationBar {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Focus Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_tap()];

  // Verify we have no navigation bar.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeUIToolbarIdentifier)]
      assertWithMatcher:grey_nil()];

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First")];

  // Verify we now have a navigation bar.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeUIToolbarIdentifier)]
      assertWithMatcher:grey_notNil()];
}

// Tests that you can long press and edit a bookmark and see edits when going
// back to search.
- (void)testSearchLongPressEditOnURL {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First")];

  // Invoke Edit through context menu.
  [BookmarkEarlGreyUtils
      tapOnLongPressContextMenuButton:IDS_IOS_BOOKMARK_CONTEXT_MENU_EDIT
                               onItem:TappableBookmarkNodeWithLabel(
                                          @"First URL")
                           openEditor:kBookmarkEditViewContainerIdentifier
                      modifyTextField:@"Title Field_textField"
                                   to:@"n6"
                          dismissWith:
                              kBookmarkEditNavigationBarDoneButtonIdentifier];

  // Should not find it anymore.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_nil()];

  // Search with new name.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_replaceText(@"n6")];

  // Should now find it again.
  [[EarlGrey selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"n6")]
      assertWithMatcher:grey_notNil()];
}

// Tests that you can long press and edit a bookmark folder and see edits
// when going back to search.
- (void)testSearchLongPressEditOnFolder {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  NSString* existingFolderTitle = @"Folder 1.1";

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(existingFolderTitle)];

  // Invoke Edit through long press.
  [[EarlGrey selectElementWithMatcher:TappableBookmarkNodeWithLabel(
                                          existingFolderTitle)]
      performAction:grey_longPress()];

  [[EarlGrey
      selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                   IDS_IOS_BOOKMARK_CONTEXT_MENU_EDIT_FOLDER)]
      performAction:grey_tap()];

  // Verify that the editor is present.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkFolderEditViewContainerIdentifier)]
      assertWithMatcher:grey_notNil()];

  NSString* newFolderTitle = @"n7";
  [BookmarkEarlGreyUtils renameBookmarkFolderWithFolderTitle:newFolderTitle];

  [[EarlGrey selectElementWithMatcher:BookmarksSaveEditFolderButton()]
      performAction:grey_tap()];

  // Verify that the change has been made.
  [[EarlGrey selectElementWithMatcher:TappableBookmarkNodeWithLabel(
                                          existingFolderTitle)]
      assertWithMatcher:grey_nil()];

  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_replaceText(newFolderTitle)];

  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(newFolderTitle)]
      assertWithMatcher:grey_notNil()];
}

// Tests that you can swipe URL items in search mode.
- (void)testSearchUrlCanBeSwipedToDelete {
  // TODO(crbug.com/851227): On non Compact Width, the bookmark cell is being
  // deleted by grey_swipeFastInDirection.
  // grey_swipeFastInDirectionWithStartPoint doesn't work either and it might
  // fail on devices. Disabling this test under these conditions on the
  // meantime.
  if (![ChromeEarlGrey isCompactWidth]) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on iPad on iOS11.");
  }

  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First URL")];

  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      performAction:grey_swipeFastInDirection(kGREYDirectionLeft)];

  // Verify we have a delete button.
  [[EarlGrey selectElementWithMatcher:BookmarksDeleteSwipeButton()]
      assertWithMatcher:grey_notNil()];
}

// Tests that you can swipe folders in search mode.
- (void)testSearchFolderCanBeSwipedToDelete {
  // TODO(crbug.com/851227): On non Compact Width, the bookmark cell is being
  // deleted by grey_swipeFastInDirection.
  // grey_swipeFastInDirectionWithStartPoint doesn't work either and it might
  // fail on devices. Disabling this test under these conditions on the
  // meantime.
  if (![ChromeEarlGrey isCompactWidth]) {
    EARL_GREY_TEST_SKIPPED(@"Test disabled on iPad on iOS11.");
  }

  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"Folder 1")];

  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1")]
      performAction:grey_swipeFastInDirection(kGREYDirectionLeft)];

  // Verify we have a delete button.
  [[EarlGrey selectElementWithMatcher:BookmarksDeleteSwipeButton()]
      assertWithMatcher:grey_notNil()];
}

// Tests that you can't search while in edit mode.
- (void)testDisablesSearchOnEditMode {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Verify search bar is enabled.
  [[EarlGrey selectElementWithMatcher:grey_kindOfClassName(@"UISearchBar")]
      assertWithMatcher:grey_userInteractionEnabled()];

  // Change to edit mode
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkHomeTrailingButtonIdentifier)]
      performAction:grey_tap()];

  // Verify search bar is disabled.
  [[EarlGrey selectElementWithMatcher:grey_kindOfClassName(@"UISearchBar")]
      assertWithMatcher:grey_not(grey_userInteractionEnabled())];

  // Cancel edito mode.
  [BookmarkEarlGreyUtils closeContextBarEditMode];

  // Verify search bar is enabled.
  [[EarlGrey selectElementWithMatcher:grey_kindOfClassName(@"UISearchBar")]
      assertWithMatcher:grey_userInteractionEnabled()];
}

// Tests that new Folder is disabled when search results are shown.
- (void)testSearchDisablesNewFolderButtonOnNavigationBar {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search and hide keyboard.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First\n")];

  // Verify we now have a navigation bar.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeUIToolbarIdentifier)]
      assertWithMatcher:grey_notNil()];

  [[EarlGrey selectElementWithMatcher:ContextBarLeadingButtonWithLabel(
                                          [BookmarkEarlGreyUtils
                                              contextBarNewFolderString])]
      assertWithMatcher:grey_accessibilityTrait(
                            UIAccessibilityTraitNotEnabled)];
}

// Tests that a single edit is possible when searching and selecting a single
// URL in edit mode.
- (void)testSearchEditModeEditOnSingleURL {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search and hide keyboard.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First\n")];

  // Change to edit mode
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkHomeTrailingButtonIdentifier)]
      performAction:grey_tap()];

  // Select URL.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityLabel(@"First URL, 127.0.0.1")]
      performAction:grey_tap()];

  // Invoke Edit through context menu.
  [BookmarkEarlGreyUtils
      tapOnContextMenuButton:IDS_IOS_BOOKMARK_CONTEXT_MENU_EDIT
                  openEditor:kBookmarkEditViewContainerIdentifier
             modifyTextField:@"Title Field_textField"
                          to:@"n6"
                 dismissWith:kBookmarkEditNavigationBarDoneButtonIdentifier];

  // Should not find it anymore.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_nil()];

  // Search with new name.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_replaceText(@"n6")];

  // Should now find it again.
  [[EarlGrey selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"n6")]
      assertWithMatcher:grey_notNil()];
}

// Tests that multiple deletes on search results works.
- (void)testSearchEditModeDeleteOnMultipleURL {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search and hide keyboard.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"URL\n")];

  // Change to edit mode
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkHomeTrailingButtonIdentifier)]
      performAction:grey_tap()];

  // Select URLs.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityLabel(@"First URL, 127.0.0.1")]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityLabel(
                                          @"Second URL, 127.0.0.1")]
      performAction:grey_tap()];

  // Delete.
  [[EarlGrey selectElementWithMatcher:ContextBarLeadingButtonWithLabel(
                                          [BookmarkEarlGreyUtils
                                              contextBarDeleteString])]
      performAction:grey_tap()];

  // Should not find them anymore.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_nil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      assertWithMatcher:grey_nil()];

  // Should find other two URLs.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Third URL")]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"French URL")]
      assertWithMatcher:grey_notNil()];
}

// Tests that multiple moves on search results works.
- (void)testMoveFunctionalityOnMultipleUrlSelection {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Search and hide keyboard.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"URL\n")];

  // Change to edit mode, using context menu.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkHomeTrailingButtonIdentifier)]
      performAction:grey_tap()];

  // Select URL and folder.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Second URL")]
      performAction:grey_tap()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      performAction:grey_tap()];

  // Tap context menu.
  [[EarlGrey selectElementWithMatcher:ContextBarCenterButtonWithLabel(
                                          [BookmarkEarlGreyUtils
                                              contextBarMoreString])]
      performAction:grey_tap()];

  // Tap on move, from context menu.
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_IOS_BOOKMARK_CONTEXT_MENU_MOVE)]
      performAction:grey_tap()];

  // Choose to move into Folder 1. Use grey_ancestor since
  // BookmarksHomeTableView might be visible on the background on non-compact
  // widthts, and there might be a "Folder1" node there as well.
  [[EarlGrey selectElementWithMatcher:
                 grey_allOf(TappableBookmarkNodeWithLabel(@"Folder 1"),
                            grey_ancestor(grey_accessibilityID(
                                kBookmarkFolderPickerViewContainerIdentifier)),
                            nil)] performAction:grey_tap()];

  // Verify all folder flow UI is now closed.
  [BookmarkEarlGreyUtils verifyFolderFlowIsClosed];

  // Wait for Undo toast to go away from screen.
  [BookmarkEarlGreyUtils waitForUndoToastToGoAway];

  // Verify edit mode is closed (context bar back to default state).
  [BookmarkEarlGreyUtils verifyContextBarInDefaultStateWithSelectEnabled:YES
                                                        newFolderEnabled:NO];

  // Cancel search.
  [[EarlGrey selectElementWithMatcher:CancelButton()] performAction:grey_tap()];

  // Verify Folder 1 has three bookmark nodes.
  [BookmarkEarlGreyUtils assertChildCount:3 ofFolderWithName:@"Folder 1"];

  // Drill down to where "Second URL" and "First URL" have been moved and assert
  // it's presence.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1")]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"Second URL")]
      assertWithMatcher:grey_sufficientlyVisible()];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"First URL")]
      assertWithMatcher:grey_sufficientlyVisible()];
}

// Tests that a search and single edit is possible when searching over root.
- (void)testSearchEditPossibleOnRoot {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];

  // Search and hide keyboard.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"First\n")];

  // Change to edit mode
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kBookmarkHomeTrailingButtonIdentifier)]
      performAction:grey_tap()];

  // Select URL.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityLabel(@"First URL, 127.0.0.1")]
      performAction:grey_tap()];

  // Invoke Edit through context menu.
  [BookmarkEarlGreyUtils
      tapOnContextMenuButton:IDS_IOS_BOOKMARK_CONTEXT_MENU_EDIT
                  openEditor:kBookmarkEditViewContainerIdentifier
             modifyTextField:@"Title Field_textField"
                          to:@"n6"
                 dismissWith:kBookmarkEditNavigationBarDoneButtonIdentifier];

  // Should not find it anymore.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"First URL")]
      assertWithMatcher:grey_nil()];

  // Search with new name.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_replaceText(@"n6")];

  // Should now find it again.
  [[EarlGrey selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"n6")]
      assertWithMatcher:grey_notNil()];

  // Cancel search.
  [[EarlGrey selectElementWithMatcher:CancelButton()] performAction:grey_tap()];

  // Verify we have no navigation bar.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kBookmarkHomeUIToolbarIdentifier)]
      assertWithMatcher:grey_nil()];
}

// Tests that you can search folders.
- (void)testSearchFolders {
  [BookmarkEarlGreyUtils setupStandardBookmarks];
  [BookmarkEarlGreyUtils openBookmarks];
  [BookmarkEarlGreyUtils openMobileBookmarks];

  // Go down Folder 1 / Folder 2 / Folder 3.
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1")]
      performAction:grey_tap()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 2")]
      performAction:grey_tap()];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 3")]
      performAction:grey_tap()];

  // Search and go to folder 1.1.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"Folder 1.1")];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 1.1")]
      performAction:grey_tap()];

  // Go back and verify we are in MobileBooknarks. (i.e. not back to Folder 2)
  [[EarlGrey selectElementWithMatcher:NavigateBackButtonTo(@"Mobile Bookmarks")]
      performAction:grey_tap()];

  // Search and go to Folder 2.
  [[EarlGrey selectElementWithMatcher:SearchIconButton()]
      performAction:grey_typeText(@"Folder 2")];
  [[EarlGrey
      selectElementWithMatcher:TappableBookmarkNodeWithLabel(@"Folder 2")]
      performAction:grey_tap()];

  // Go back and verify we are in Folder 1. (i.e. not back to Mobile Bookmarks)
  [[EarlGrey selectElementWithMatcher:NavigateBackButtonTo(@"Folder 1")]
      performAction:grey_tap()];
}

@end
