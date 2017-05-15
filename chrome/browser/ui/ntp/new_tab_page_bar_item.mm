// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/ntp/new_tab_page_bar_item.h"

#include "base/mac/objc_release_properties.h"

@implementation NewTabPageBarItem {
  // Title of the button.
  NSString* title_;
  // A numeric identifier.
  NSUInteger identifier_;
  // Tabbar image.
  UIImage* image_;
  // New tab page view.
  __unsafe_unretained UIView* view_;  // weak
}

@synthesize title = title_;
@synthesize identifier = identifier_;
@synthesize image = image_;
@synthesize view = view_;

+ (NewTabPageBarItem*)newTabPageBarItemWithTitle:(NSString*)title
                                      identifier:(NSUInteger)identifier
                                           image:(UIImage*)image {
  NewTabPageBarItem* item = [[[NewTabPageBarItem alloc] init] autorelease];
  if (item) {
    item.title = title;
    item.identifier = identifier;
    item.image = image;
  }
  return item;
}

- (void)dealloc {
  base::mac::ReleaseProperties(self);
  [super dealloc];
}

@end
