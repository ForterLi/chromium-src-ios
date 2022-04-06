// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_enhanced_protection_mediator.h"

#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/settings/cells/settings_image_detail_text_item.h"
#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_constants.h"
#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_enhanced_protection_consumer.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

typedef NSArray<TableViewItem*>* ItemArray;

namespace {
// List of item types.
typedef NS_ENUM(NSInteger, ItemType) {
  ItemTypeShield = kItemTypeEnumZero,
};
}  // namespace

@interface SafeBrowsingEnhancedProtectionMediator ()

// All the items for the enhanced safe browsing section.
@property(nonatomic, strong, readonly)
    ItemArray safeBrowsingEnhancedProtectionItems;

@end

@implementation SafeBrowsingEnhancedProtectionMediator

@synthesize safeBrowsingEnhancedProtectionItems =
    _safeBrowsingEnhancedProtectionItems;

#pragma mark - Properties

- (ItemArray)safeBrowsingEnhancedProtectionItems {
  if (!_safeBrowsingEnhancedProtectionItems) {
    NSMutableArray* items = [NSMutableArray array];
    SettingsImageDetailTextItem* shieldIconItem = [self
             detailItemWithType:ItemTypeShield
                     detailText:
                         IDS_IOS_SAFE_BROWSING_ENHANCED_PROTECTION_BULLET_ONE
        accessibilityIdentifier:kSafeBrowsingEnhancedProtectionShieldCellId];
    [items addObject:shieldIconItem];

    _safeBrowsingEnhancedProtectionItems = items;
  }
  return _safeBrowsingEnhancedProtectionItems;
}

- (void)setConsumer:(id<SafeBrowsingEnhancedProtectionConsumer>)consumer {
  if (_consumer == consumer)
    return;
  _consumer = consumer;
  [_consumer setSafeBrowsingEnhancedProtectionItems:
                 self.safeBrowsingEnhancedProtectionItems];
}

#pragma mark - Private

// Creates item that will show what Enhanced Protection entails.
- (SettingsImageDetailTextItem*)detailItemWithType:(NSInteger)type
                                        detailText:(NSInteger)detailText
                           accessibilityIdentifier:
                               (NSString*)accessibilityIdentifier {
  SettingsImageDetailTextItem* detailItem =
      [[SettingsImageDetailTextItem alloc] initWithType:type];
  detailItem.detailText = l10n_util::GetNSString(detailText);
  detailItem.accessibilityIdentifier = accessibilityIdentifier;

  return detailItem;
}

@end
