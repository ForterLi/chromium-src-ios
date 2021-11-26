// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin_sync/signin_sync_view_controller.h"

#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/ui/authentication/authentication_constants.h"
#import "ios/chrome/browser/ui/authentication/views/identity_button_control.h"
#import "ios/chrome/browser/ui/elements/activity_overlay_view.h"
#import "ios/chrome/browser/ui/settings/elements/enterprise_info_popover_view_controller.h"
#import "ios/chrome/common/string_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/elements/popover_label_view_controller.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#include "ios/chrome/grit/ios_google_chrome_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Width of the identity control if nothing is contraining it.
constexpr CGFloat kIdentityControlMaxWidth = 327;
constexpr CGFloat kIdentityTopMargin = 16;
constexpr CGFloat kMarginBetweenContents = 12;
constexpr CGFloat kTopSpecificContentVerticalMargin = 24;

// URL for the learn more text.
// Need to set a value so the delegate gets called.
NSString* const kLearnMoreUrl = @"internal://learn-more";

NSString* const kLearnMoreTextViewAccessibilityIdentifier =
    @"kLearnMoreTextViewAccessibilityIdentifier";

}  // namespace

@interface SigninSyncViewController () <UITextViewDelegate>

// Button controlling the display of the selected identity.
@property(nonatomic, strong) IdentityButtonControl* identityControl;

// The string to be displayed in the "Cotinue" button to personalize it. Usually
// the given name, or the email address if no given name.
@property(nonatomic, copy) NSString* personalizedButtonPrompt;

// Scrim displayed above the view when the UI is disabled.
@property(nonatomic, strong) ActivityOverlayView* overlay;

// Text view that displays an attributed string with the "Learn More" link that
// opens a popover.
@property(nonatomic, strong) UITextView* learnMoreTextView;

// Popover shown when "Details" link is tapped.
@property(nonatomic, strong)
    EnterpriseInfoPopoverViewController* bubbleViewController;

@end

@implementation SigninSyncViewController
@dynamic delegate;

#pragma mark - Public

- (void)viewDidLoad {
  self.view.accessibilityIdentifier = kSigninSyncScreenAccessibilityIdentifier;
  self.isTallBanner = NO;
  self.scrollToEndMandatory = YES;
  self.readMoreString =
      l10n_util::GetNSString(IDS_IOS_FIRST_RUN_SCREEN_READ_MORE);

  int titleTextID = IDS_IOS_FIRST_RUN_SIGNIN_TITLE;
  [self.delegate signinSyncViewController:self addConsentStringID:titleTextID];
  self.titleText = l10n_util::GetNSString(titleTextID);

  int subtitleTextID;
  if (self.enterpriseSignInRestrictions == kNoEnterpriseRestriction) {
    subtitleTextID = IDS_IOS_FIRST_RUN_SIGNIN_SUBTITLE;
  } else {
    subtitleTextID = IDS_IOS_FIRST_RUN_SIGNIN_SUBTITLE_MANAGED;
  }
  [self.delegate signinSyncViewController:self addConsentStringID:titleTextID];
  self.subtitleText = l10n_util::GetNSString(subtitleTextID);

  if (!self.primaryActionString) {
    // |primaryActionString| could already be set using the consumer methods.
    self.primaryActionString =
        l10n_util::GetNSString(IDS_IOS_FIRST_RUN_SIGNIN_SIGN_IN_ACTION);
  }
  // Set the consent ID associated with the primary action string to
  // |self.activateSyncButtonID| regardless of its current value because this
  // is the only string that will be used in the button when enabling sync.
  [self.delegate signinSyncViewController:self
                       addConsentStringID:self.activateSyncButtonID];

  if (self.identityControlInTop) {
    [self.topSpecificContentView addSubview:self.identityControl];
  } else {
    [self.specificContentView addSubview:self.identityControl];
  }

  UILabel* syncInfoLabel = [self syncInfoLabel];
  // TODO(crbug.com/1270491) don't show the advanced settings button when there
  // is no account available/selected.
  UIButton* advanceSyncSettingsButton = [self advanceSyncSettingsButton];

  // Add content specific to sync.
  [self.specificContentView addSubview:syncInfoLabel];
  [self.specificContentView addSubview:advanceSyncSettingsButton];

  // Add the Learn More text label if there are enterprise sign-in or sync
  // restrictions.
  if (self.enterpriseSignInRestrictions != kNoEnterpriseRestriction) {
    self.learnMoreTextView.delegate = self;
    [self.specificContentView addSubview:self.learnMoreTextView];

    [NSLayoutConstraint activateConstraints:@[
      [self.learnMoreTextView.bottomAnchor
          constraintEqualToAnchor:self.specificContentView.bottomAnchor],
      [self.learnMoreTextView.centerXAnchor
          constraintEqualToAnchor:self.specificContentView.centerXAnchor],
      [self.learnMoreTextView.widthAnchor
          constraintLessThanOrEqualToAnchor:self.specificContentView
                                                .widthAnchor],
    ]];
  }

  self.bannerImage = [UIImage imageNamed:@"sync_screen_banner"];
  self.secondaryActionString =
      l10n_util::GetNSString(IDS_IOS_FIRST_RUN_SIGNIN_DONT_SIGN_IN);

  // Set constraints specific to the identity control button that don't change.
  NSLayoutConstraint* widthConstraint = [self.identityControl.widthAnchor
      constraintEqualToConstant:kIdentityControlMaxWidth];
  widthConstraint.priority = UILayoutPriorityDefaultHigh;
  [NSLayoutConstraint activateConstraints:@[
    [self.identityControl.centerXAnchor
        constraintEqualToAnchor:self.identityControl.superview.centerXAnchor],
    [self.identityControl.widthAnchor
        constraintLessThanOrEqualToAnchor:self.identityControl.superview
                                              .widthAnchor],
    widthConstraint,
  ]];

  // Set constraints that are dependent on the position of the identity
  // controller button and sign-in restrictions.

  if (self.identityControlInTop) {
    [self.identityControl.bottomAnchor
        constraintEqualToAnchor:self.identityControl.superview.bottomAnchor
                       constant:-kTopSpecificContentVerticalMargin]
        .active = YES;
    [self.identityControl.topAnchor
        constraintEqualToAnchor:self.identityControl.superview.topAnchor
                       constant:kTopSpecificContentVerticalMargin]
        .active = YES;
    if (self.enterpriseSignInRestrictions == kNoEnterpriseRestriction) {
      [advanceSyncSettingsButton.bottomAnchor
          constraintLessThanOrEqualToAnchor:advanceSyncSettingsButton.superview
                                                .bottomAnchor]
          .active = YES;
    } else {
      [advanceSyncSettingsButton.bottomAnchor
          constraintLessThanOrEqualToAnchor:self.learnMoreTextView.topAnchor]
          .active = YES;
    }
  } else {
    [advanceSyncSettingsButton.bottomAnchor
        constraintLessThanOrEqualToAnchor:self.identityControl.topAnchor]
        .active = YES;
    if (self.enterpriseSignInRestrictions == kNoEnterpriseRestriction) {
      [self.identityControl.bottomAnchor
          constraintEqualToAnchor:self.identityControl.superview.bottomAnchor]
          .active = YES;
    } else {
      [self.learnMoreTextView.topAnchor
          constraintEqualToAnchor:self.identityControl.bottomAnchor
                         constant:kIdentityTopMargin]
          .active = YES;
    }
  }

  // Set constraints specific to the content related to sync.
  [NSLayoutConstraint activateConstraints:@[
    [syncInfoLabel.topAnchor
        constraintEqualToAnchor:self.specificContentView.topAnchor],
    [syncInfoLabel.centerXAnchor
        constraintEqualToAnchor:self.specificContentView.centerXAnchor],
    [syncInfoLabel.widthAnchor
        constraintLessThanOrEqualToAnchor:self.specificContentView.widthAnchor],
    [advanceSyncSettingsButton.topAnchor
        constraintEqualToAnchor:syncInfoLabel.bottomAnchor
                       constant:kMarginBetweenContents],
    [advanceSyncSettingsButton.centerXAnchor
        constraintEqualToAnchor:self.specificContentView.centerXAnchor],
    [advanceSyncSettingsButton.widthAnchor
        constraintLessThanOrEqualToAnchor:self.specificContentView.widthAnchor],
  ]];

  // Call super after setting up the strings and others, as required per super
  // class.
  [super viewDidLoad];
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];

  // Close popover when font size changed for accessibility because it does not
  // resize properly and the arrow is not aligned.
  if (self.bubbleViewController) {
    [self.bubbleViewController dismissViewControllerAnimated:YES
                                                  completion:nil];
  }
}

#pragma mark - Properties

- (IdentityButtonControl*)identityControl {
  if (!_identityControl) {
    _identityControl = [[IdentityButtonControl alloc] initWithFrame:CGRectZero];
    _identityControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_identityControl addTarget:self
                         action:@selector(identityButtonControlTapped:forEvent:)
               forControlEvents:UIControlEventTouchUpInside];

    // Setting the content hugging priority isn't working, so creating a
    // low-priority constraint to make sure that the view is as small as
    // possible.
    NSLayoutConstraint* heightConstraint =
        [_identityControl.heightAnchor constraintEqualToConstant:0];
    heightConstraint.priority = UILayoutPriorityDefaultLow - 1;
    heightConstraint.active = YES;
  }
  return _identityControl;
}

- (ActivityOverlayView*)overlay {
  if (!_overlay) {
    _overlay = [[ActivityOverlayView alloc] init];
    _overlay.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return _overlay;
}

- (UITextView*)learnMoreTextView {
  if (!_learnMoreTextView) {
    _learnMoreTextView = [[UITextView alloc] init];
    _learnMoreTextView.backgroundColor = UIColor.clearColor;
    _learnMoreTextView.scrollEnabled = NO;
    _learnMoreTextView.editable = NO;
    _learnMoreTextView.adjustsFontForContentSizeCategory = YES;
    _learnMoreTextView.textContainerInset = UIEdgeInsetsZero;
    _learnMoreTextView.textContainer.lineFragmentPadding = 0;
    _learnMoreTextView.accessibilityIdentifier =
        kLearnMoreTextViewAccessibilityIdentifier;

    _learnMoreTextView.linkTextAttributes =
        @{NSForegroundColorAttributeName : [UIColor colorNamed:kBlueColor]};
    _learnMoreTextView.translatesAutoresizingMaskIntoConstraints = NO;

    NSMutableParagraphStyle* paragraphStyle =
        [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;

    NSDictionary* textAttributes = @{
      NSForegroundColorAttributeName : [UIColor colorNamed:kTextSecondaryColor],
      NSFontAttributeName :
          [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote],
      NSParagraphStyleAttributeName : paragraphStyle
    };

    NSDictionary* linkAttributes =
        @{NSLinkAttributeName : [NSURL URLWithString:kLearnMoreUrl]};

    NSAttributedString* learnMoreTextAttributedString =
        AttributedStringFromStringWithLink(
            l10n_util::GetNSString(IDS_IOS_ENTERPRISE_MANAGED_SIGNIN_DETAILS),
            textAttributes, linkAttributes);

    _learnMoreTextView.attributedText = learnMoreTextAttributedString;
  }
  return _learnMoreTextView;
}

// Creates and returns the label that gives detailed information about sync.
- (UILabel*)syncInfoLabel {
  UILabel* label = [[UILabel alloc] init];
  label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
  label.numberOfLines = 0;
  label.textAlignment = NSTextAlignmentCenter;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.adjustsFontForContentSizeCategory = YES;
  int textID = IDS_IOS_FIRST_RUN_SYNC_SCREEN_CONTENT;
  [self.delegate signinSyncViewController:self addConsentStringID:textID];
  label.text = l10n_util::GetNSString(textID);
  label.textColor = [UIColor colorNamed:kGrey600Color];
  label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
  return label;
}

// Creates and returns the button to show advanced settings.
- (UIButton*)advanceSyncSettingsButton {
  UIButton* button = [[UIButton alloc] init];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.titleLabel.numberOfLines = 0;
  button.titleLabel.adjustsFontForContentSizeCategory = YES;
  [button.titleLabel
      setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
  int stringID = IDS_IOS_FIRST_RUN_SYNC_SCREEN_ADVANCE_SETTINGS;
  [self.delegate signinSyncViewController:self addConsentStringID:stringID];
  [button setTitle:l10n_util::GetNSString(stringID)
          forState:UIControlStateNormal];
  [button setTitleColor:[UIColor colorNamed:kBlueColor]
               forState:UIControlStateNormal];

  [button addTarget:self
                action:@selector(showAdvanceSyncSettings)
      forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (int)activateSyncButtonID {
  return IDS_IOS_FIRST_RUN_SIGNIN_CONTINUE_AS;
}

#pragma mark - SignInSyncConsumer

- (void)setSelectedIdentityUserName:(NSString*)userName
                              email:(NSString*)email
                          givenName:(NSString*)givenName
                             avatar:(UIImage*)avatar {
  DCHECK(email);
  DCHECK(avatar);
  self.personalizedButtonPrompt = givenName ? givenName : email;
  [self updateUIForIdentityAvailable:YES];
  [self.identityControl setIdentityName:userName email:email];
  [self.identityControl setIdentityAvatar:avatar];
}

- (void)noIdentityAvailable {
  [self updateUIForIdentityAvailable:NO];
}

- (void)setUIEnabled:(BOOL)UIEnabled {
  if (UIEnabled) {
    [self.overlay removeFromSuperview];
  } else {
    [self.view addSubview:self.overlay];
    AddSameConstraints(self.view, self.overlay);
    [self.overlay.indicator startAnimating];
  }
}

#pragma mark - Private

// Callback for |identityControl|.
- (void)identityButtonControlTapped:(id)sender forEvent:(UIEvent*)event {
  UITouch* touch = event.allTouches.anyObject;
  [self.delegate signinSyncViewController:self
               showAccountPickerFromPoint:[touch locationInView:nil]];
}

// Updates the UI to adapt for |identityAvailable| or not.
- (void)updateUIForIdentityAvailable:(BOOL)identityAvailable {
  self.identityControl.hidden = !identityAvailable;
  if (identityAvailable) {
    self.primaryActionString = l10n_util::GetNSStringF(
        self.activateSyncButtonID,
        base::SysNSStringToUTF16(self.personalizedButtonPrompt));
  } else {
    // TODO(crbug.com/1271355): We need to determine that string. We may want
    // to change it.
    self.primaryActionString =
        l10n_util::GetNSString(IDS_IOS_FIRST_RUN_SIGNIN_SIGN_IN_ACTION);
  }
}

// Appends |restrictionString| to |existingString|, adding padding if needed.
- (void)appendRestrictionString:(NSString*)restrictionString
                       toString:(NSMutableString*)existingString {
  NSString* padding = @"\n\n";
  if ([existingString length])
    [existingString appendString:padding];
  [existingString appendString:restrictionString];
}

// Called when the sync advanced settings button is tapped.
- (void)showAdvanceSyncSettings {
  [self.delegate signinSyncViewControllerDidTapOnSettings:self];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView*)textView
    shouldInteractWithURL:(NSURL*)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction {
  DCHECK(textView == self.learnMoreTextView);

  NSMutableString* detailsMessage = [[NSMutableString alloc] init];
  if (self.enterpriseSignInRestrictions & kEnterpriseRestrictAccounts) {
    [self appendRestrictionString:
              l10n_util::GetNSString(
                  IDS_IOS_ENTERPRISE_RESTRICTED_ACCOUNTS_TO_PATTERNS_MESSAGE)
                         toString:detailsMessage];
  }
  if (self.enterpriseSignInRestrictions & kEnterpriseSyncTypesListDisabled) {
    [self appendRestrictionString:l10n_util::GetNSString(
                                      IDS_IOS_ENTERPRISE_MANAGED_SYNC)
                         toString:detailsMessage];
  }

  // Open signin popover.
  self.bubbleViewController = [[EnterpriseInfoPopoverViewController alloc]
             initWithMessage:detailsMessage
              enterpriseName:nil  // TODO(crbug.com/1251986): Remove this
                                  // variable.
      isPresentingFromButton:NO
            addLearnMoreLink:NO];
  [self presentViewController:self.bubbleViewController
                     animated:YES
                   completion:nil];

  // Set the anchor and arrow direction of the bubble.
  self.bubbleViewController.popoverPresentationController.sourceView =
      self.learnMoreTextView;
  self.bubbleViewController.popoverPresentationController.sourceRect =
      TextViewLinkBound(textView, characterRange);
  self.bubbleViewController.popoverPresentationController
      .permittedArrowDirections =
      UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;

  // The handler is already handling the tap.
  return NO;
}

- (void)textViewDidChangeSelection:(UITextView*)textView {
  // Always force the |selectedTextRange| to |nil| to prevent users from
  // selecting text. Setting the |selectable| property to |NO| doesn't help
  // since it makes links inside the text view untappable.
  textView.selectedTextRange = nil;
}

@end
