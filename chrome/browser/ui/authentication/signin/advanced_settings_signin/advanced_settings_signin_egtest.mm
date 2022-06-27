// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/ios/ios_util.h"
#import "base/test/ios/wait_util.h"
#import "ios/chrome/browser/ui/authentication/signin/advanced_settings_signin/advanced_settings_signin_constants.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_ui_test_util.h"
#import "ios/chrome/browser/ui/authentication/signin_matchers.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_earl_grey.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_earl_grey_ui.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/recent_tabs/recent_tabs_constants.h"
#import "ios/chrome/browser/ui/settings/google_services/manage_sync_settings_constants.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/chrome/test/earl_grey/web_http_server_chrome_test_case.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "ios/testing/earl_grey/matchers.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::GoogleSyncSettingsButton;
using chrome_test_util::PrimarySignInButton;
using chrome_test_util::SettingsDoneButton;
using chrome_test_util::SettingsLink;
using chrome_test_util::AdvancedSyncSettingsDoneButtonMatcher;
using l10n_util::GetNSString;
using testing::ButtonWithAccessibilityLabel;
using base::test::ios::WaitUntilConditionOrTimeout;
using base::test::ios::kWaitForUIElementTimeout;

namespace {

NSString* const kPassphrase = @"hello";

// Timeout in seconds to wait for asynchronous sync operations.
const NSTimeInterval kSyncOperationTimeout = 5.0;

// Waits for the settings done button to be enabled.
void WaitForSettingDoneButton() {
  ConditionBlock condition = ^{
    NSError* error = nil;
    [[EarlGrey selectElementWithMatcher:SettingsDoneButton()]
        assertWithMatcher:grey_sufficientlyVisible()
                    error:&error];
    return error == nil;
  };
  GREYAssert(base::test::ios::WaitUntilConditionOrTimeout(
                 base::test::ios::kWaitForClearBrowsingDataTimeout, condition),
             @"Settings done button not visible");
}

}  // namespace

// Interaction tests for advanced settings sign-in.
@interface AdvancedSettingsSigninTestCase : WebHttpServerChromeTestCase
@end

@implementation AdvancedSettingsSigninTestCase

- (void)setUp {
  [super setUp];

  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  [ChromeEarlGrey clearBookmarks];
}

- (void)tearDown {
  [super tearDown];
  [ChromeEarlGrey clearBookmarks];
  [BookmarkEarlGrey clearBookmarksPositionCache];
}

// Tests that signing in, tapping the Settings link on the confirmation screen
// and closing the advanced sign-in settings correctly leaves the user signed
// in.
- (void)testSignInOpenSyncSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];
  // Test the user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
}

// Tests that a user that signs in and gives sync consent can sign
// out through the "Sign out and Turn Off Sync" > "Clear Data" option in Sync
// settings.
- (void)testSignInOpenSyncSettingsSignOutAndTurnOffSyncWithClearData {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];
  // Test the user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];

  // Add a bookmark after sync is initialized.
  [ChromeEarlGrey waitForSyncInitialized:YES syncTimeout:kSyncOperationTimeout];
  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  [BookmarkEarlGrey setupStandardBookmarks];

  // Sign out and clear data from Sync settings.
  [ChromeEarlGreyUI tapSettingsMenuButton:GoogleSyncSettingsButton()];
  [[[EarlGrey selectElementWithMatcher:
                  grey_accessibilityLabel(l10n_util::GetNSString(
                      IDS_IOS_OPTIONS_ACCOUNTS_SIGN_OUT_TURN_OFF_SYNC))]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, 200)
      onElementWithMatcher:grey_accessibilityID(
                               kManageSyncTableViewAccessibilityIdentifier)]
      performAction:grey_tap()];

  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::ButtonWithAccessibilityLabelId(
                                   IDS_IOS_SIGNOUT_DIALOG_CLEAR_DATA_BUTTON)]
      performAction:grey_tap()];
  WaitForSettingDoneButton();

  // Verify signed out.
  [SigninEarlGrey verifySignedOut];
  [[EarlGrey selectElementWithMatcher:SettingsDoneButton()]
      performAction:grey_tap()];

  // Verify bookmarks are cleared.
  [BookmarkEarlGreyUI openBookmarks];
  [BookmarkEarlGreyUI verifyEmptyBackgroundAppears];
}

// Tests that a user that signs in and gives sync consent can sign
// out through the "Sign out and Turn Off Sync" > "Keep Data" option in Sync
// setting.
- (void)testSignInOpenSyncSettingsSignOutAndTurnOffSyncWithKeepData {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];
  // Test the user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];

  // Add a bookmark after sync is initialized.
  [ChromeEarlGrey waitForSyncInitialized:YES syncTimeout:kSyncOperationTimeout];
  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  [BookmarkEarlGrey setupStandardBookmarks];

  // Sign out and keep data from Sync settings.
  [ChromeEarlGreyUI tapSettingsMenuButton:GoogleSyncSettingsButton()];
  [[[EarlGrey selectElementWithMatcher:
                  grey_accessibilityLabel(l10n_util::GetNSString(
                      IDS_IOS_OPTIONS_ACCOUNTS_SIGN_OUT_TURN_OFF_SYNC))]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, 200)
      onElementWithMatcher:grey_accessibilityID(
                               kManageSyncTableViewAccessibilityIdentifier)]
      performAction:grey_tap()];

  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::ButtonWithAccessibilityLabelId(
                                   IDS_IOS_SIGNOUT_DIALOG_KEEP_DATA_BUTTON)]
      performAction:grey_tap()];
  WaitForSettingDoneButton();

  // Verify signed out.
  [SigninEarlGrey verifySignedOut];
  [[EarlGrey selectElementWithMatcher:SettingsDoneButton()]
      performAction:grey_tap()];

  // Verify bookmarks are available.
  [BookmarkEarlGreyUI openBookmarks];
  [BookmarkEarlGreyUI verifyEmptyBackgroundIsAbsent];
}

// Tests that "Sign out and Turn Off Sync" is not present in advanced settings.
- (void)testSignInOpenSyncSettingsNoSignOut {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];

  [[[EarlGrey selectElementWithMatcher:
                  grey_accessibilityLabel(l10n_util::GetNSString(
                      IDS_IOS_OPTIONS_ACCOUNTS_SIGN_OUT_TURN_OFF_SYNC))]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, 200)
      onElementWithMatcher:grey_accessibilityID(
                               kManageSyncTableViewAccessibilityIdentifier)]
      assertWithMatcher:grey_notVisible()];
}

// Tests that a user account with a sync password displays a sync error
// message after sign-in.
- (void)testSigninOpenSyncSettingsWithPasswordError {
  [ChromeEarlGrey addBookmarkWithSyncPassphrase:kPassphrase];
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];
  // Test the user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];

  // Give the Sync state a chance to finish UI updates.
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:GoogleSyncSettingsButton()];
  [[EarlGrey selectElementWithMatcher:GoogleSyncSettingsButton()]
      performAction:grey_tap()];

  // Test the sync error message is visible.
  ConditionBlock condition = ^{
    NSError* error = nil;
    [[EarlGrey
        selectElementWithMatcher:grey_accessibilityLabel(l10n_util::GetNSString(
                                     IDS_IOS_SYNC_ERROR_TITLE))]
        assertWithMatcher:grey_sufficientlyVisible()
                    error:&error];
    return error == nil;
  };
  GREYAssert(WaitUntilConditionOrTimeout(kWaitForUIElementTimeout, condition),
             @"Could not find the Sync Error text");
}

// Tests that no sync error will be displayed after a user introduces the sync
// passphrase correctly from Advanced Settings and then signs in.
- (void)testSigninWithPassword {
  [ChromeEarlGrey addBookmarkWithSyncPassphrase:kPassphrase];
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  // Scroll and select the Encryption item.
  [[[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                           IDS_IOS_MANAGE_SYNC_ENCRYPTION)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, 200)
      onElementWithMatcher:grey_accessibilityID(
                               kManageSyncTableViewAccessibilityIdentifier)]
      performAction:grey_tap()];

  // Type and submit the sync passphrase.
  [SigninEarlGreyUI submitSyncPassphrase:kPassphrase];

  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];
  // Check Sync On label is visible and user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [SigninEarlGrey verifySyncUIEnabled:YES];
}

// Tests interrupting sign-in by opening an URL from another app.
// Sign-in opened from: setting menu.
// Interrupted at: advanced sign-in.
- (void)testInterruptAdvancedSigninSettingsFromAdvancedSigninSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [ChromeEarlGrey simulateExternalAppURLOpening];

  [SigninEarlGrey verifySignedOut];
}

// Tests interrupting sign-in by opening an URL from another app.
// Sign-in opened from: bookmark view.
// Interrupted at: advanced sign-in.
- (void)testInterruptAdvancedSigninBookmarksFromAdvancedSigninSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openToolsMenu];
  [ChromeEarlGreyUI
      tapToolsMenuButton:chrome_test_util::BookmarksDestinationButton()];
  [[EarlGrey selectElementWithMatcher:PrimarySignInButton()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [ChromeEarlGrey simulateExternalAppURLOpening];

  [SigninEarlGrey verifySignedOut];
}

// Tests interrupting sign-in by opening an URL from another app.
// Sign-in opened from: recent tabs.
// Interrupted at: advanced sign-in.
- (void)testInterruptSigninFromRecentTabsFromAdvancedSigninSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [SigninEarlGreyUI tapPrimarySignInButtonInRecentTabs];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [ChromeEarlGrey simulateExternalAppURLOpening];

  [SigninEarlGrey verifySignedOut];
}

// Tests interrupting sign-in by opening an URL from another app.
// Sign-in opened from: tab switcher.
// Interrupted at: advanced sign-in.
- (void)testInterruptSigninFromTabSwitcherFromAdvancedSigninSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [SigninEarlGreyUI tapPrimarySignInButtonInTabSwitcher];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [ChromeEarlGrey simulateExternalAppURLOpening];

  [SigninEarlGrey verifySignedOut];
}

// Tests that canceling sign-in from advanced sign-in settings will
// return the user to their prior sign-in state.
- (void)testCancelSigninFromAdvancedSigninSettings {
  FakeChromeIdentity* fakeIdentity = [FakeChromeIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [[EarlGrey selectElementWithMatcher:SettingsLink()] performAction:grey_tap()];
  [ChromeEarlGreyUI waitForAppToIdle];

  [[EarlGrey selectElementWithMatcher:AdvancedSyncSettingsDoneButtonMatcher()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:
                 ButtonWithAccessibilityLabelId(
                     IDS_IOS_ACCOUNT_CONSISTENCY_SETUP_SKIP_BUTTON)]
      performAction:grey_tap()];

  [SigninEarlGrey verifySignedOut];
}

@end
