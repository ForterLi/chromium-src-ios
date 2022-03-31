// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_view_controller.h"

#include "base/mac/foundation_util.h"
#include "base/metrics/user_metrics.h"
#include "base/metrics/user_metrics_action.h"
#import "ios/chrome/browser/net/crurl.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/settings/cells/settings_image_detail_text_item.h"
#import "ios/chrome/browser/ui/settings/privacy/privacy_constants.h"
#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_view_controller_delegate.h"
#import "ios/chrome/browser/ui/settings/utils/pref_backed_boolean.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#include "ios/chrome/grit/ios_chromium_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#import "net/base/mac/url_conversions.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

typedef NSArray<TableViewItem*>* ItemArray;

namespace {
// List of sections.
typedef NS_ENUM(NSInteger, SectionIdentifier) {
  SectionIdentifierPrivacySafeBrowsing = kSectionIdentifierEnumZero,
};
}  // namespace

@interface PrivacySafeBrowsingViewController ()

// All the items for the safe browsing section.
@property(nonatomic, strong) ItemArray safeBrowsingItems;

@end

@implementation PrivacySafeBrowsingViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.tableView.accessibilityIdentifier = kPrivacySafeBrowsingTableViewId;
  self.title = l10n_util::GetNSString(IDS_IOS_PRIVACY_SAFE_BROWSING_TITLE);
  [self loadModel];
}

#pragma mark - SettingsControllerProtocol

- (void)reportDismissalUserAction {
  // TODO(crbug.com/1307428): Add UMA recording
}

- (void)reportBackUserAction {
  // TODO(crbug.com/1307428): Add UMA recording
}

#pragma mark - PrivacySafeBrowsingConsumer

- (void)reloadSection {
  if (!self.tableViewModel) {
    // No need to reload since the model has not been loaded yet.
    return;
  }
  TableViewModel* model = self.tableViewModel;
  NSUInteger sectionIndex =
      [model sectionForSectionIdentifier:SectionIdentifierPrivacySafeBrowsing];
  NSIndexSet* sections = [NSIndexSet indexSetWithIndex:sectionIndex];
  [self.tableView reloadSections:sections
                withRowAnimation:UITableViewRowAnimationNone];
}

- (void)setSafeBrowsingItems:(ItemArray)safeBrowsingItems {
  _safeBrowsingItems = safeBrowsingItems;
}

#pragma mark - CollectionViewController

- (void)loadModel {
  [super loadModel];
  TableViewModel* model = self.tableViewModel;
  [model addSectionWithIdentifier:SectionIdentifierPrivacySafeBrowsing];
  for (TableViewItem* item in self.safeBrowsingItems) {
    [model addItem:item
        toSectionWithIdentifier:SectionIdentifierPrivacySafeBrowsing];
  }
}

#pragma mark - UIViewController

- (void)didMoveToParentViewController:(UIViewController*)parent {
  [super didMoveToParentViewController:parent];
  if (!parent) {
    [self.presentationDelegate privacySafeBrowsingViewControllerDidRemove:self];
  }
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidDismiss:
    (UIPresentationController*)presentationController {
  // TODO(crbug.com/1307428): Add UMA recording
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [super tableView:tableView didSelectRowAtIndexPath:indexPath];
  TableViewModel* model = self.tableViewModel;
  TableViewItem* selectedItem = [model itemAtIndexPath:indexPath];
  [self.modelDelegate didSelectItem:selectedItem];

  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView*)tableView
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath*)indexPath {
  TableViewModel* model = self.tableViewModel;
  TableViewItem* selectedItem = [model itemAtIndexPath:indexPath];
  [self.modelDelegate didTapAccessoryView:selectedItem];
}

@end