// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/stack_view/stack_card.h"

#include "base/logging.h"
#import "ios/chrome/browser/ui/rtl_geometry.h"
#import "ios/chrome/browser/ui/stack_view/card_view.h"
#import "ios/chrome/browser/ui/ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface StackCard () {
  __weak id<StackCardViewProvider> _viewProvider;
  CardView* _view;
}

// The pixel-aligned frame generated by applying |self.layout| under the current
// language direction.
@property(nonatomic, readonly) CGRect frame;

// Applies |self.layout| to the underlying CardView if it exists.
- (void)applyLayout;

@end

@implementation StackCard

@synthesize layout = _layout;
@synthesize synchronizeView = _synchronizeView;
@synthesize isActiveTab = _isActiveTab;
@synthesize tabID = _tabID;

- (instancetype)initWithViewProvider:(id<StackCardViewProvider>)viewProvider {
  if ((self = [super init])) {
    DCHECK(viewProvider);
    _viewProvider = viewProvider;
    _synchronizeView = YES;
  }
  return self;
}

- (instancetype)init {
  NOTREACHED();
  return nil;
}

- (void)releaseView {
  if (self.viewIsLive)
    _view = nil;
}

#pragma mark - Properties

- (CardView*)view {
  if (!_view) {
    _view = [_viewProvider cardViewWithFrame:self.frame forStackCard:self];
    _view.isActiveTab = _isActiveTab;
  }
  return _view;
}

- (void)setLayout:(LayoutRect)layout {
  if (!LayoutRectEqualToRect(_layout, layout)) {
    _layout = layout;
    [self applyLayout];
  }
}

- (CGSize)size {
  return self.layout.size;
}

- (void)setSize:(CGSize)size {
  CGSize oldSize = self.size;
  if (!CGSizeEqualToSize(oldSize, size)) {
    _layout.size = size;
    _layout.position.leading += (oldSize.width - size.width) / 2.0;
    _layout.position.originY += (oldSize.height - size.height) / 2.0;
    [self applyLayout];
  }
}

- (void)setSynchronizeView:(BOOL)synchronizeView {
  if (_synchronizeView != synchronizeView) {
    _synchronizeView = synchronizeView;
    [self applyLayout];
  }
}

- (void)setIsActiveTab:(BOOL)isActiveTab {
  _isActiveTab = isActiveTab;
  _view.isActiveTab = _isActiveTab;
}

- (BOOL)viewIsLive {
  return _view != nil;
}

- (CGRect)frame {
  return AlignRectOriginAndSizeToPixels(LayoutRectGetRect(self.layout));
}

#pragma mark -

- (void)applyLayout {
  if (!self.viewIsLive || !self.synchronizeView)
    return;
  self.view.frame = self.frame;
}

@end
