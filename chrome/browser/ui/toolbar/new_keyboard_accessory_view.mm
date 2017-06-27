// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/toolbar/new_keyboard_accessory_view.h"

#import <NotificationCenter/NotificationCenter.h>

#include "base/mac/foundation_util.h"
#include "ios/chrome/browser/experimental_flags.h"
#include "ios/chrome/browser/ui/commands/ios_command_ids.h"
#include "ios/chrome/browser/ui/rtl_geometry.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface NewKeyboardAccessoryView ()

@property(nonatomic, retain) NSArray<NSString*>* buttonTitles;
@property(nonatomic, weak) id<KeyboardAccessoryViewDelegate> delegate;

// Called when a keyboard shortcut button is pressed.
- (void)keyboardButtonPressed:(NSString*)title;
// Creates a button shortcut for |title|.
- (UIView*)shortcutButtonWithTitle:(NSString*)title;
// Creates a button with an icon based on |iconName|.
- (UIButton*)iconButton:(NSString*)iconName;

@end

@implementation NewKeyboardAccessoryView

// Unused by this implementation of |KeyboardAccessoryViewProtocol|.
@synthesize mode = _mode;

@synthesize buttonTitles = _buttonTitles;
@synthesize delegate = _delegate;

- (instancetype)initWithButtons:(NSArray<NSString*>*)buttonTitles
                       delegate:(id<KeyboardAccessoryViewDelegate>)delegate {
  const CGFloat kViewHeight = 44.0;
  CGFloat width = [[UIScreen mainScreen] bounds].size.width;
  // TODO(734512): Have the creator of the view define the size.
  CGRect frame = CGRectMake(0.0, 0.0, width, kViewHeight);

  self = [super initWithFrame:frame inputViewStyle:UIInputViewStyleKeyboard];
  if (self) {
    _buttonTitles = buttonTitles;
    _delegate = delegate;
    [self addSubviews];
  }
  return self;
}

- (void)addSubviews {
  if (!self.subviews.count)
    return;

  const CGFloat kButtonMinWidth = 34.0;
  const CGFloat kButtonHeight = 34.0;
  const CGFloat kBetweenShortcutButtonSpacing = 5.0;
  const CGFloat kBetweenSearchButtonSpacing = 12.0;
  const CGFloat kHorizontalMargin = 12.0;

  // Create and add stackview filled with the shortcut buttons.
  UIStackView* shortcutStackView = [[UIStackView alloc] init];
  shortcutStackView.translatesAutoresizingMaskIntoConstraints = NO;
  shortcutStackView.spacing = kBetweenShortcutButtonSpacing;
  for (NSString* title in self.buttonTitles) {
    UIView* button = [self shortcutButtonWithTitle:title];
    [button setTranslatesAutoresizingMaskIntoConstraints:NO];
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:kButtonMinWidth]
        .active = YES;
    [button.heightAnchor constraintEqualToConstant:kButtonHeight].active = YES;
    [shortcutStackView addArrangedSubview:button];
  }
  [self addSubview:shortcutStackView];

  // Create buttons for voice search and camera search.
  UIButton* voiceSearchButton =
      [self iconButton:@"keyboard_accessory_voice_search"];
  [voiceSearchButton addTarget:_delegate
                        action:@selector(keyboardAccessoryVoiceSearchTouchDown)
              forControlEvents:UIControlEventTouchDown];
  SetA11yLabelAndUiAutomationName(voiceSearchButton,
                                  IDS_IOS_KEYBOARD_ACCESSORY_VIEW_VOICE_SEARCH,
                                  @"Voice Search");
  [voiceSearchButton
             addTarget:_delegate
                action:@selector(keyboardAccessoryVoiceSearchTouchUpInside)
      forControlEvents:UIControlEventTouchUpInside];
  UIButton* cameraButton = [self iconButton:@"keyboard_accessory_qr_scanner"];
  [cameraButton addTarget:_delegate
                   action:@selector(keyboardAccessoryCameraSearchTouchUpInside)
         forControlEvents:UIControlEventTouchUpInside];
  SetA11yLabelAndUiAutomationName(
      cameraButton, IDS_IOS_KEYBOARD_ACCESSORY_VIEW_QR_CODE_SEARCH,
      @"QR code Search");

  // Create and add a stackview containing containing the buttons for voice
  // search and camera search.
  UIStackView* searchStackView = [[UIStackView alloc] init];
  searchStackView.translatesAutoresizingMaskIntoConstraints = NO;
  searchStackView.spacing = kBetweenSearchButtonSpacing;
  [searchStackView addArrangedSubview:voiceSearchButton];
  [searchStackView addArrangedSubview:cameraButton];
  [self addSubview:searchStackView];

  // Position the stack views.
  NSArray* constraints = @[
    @"H:|-horizontalMargin-[searchStackView]-(>=0)-[shortcutStackView]",
    @"[shortcutStackView]-horizontalMargin-|",
  ];
  NSDictionary* viewsDictionary = @{
    @"searchStackView" : searchStackView,
    @"shortcutStackView" : shortcutStackView,
  };
  NSDictionary* metrics = @{
    @"horizontalMargin" : @(kHorizontalMargin),
  };
  ApplyVisualConstraintsWithMetrics(constraints, viewsDictionary, metrics);
  AddSameCenterYConstraint(searchStackView, self);
  AddSameCenterYConstraint(shortcutStackView, self);
}

- (UIView*)shortcutButtonWithTitle:(NSString*)title {
  const CGFloat kHorizontalEdgeInset = 8;
  const CGFloat kButtonTitleFontSize = 16.0;
  UIColor* kTitleColorStateNormal = [UIColor colorWithWhite:0.0 alpha:1.0];
  UIColor* kTitleColorStateHighlighted = [UIColor colorWithWhite:0.0 alpha:0.3];

  UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
  [button setTitleColor:kTitleColorStateNormal forState:UIControlStateNormal];
  [button setTitleColor:kTitleColorStateHighlighted
               forState:UIControlStateHighlighted];

  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  button.contentEdgeInsets =
      UIEdgeInsetsMake(0, kHorizontalEdgeInset, 0, kHorizontalEdgeInset);
  button.clipsToBounds = YES;
  [button.titleLabel setFont:[UIFont systemFontOfSize:kButtonTitleFontSize
                                               weight:UIFontWeightMedium]];

  [button addTarget:self
                action:@selector(keyboardButtonPressed:)
      forControlEvents:UIControlEventTouchUpInside];
  button.isAccessibilityElement = YES;
  [button setAccessibilityLabel:title];
  return button;
}

- (UIButton*)iconButton:(NSString*)iconName {
  const CGFloat kButtonShadowOpacity = 0.35;
  const CGFloat kButtonShadowRadius = 1.0;
  const CGFloat kButtonShadowVerticalOffset = 1.0;

  UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
  [button setTranslatesAutoresizingMaskIntoConstraints:NO];
  UIImage* icon = [UIImage imageNamed:iconName];
  [button setImage:icon forState:UIControlStateNormal];
  button.layer.shadowColor = [UIColor blackColor].CGColor;
  button.layer.shadowOffset = CGSizeMake(0, kButtonShadowVerticalOffset);
  button.layer.shadowOpacity = kButtonShadowOpacity;
  button.layer.shadowRadius = kButtonShadowRadius;
  return button;
}

- (BOOL)enableInputClicksWhenVisible {
  return YES;
}

- (void)keyboardButtonPressed:(id)sender {
  UIButton* button = base::mac::ObjCCastStrict<UIButton>(sender);
  [[UIDevice currentDevice] playInputClick];
  [_delegate keyPressed:[button currentTitle]];
}

@end
