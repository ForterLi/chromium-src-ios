// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/ntp/feed_header_view_controller.h"

#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_constants.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Leading margin for title label. Its used to align with the Card leading
// margin.
const CGFloat kTitleHorizontalMargin = 19;
// Trailing margin for menu button. Its used to align with the Card trailing
// margin.
const CGFloat kMenuButtonHorizontalMargin = 14;
// Font size for label text in header.
const CGFloat kDiscoverFeedTitleFontSize = 16;
// Insets for header menu button.
const CGFloat kHeaderMenuButtonInsetTopAndBottom = 2;
const CGFloat kHeaderMenuButtonInsetSides = 2;
// The width of the feed content. Currently hard coded in Mulder.
// TODO(crbug.com/1085419): Get card width from Mulder.
const CGFloat kDiscoverFeedContentWith = 430;
// The height of the header container. The content is unaffected.
const CGFloat kFeedHeaderHeight = 40;
}

@interface FeedHeaderViewController ()

// Header constraints for when the feed is hidden.
@property(nonatomic, strong)
    NSArray<NSLayoutConstraint*>* feedHiddenConstraints;

// Title label element for the feed.
@property(nonatomic, strong) UILabel* titleLabel;

// Button for opening top-level feed menu.
// Redefined to not be readonly.
@property(nonatomic, strong) UIButton* menuButton;

// View containing elements of the header. Handles header sizing.
@property(nonatomic, strong) UIView* container;

@end

@implementation FeedHeaderViewController

- (instancetype)init {
  return [super initWithNibName:nil bundle:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.container = [[UIView alloc] init];

  self.view.translatesAutoresizingMaskIntoConstraints = NO;
  self.container.translatesAutoresizingMaskIntoConstraints = NO;

  self.titleLabel = [self createTitleLabel];
  self.menuButton = [self createMenuButton];

  [self.container addSubview:self.menuButton];
  [self.container addSubview:self.titleLabel];
  [self.view addSubview:self.container];

  [self applyHeaderConstraints];
}

#pragma mark - Setters

// Sets |titleText| and updates header label if it exists.
- (void)setTitleText:(NSString*)titleText {
  _titleText = titleText;
  if (self.titleLabel) {
    self.titleLabel.text = titleText;
    [self.titleLabel setNeedsDisplay];
  }
}

#pragma mark - Private

// Configures and returns the feed header's title label.
- (UILabel*)createTitleLabel {
  UILabel* titleLabel = [[UILabel alloc] init];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont systemFontOfSize:kDiscoverFeedTitleFontSize
                                      weight:UIFontWeightMedium];
  titleLabel.textColor = [UIColor colorNamed:kGrey700Color];
  titleLabel.adjustsFontForContentSizeCategory = YES;
  titleLabel.accessibilityIdentifier =
      ntp_home::DiscoverHeaderTitleAccessibilityID();
  titleLabel.text = self.titleText;
  return titleLabel;
}

// Configures and returns the feed header's menu button.
- (UIButton*)createMenuButton {
  UIButton* menuButton = [[UIButton alloc] init];
  menuButton.translatesAutoresizingMaskIntoConstraints = NO;
  menuButton.accessibilityIdentifier = kNTPFeedHeaderButtonIdentifier;
  menuButton.accessibilityLabel =
      l10n_util::GetNSString(IDS_IOS_DISCOVER_FEED_MENU_ACCESSIBILITY_LABEL);
  [menuButton
      setImage:[[UIImage imageNamed:@"infobar_settings_icon"]
                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
      forState:UIControlStateNormal];
  menuButton.tintColor = [UIColor colorNamed:kGrey600Color];
  menuButton.imageEdgeInsets = UIEdgeInsetsMake(
      kHeaderMenuButtonInsetTopAndBottom, kHeaderMenuButtonInsetSides,
      kHeaderMenuButtonInsetTopAndBottom, kHeaderMenuButtonInsetSides);
  return menuButton;
}

// Applies constraints for the feed header elements' positioning.
- (void)applyHeaderConstraints {
  [NSLayoutConstraint activateConstraints:@[
    // Anchor container.
    [self.view.heightAnchor constraintEqualToConstant:kFeedHeaderHeight],
    [self.container.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.container.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor],
    [self.container.centerXAnchor
        constraintEqualToAnchor:self.view.centerXAnchor],
    [self.container.widthAnchor
        constraintEqualToConstant:MIN(kDiscoverFeedContentWith,
                                      self.view.frame.size.width)],
    // Anchors title label and menu button.
    [self.titleLabel.leadingAnchor
        constraintEqualToAnchor:self.container.leadingAnchor
                       constant:kTitleHorizontalMargin],
    [self.titleLabel.trailingAnchor
        constraintLessThanOrEqualToAnchor:self.menuButton.leadingAnchor],
    [self.menuButton.trailingAnchor
        constraintEqualToAnchor:self.container.trailingAnchor
                       constant:-kMenuButtonHorizontalMargin],
    [self.titleLabel.centerYAnchor
        constraintEqualToAnchor:self.container.centerYAnchor],
    [self.menuButton.centerYAnchor
        constraintEqualToAnchor:self.container.centerYAnchor],
  ]];
}

@end