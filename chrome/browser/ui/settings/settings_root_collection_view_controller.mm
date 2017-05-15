// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/settings_root_collection_view_controller.h"

#include "base/ios/ios_util.h"
#include "base/logging.h"
#import "base/mac/foundation_util.h"
#import "base/mac/objc_release_properties.h"
#import "base/mac/scoped_nsobject.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/ui/commands/UIKit+ChromeExecuteCommand.h"
#include "ios/chrome/browser/ui/commands/ios_command_ids.h"
#import "ios/chrome/browser/ui/commands/open_url_command.h"
#import "ios/chrome/browser/ui/settings/bar_button_activity_indicator.h"
#import "ios/chrome/browser/ui/settings/settings_navigation_controller.h"
#import "ios/chrome/browser/ui/settings/settings_utils.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/third_party/material_components_ios/src/components/Collections/src/MaterialCollections.h"
#include "ui/base/l10n/l10n_util.h"

namespace {
enum SavedBarButtomItemPositionEnum {
  kUndefinedBarButtonItemPosition,
  kLeftBarButtonItemPosition,
  kRightBarButtonItemPosition
};

// Dimension of the authentication operation activity indicator frame.
const CGFloat kActivityIndicatorDimensionIPad = 64;
const CGFloat kActivityIndicatorDimensionIPhone = 56;

}  // namespace

@implementation SettingsRootCollectionViewController {
  SavedBarButtomItemPositionEnum savedBarButtonItemPosition_;
  base::scoped_nsobject<UIBarButtonItem> savedBarButtonItem_;
  base::scoped_nsobject<UIView> veil_;
}

@synthesize shouldHideDoneButton = shouldHideDoneButton_;
@synthesize collectionViewAccessibilityIdentifier =
    collectionViewAccessibilityIdentifier_;

- (void)dealloc {
  base::mac::ReleaseProperties(self);
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.collectionView.accessibilityIdentifier =
      self.collectionViewAccessibilityIdentifier;

  // Customize collection view settings.
  self.styler.cellStyle = MDCCollectionViewCellStyleCard;
  self.styler.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  UIBarButtonItem* doneButton = [self doneButtonIfNeeded];
  if (!self.navigationItem.rightBarButtonItem && doneButton) {
    self.navigationItem.rightBarButtonItem = doneButton;
  }
}

- (UIBarButtonItem*)doneButtonIfNeeded {
  if (self.shouldHideDoneButton) {
    return nil;
  }
  SettingsNavigationController* navigationController =
      base::mac::ObjCCast<SettingsNavigationController>(
          self.navigationController);
  return [navigationController doneButton];
}

- (UIBarButtonItem*)createEditButton {
  // Create a custom Edit bar button item, as Material Navigation Bar does not
  // handle a system UIBarButtonSystemItemEdit item.
  UIBarButtonItem* button = [[[UIBarButtonItem alloc]
      initWithTitle:l10n_util::GetNSString(IDS_IOS_NAVIGATION_BAR_EDIT_BUTTON)
              style:UIBarButtonItemStyleDone
             target:self
             action:@selector(editButtonPressed)] autorelease];
  [button setEnabled:[self editButtonEnabled]];
  return button;
}

- (UIBarButtonItem*)createEditDoneButton {
  // Create a custom Done bar button item, as Material Navigation Bar does not
  // handle a system UIBarButtonSystemItemDone item.
  return [[[UIBarButtonItem alloc]
      initWithTitle:l10n_util::GetNSString(IDS_IOS_NAVIGATION_BAR_DONE_BUTTON)
              style:UIBarButtonItemStyleDone
             target:self
             action:@selector(editButtonPressed)] autorelease];
}

- (void)updateEditButton {
  if ([self.editor isEditing]) {
    self.navigationItem.rightBarButtonItem = [self createEditDoneButton];
  } else if ([self shouldShowEditButton]) {
    self.navigationItem.rightBarButtonItem = [self createEditButton];
  } else {
    self.navigationItem.rightBarButtonItem = [self doneButtonIfNeeded];
  }
}

- (void)editButtonPressed {
  [self.editor setEditing:![self.editor isEditing] animated:YES];
  [self updateEditButton];
}

- (void)reloadData {
  [self loadModel];
  [self.collectionView reloadData];
}

#pragma mark - CollectionViewFooterLinkDelegate

- (void)cell:(CollectionViewFooterCell*)cell didTapLinkURL:(GURL)URL {
  base::scoped_nsobject<OpenUrlCommand> command(
      [[OpenUrlCommand alloc] initWithURLFromChrome:URL]);
  [command setTag:IDC_CLOSE_SETTINGS_AND_OPEN_URL];
  [self chromeExecuteCommand:command];
}

#pragma mark - Status bar

- (UIViewController*)childViewControllerForStatusBarHidden {
  if (!base::ios::IsRunningOnIOS10OrLater()) {
    // TODO(crbug.com/620361): Remove the entire method override when iOS 9 is
    // dropped.
    return nil;
  } else {
    return [super childViewControllerForStatusBarHidden];
  }
}

- (BOOL)prefersStatusBarHidden {
  if (!base::ios::IsRunningOnIOS10OrLater()) {
    // TODO(crbug.com/620361): Remove the entire method override when iOS 9 is
    // dropped.
    return NO;
  } else {
    return [super prefersStatusBarHidden];
  }
}

- (UIViewController*)childViewControllerForStatusBarStyle {
  if (!base::ios::IsRunningOnIOS10OrLater()) {
    // TODO(crbug.com/620361): Remove the entire method override when iOS 9 is
    // dropped.
    return nil;
  } else {
    return [super childViewControllerForStatusBarStyle];
  }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  if (!base::ios::IsRunningOnIOS10OrLater()) {
    // TODO(crbug.com/620361): Remove the entire method override when iOS 9 is
    // dropped.
    if (IsIPadIdiom() && !IsCompact()) {
      return UIStatusBarStyleLightContent;
    } else {
      return UIStatusBarStyleDefault;
    }
  } else {
    return [super preferredStatusBarStyle];
  }
}

#pragma mark - Subclassing

- (BOOL)shouldShowEditButton {
  return NO;
}

- (BOOL)editButtonEnabled {
  return NO;
}

- (void)preventUserInteraction {
  DCHECK(!savedBarButtonItem_);
  DCHECK_EQ(kUndefinedBarButtonItemPosition, savedBarButtonItemPosition_);

  // Create |waitButton|.
  BOOL displayActivityIndicatorOnTheRight =
      self.navigationItem.rightBarButtonItem != nil;
  CGFloat activityIndicatorDimension = IsIPadIdiom()
                                           ? kActivityIndicatorDimensionIPad
                                           : kActivityIndicatorDimensionIPhone;
  base::scoped_nsobject<BarButtonActivityIndicator> indicator(
      [[BarButtonActivityIndicator alloc]
          initWithFrame:CGRectMake(0.0, 0.0, activityIndicatorDimension,
                                   activityIndicatorDimension)]);
  base::scoped_nsobject<UIBarButtonItem> waitButton(
      [[UIBarButtonItem alloc] initWithCustomView:indicator]);

  if (displayActivityIndicatorOnTheRight) {
    // If there is a right bar button item, then it is the "Done" button.
    savedBarButtonItem_.reset([self.navigationItem.rightBarButtonItem retain]);
    savedBarButtonItemPosition_ = kRightBarButtonItemPosition;
    self.navigationItem.rightBarButtonItem = waitButton;
    [self.navigationItem.leftBarButtonItem setEnabled:NO];
  } else {
    savedBarButtonItem_.reset([self.navigationItem.leftBarButtonItem retain]);
    savedBarButtonItemPosition_ = kLeftBarButtonItemPosition;
    self.navigationItem.leftBarButtonItem = waitButton;
  }

  // Adds a veil that covers the collection view and prevents user interaction.
  DCHECK(self.view);
  DCHECK(!veil_);
  veil_.reset([[UIView alloc] initWithFrame:self.view.bounds]);
  [veil_ setAutoresizingMask:(UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleHeight)];
  [veil_ setBackgroundColor:[UIColor colorWithWhite:1.0 alpha:0.5]];
  [self.view addSubview:veil_];

  // Disable user interaction for the navigation controller view to ensure
  // that the user cannot go back by swipping the navigation's top view
  // controller
  [self.navigationController.view setUserInteractionEnabled:NO];
}

- (void)allowUserInteraction {
  DCHECK(self.navigationController)
      << "|allowUserInteraction| should always be called before this settings"
         " controller is popped or dismissed.";
  [self.navigationController.view setUserInteractionEnabled:YES];

  // Removes the veil that prevents user interaction.
  DCHECK(veil_);
  [UIView animateWithDuration:0.3
      animations:^{
        [veil_ removeFromSuperview];
      }
      completion:^(BOOL finished) {
        veil_.reset();
      }];

  DCHECK(savedBarButtonItem_);
  switch (savedBarButtonItemPosition_) {
    case kLeftBarButtonItemPosition:
      self.navigationItem.leftBarButtonItem = savedBarButtonItem_;
      break;
    case kRightBarButtonItemPosition:
      self.navigationItem.rightBarButtonItem = savedBarButtonItem_;
      [self.navigationItem.leftBarButtonItem setEnabled:YES];
      break;
    default:
      NOTREACHED();
      break;
  }
  savedBarButtonItem_.reset();
  savedBarButtonItemPosition_ = kUndefinedBarButtonItemPosition;
}

@end
