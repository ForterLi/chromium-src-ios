// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/toolbar/clean/toolbar_view.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation ToolbarView

@synthesize delegate = _delegate;

- (void)setFrame:(CGRect)frame {
  [super setFrame:frame];
  [self.delegate toolbarViewFrameChanged];
}

@end
