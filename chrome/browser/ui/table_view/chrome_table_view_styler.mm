// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation ChromeTableViewStyler

@synthesize tableViewBackgroundColor = _tableViewBackgroundColor;
@synthesize cellTitleColor = _cellTitleColor;
@synthesize headerFooterTitleColor = _headerFooterTitleColor;

- (instancetype)init {
  if ((self = [super init])) {
    _tableViewBackgroundColor = [UIColor whiteColor];
  }
  return self;
}

@end
