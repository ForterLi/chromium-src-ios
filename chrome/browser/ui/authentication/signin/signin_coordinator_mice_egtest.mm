// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "base/ios/block_types.h"
#include "base/ios/ios_util.h"
#include "components/signin/public/base/account_consistency_method.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_ui.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/settings/google_services/google_services_settings_constants.h"
#import "ios/chrome/browser/ui/settings/google_services/manage_sync_settings_constants.h"
#import "ios/chrome/browser/ui/settings/settings_table_view_controller_constants.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "ios/testing/earl_grey/matchers.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::ButtonWithAccessibilityLabel;
using chrome_test_util::PrimarySignInButton;
using chrome_test_util::SettingsAccountButton;
using chrome_test_util::SettingsDoneButton;
using chrome_test_util::ClearBrowsingDataButton;
using chrome_test_util::ConfirmClearBrowsingDataButton;
using chrome_test_util::SettingsMenuPrivacyButton;
using chrome_test_util::SettingsCollectionView;

namespace {
NSString* const kPassphrase = @"hello";
}

// Sign-in interaction tests that work with |kMobileIdentityConsistency|
// enabled.
@interface SigninCoordinatorMICETestCase : ChromeTestCase
@end

@implementation SigninCoordinatorMICETestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  config.features_enabled.push_back(signin::kMobileIdentityConsistency);
  return config;
}

- (void)setUp {
  [super setUp];
  // Remove closed tab history to make sure the sign-in promo is always visible
  // in recent tabs.
  [ChromeEarlGrey clearBrowsingHistory];
}

// Tests that a signed-in user can open "Settings" screen from the NTP.
- (void)testOpenManageSyncSettingsFromNTP {
  // Sign in to Chrome.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Select the identity disc particle.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityLabel(l10n_util::GetNSString(
                                   IDS_ACCNAME_PARTICLE_DISC))]
      performAction:grey_tap()];

  // Ensure the Settings menu is displayed.
  [[EarlGrey selectElementWithMatcher:SettingsCollectionView()]
      assertWithMatcher:grey_sufficientlyVisible()];
}

// Tests that opening the sign-in screen from the Settings and signing in works
// correctly when there is already an identity on the device.
- (void)testSignInFromSettingsMenu {
  // Set up a fake identity.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Check |fakeIdentity| is signed-in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];

  // Check the Settings Menu labels for sync state.
  [ChromeEarlGreyUI openSettingsMenu];
  [[EarlGrey
      selectElementWithMatcher:grey_allOf(
                                   grey_accessibilityValue(
                                       l10n_util::GetNSString(
                                           IDS_IOS_SETTING_ON)),
                                   grey_accessibilityID(
                                       kSettingsGoogleSyncAndServicesCellId),
                                   nil)]
      assertWithMatcher:grey_sufficientlyVisible()];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kSettingsGoogleServicesCellId)]
      assertWithMatcher:grey_sufficientlyVisible()];
  [[EarlGrey selectElementWithMatcher:SettingsAccountButton()]
      assertWithMatcher:grey_sufficientlyVisible()];
}

// Tests that opening the sign-in screen from the Sync Off tab and signin in
// will turn Sync On.
- (void)testSignInFromSyncOffLink {
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity enableSync:NO];

  [ChromeEarlGreyUI openSettingsMenu];
  // Check Sync Off label is visible and user is signed in.
  [[EarlGrey
      selectElementWithMatcher:grey_allOf(
                                   grey_accessibilityValue(
                                       l10n_util::GetNSString(
                                           IDS_IOS_SETTING_OFF)),
                                   grey_accessibilityID(
                                       kSettingsGoogleSyncAndServicesCellId),
                                   nil)] performAction:grey_tap()];

  [SigninEarlGreyUI tapSigninConfirmationDialog];

  // Check Sync On label is visible and user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [[EarlGrey
      selectElementWithMatcher:grey_allOf(
                                   grey_accessibilityValue(
                                       l10n_util::GetNSString(
                                           IDS_IOS_SETTING_ON)),
                                   grey_accessibilityID(
                                       kSettingsGoogleSyncAndServicesCellId),
                                   nil)]
      assertWithMatcher:grey_sufficientlyVisible()];
  [[EarlGrey selectElementWithMatcher:SettingsDoneButton()]
      performAction:grey_tap()];
  [ChromeEarlGreyUI waitForToolbarVisible:YES];
}

// Tests that the sign-in promo for no identities is displayed in Settings when
// the user is signed out and has not added any identities to the device.
- (void)testSigninPromoWithNoIdentitiesOnDevice {
  [ChromeEarlGreyUI openSettingsMenu];

  [SigninEarlGrey verifySignedOut];
  [SigninEarlGreyUI
      verifySigninPromoVisibleWithMode:SigninPromoViewModeNoAccounts];
}

// Tests that the sign-in promo with user name is displayed in Settings when the
// user is signed out.
- (void)testSigninPromoWhenSignedOut {
  // Add identity to the device.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];

  [SigninEarlGrey verifySignedOut];
  [SigninEarlGreyUI
      verifySigninPromoVisibleWithMode:SigninPromoViewModeSigninWithAccount];
}

// Tests that the sign-in promo is removed from Settings when the user
// is signed out and has closed the sign-in promo with user name.
- (void)testSigninPromoClosedWhenSignedOut {
  // Add identity to the device.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [SigninEarlGreyUI
      verifySigninPromoVisibleWithMode:SigninPromoViewModeSigninWithAccount
                           closeButton:YES];
  [[EarlGrey
      selectElementWithMatcher:grey_allOf(grey_accessibilityID(
                                              kSigninPromoCloseButtonId),
                                          grey_sufficientlyVisible(), nil)]
      performAction:grey_tap()];

  [SigninEarlGrey verifySignedOut];
  [SigninEarlGreyUI verifySigninPromoNotVisible];
}

// Tests that the sign-in promo for Sync is displayed when the user is signed in
// with Sync off.
- (void)testSigninPromoWhenSyncOff {
  // Add identity to the device.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity enableSync:NO];

  [ChromeEarlGreyUI openSettingsMenu];
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI
      verifySigninPromoVisibleWithMode:SigninPromoViewModeSigninWithAccount];
}

// Tests that no sign-in promo for Sync is displayed when the user is signed in
// with Sync off and has closed the sign-in promo for Sync.
- (void)testSigninPromoClosedWhenSyncOff {
  // Add identity to the device.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity enableSync:NO];

  [ChromeEarlGreyUI openSettingsMenu];
  [SigninEarlGreyUI
      verifySigninPromoVisibleWithMode:SigninPromoViewModeSigninWithAccount];
  // Tap on dismiss button.
  [[EarlGrey
      selectElementWithMatcher:grey_allOf(grey_accessibilityID(
                                              kSigninPromoCloseButtonId),
                                          grey_sufficientlyVisible(), nil)]
      performAction:grey_tap()];

  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI verifySigninPromoNotVisible];
}

// Tests that a user in the |ConsentLevel::kSignin| state will be signed out
// after clearing their browsing history.
- (void)testUserSignedOutWhenClearingBrowsingData {
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity enableSync:NO];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:SettingsMenuPrivacyButton()];
  [ChromeEarlGreyUI
      tapPrivacyMenuButton:ButtonWithAccessibilityLabelId(
                               IDS_IOS_CLEAR_BROWSING_DATA_TITLE)];
  [ChromeEarlGreyUI tapClearBrowsingDataMenuButton:ClearBrowsingDataButton()];
  [[EarlGrey selectElementWithMatcher:ConfirmClearBrowsingDataButton()]
      performAction:grey_tap()];

  [SigninEarlGrey verifySignedOut];
}

// Tests that Sync is on when introducing passphrase from settings, after
// logging in.
- (void)testSyncOnWhenPassphraseIntroducedAfterSignIn {
  [ChromeEarlGrey addBookmarkWithSyncPassphrase:kPassphrase];
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [SigninEarlGreyUI tapSigninConfirmationDialog];

  [[EarlGrey
      selectElementWithMatcher:
          grey_allOf(grey_accessibilityValue(l10n_util::GetNSString(
                         IDS_IOS_SYNC_ENCRYPTION_DESCRIPTION)),
                     grey_accessibilityID(kSettingsGoogleSyncAndServicesCellId),
                     nil)] performAction:grey_tap()];

  // Scroll to bottom of Manage Sync Settings, if necessary.
  [[EarlGrey selectElementWithMatcher:
                 grey_allOf(grey_accessibilityID(
                                kManageSyncTableViewAccessibilityIdentifier),
                            grey_sufficientlyVisible(), nil)]
      performAction:grey_scrollToContentEdge(kGREYContentEdgeBottom)];

  // Select Encryption item.
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_IOS_MANAGE_SYNC_ENCRYPTION)]
      performAction:grey_tap()];

  // Type and submit the sync passphrase.
  [SigninEarlGreyUI submitSyncPassphrase:kPassphrase];

  [[EarlGrey selectElementWithMatcher:SettingsDoneButton()]
      performAction:grey_tap()];
  [ChromeEarlGreyUI openSettingsMenu];

  // Check Sync On label is visible.
  [SigninEarlGrey verifySyncUIEnabled:YES];
}
@end
