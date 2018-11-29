// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/autofill/form_input_accessory_view_controller.h"

#include "base/mac/foundation_util.h"
#include "base/metrics/histogram_macros.h"
#include "components/autofill/core/common/autofill_features.h"
#import "ios/chrome/browser/autofill/form_input_accessory_view.h"
#import "ios/chrome/browser/autofill/form_suggestion_view.h"
#import "ios/chrome/browser/ui/autofill/manual_fill/manual_fill_accessory_view_controller.h"
#include "ios/chrome/browser/ui/util/ui_util.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui_util/constraints_ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace autofill {
CGFloat const kInputAccessoryHeight = 44.0f;
}  // namespace autofill

@interface FormInputAccessoryViewController () <
    ManualFillAccessoryViewControllerDelegate>

// Grey view used as the background of the keyboard to fix
// http://crbug.com/847523
@property(nonatomic, strong) UIView* grayBackgroundView;

// The keyboard replacement view, if any.
@property(nonatomic, weak) UIView* keyboardReplacementView;

// The custom view that should be shown in the input accessory view.
@property(nonatomic, strong) FormInputAccessoryView* inputAccessoryView;

// The leading view with the suggestions in FormInputAccessoryView.
@property(nonatomic, strong) FormSuggestionView* formSuggestionView;

// If this view controller is paused it shouldn't add its views to the keyboard.
@property(nonatomic, getter=isPaused) BOOL paused;

// The manual fill accessory view controller to add at the end of the
// suggestions.
@property(nonatomic, strong, readonly)
    ManualFillAccessoryViewController* manualFillAccessoryViewController;

// Delegate to handle interactions with the manual fill buttons.
@property(nonatomic, readonly, weak)
    id<ManualFillAccessoryViewControllerDelegate>
        manualFillAccessoryViewControllerDelegate;

// Called when the keyboard will or did change frame.
- (void)keyboardWillOrDidChangeFrame:(NSNotification*)notification;

@end

@implementation FormInputAccessoryViewController {
  // Last registered keyboard rectangle.
  CGRect _keyboardFrame;

  // Whether suggestions have previously been shown.
  BOOL _suggestionsHaveBeenShown;
}

@synthesize addressButtonHidden = _addressButtonHidden;
@synthesize creditCardButtonHidden = _creditCardButtonHidden;
@synthesize formInputNextButtonEnabled = _formInputNextButtonEnabled;
@synthesize formInputPreviousButtonEnabled = _formInputPreviousButtonEnabled;
@synthesize navigationDelegate = _navigationDelegate;
@synthesize passwordButtonHidden = _passwordButtonHidden;

#pragma mark - Life Cycle

- (instancetype)initWithManualFillAccessoryViewControllerDelegate:
    (id<ManualFillAccessoryViewControllerDelegate>)
        manualFillAccessoryViewControllerDelegate {
  self = [super init];
  if (self) {
    _paused = YES;
    _manualFillAccessoryViewControllerDelegate =
        manualFillAccessoryViewControllerDelegate;
    if (autofill::features::IsPasswordManualFallbackEnabled()) {
      _manualFillAccessoryViewController =
          [[ManualFillAccessoryViewController alloc] initWithDelegate:self];
    }

    _suggestionsHaveBeenShown = NO;
    if (IsIPadIdiom()) {
      _grayBackgroundView = [[UIView alloc] init];
      _grayBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
      // This color was obtained by try and error.
      _grayBackgroundView.backgroundColor =
          [[UIColor alloc] initWithRed:206 / 255.f
                                 green:212 / 255.f
                                  blue:217 / 255.f
                                 alpha:1];

    }
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillOrDidChangeFrame:)
               name:UIKeyboardWillChangeFrameNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillOrDidChangeFrame:)
               name:UIKeyboardDidChangeFrameNotification
             object:nil];
  }
  return self;
}

#pragma mark - Public

- (void)presentView:(UIView*)view {
  if (self.paused) {
    return;
  }
  DCHECK(view);
  DCHECK(!view.superview);
  UIView* keyboardView = [self getKeyboardView];
  view.accessibilityViewIsModal = YES;
  [keyboardView.superview addSubview:view];
  UIView* constrainingView =
      [self recursiveGetKeyboardConstraintView:keyboardView];
  DCHECK(constrainingView);
  view.translatesAutoresizingMaskIntoConstraints = NO;
  AddSameConstraints(view, constrainingView);
  self.keyboardReplacementView = view;
  UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, view);
}

- (void)unlockManualFallbackView {
  [self.formSuggestionView unlockTrailingView];
}

- (void)lockManualFallbackView {
  [self.formSuggestionView lockTrailingView];
}

- (void)resetManualFallbackIcons {
  [self.manualFillAccessoryViewController reset];
}

#pragma mark - FormInputAccessoryConsumer

- (void)showAccessorySuggestions:(NSArray<FormSuggestion*>*)suggestions
                suggestionClient:(id<FormSuggestionClient>)suggestionClient
              isHardwareKeyboard:(BOOL)hardwareKeyboard {
  // On ipad if the keyboard isn't visible don't show the custom view.
  if (IsIPadIdiom() &&
      (CGRectIntersection([UIScreen mainScreen].bounds, _keyboardFrame)
               .size.height == 0 ||
       CGRectEqualToRect(_keyboardFrame, CGRectZero))) {
    [self removeCustomInputAccessoryView];
    return;
  }

  // Check that |manualFillAccessoryViewController| was not instantiated if flag
  // is disabled. And return early if there are no suggestions on iPad.
  if (!autofill::features::IsPasswordManualFallbackEnabled()) {
    DCHECK(!self.manualFillAccessoryViewController);
    if (IsIPadIdiom()) {
      // On iPad, there's no inputAccessoryView available, so we attach the
      // custom view directly to the keyboard view instead. If this is a form
      // suggestion view and no suggestions have been triggered yet, don't show
      // the custom view.
      if (suggestions && !_suggestionsHaveBeenShown && !suggestions.count) {
        [self removeCustomInputAccessoryView];
        return;
      }
      _suggestionsHaveBeenShown = YES;
    }
  }

  // Create the views if they don't exist already.
  if (!self.formSuggestionView) {
    self.formSuggestionView = [[FormSuggestionView alloc] init];
  }

  [self.formSuggestionView updateClient:suggestionClient
                            suggestions:suggestions];

  if (!self.inputAccessoryView) {
    self.inputAccessoryView = [[FormInputAccessoryView alloc] init];
    if (IsIPadIdiom()) {
      [self.inputAccessoryView
          setUpWithLeadingView:self.formSuggestionView
            customTrailingView:self.manualFillAccessoryViewController.view];
    } else {
      self.formSuggestionView.trailingView =
          self.manualFillAccessoryViewController.view;
      [self.inputAccessoryView setUpWithLeadingView:self.formSuggestionView
                                 navigationDelegate:self.navigationDelegate];
      self.inputAccessoryView.nextButton.enabled =
          self.formInputNextButtonEnabled;
      self.inputAccessoryView.previousButton.enabled =
          self.formInputPreviousButtonEnabled;
    }
  }

  // On iPhones, when using a hardware keyboard, for most models, there's no
  // space to show suggestions because of the on-screen menu button.
  self.inputAccessoryView.leadingView.hidden = hardwareKeyboard;

  [self addInputAccessoryViewIfNeeded];
}

- (void)restoreOriginalKeyboardView {
  [self.manualFillAccessoryViewController reset];
  [self removeCustomInputAccessoryView];
  [self.keyboardReplacementView removeFromSuperview];
  self.keyboardReplacementView = nil;
}

- (void)pauseCustomKeyboardView {
  [self removeCustomInputAccessoryView];
  [self.keyboardReplacementView removeFromSuperview];
  self.paused = YES;
}

- (void)continueCustomKeyboardView {
  self.paused = NO;
}

- (void)removeAnimationsOnKeyboardView {
  // Work Around. On focus event, keyboardReplacementView is animated but the
  // keyboard isn't. Cancel the animation to match the keyboard behavior
  if (self.keyboardReplacementView.superview) {
    [self.keyboardReplacementView.layer removeAllAnimations];
  }
}

#pragma mark - Setters

- (void)setPasswordButtonHidden:(BOOL)passwordButtonHidden {
  _passwordButtonHidden = passwordButtonHidden;
  self.manualFillAccessoryViewController.passwordButtonHidden =
      passwordButtonHidden;
}

- (void)setAddressButtonHidden:(BOOL)addressButtonHidden {
  _addressButtonHidden = addressButtonHidden;
  self.manualFillAccessoryViewController.addressButtonHidden =
      addressButtonHidden;
}

- (void)setCreditCardButtonHidden:(BOOL)creditCardButtonHidden {
  _creditCardButtonHidden = creditCardButtonHidden;
  self.manualFillAccessoryViewController.creditCardButtonHidden =
      creditCardButtonHidden;
}

- (void)setFormInputNextButtonEnabled:(BOOL)formInputNextButtonEnabled {
  if (formInputNextButtonEnabled == _formInputNextButtonEnabled) {
    return;
  }
  _formInputNextButtonEnabled = formInputNextButtonEnabled;
  self.inputAccessoryView.nextButton.enabled = _formInputNextButtonEnabled;
}

- (void)setFormInputPreviousButtonEnabled:(BOOL)formInputPreviousButtonEnabled {
  if (formInputPreviousButtonEnabled == _formInputPreviousButtonEnabled) {
    return;
  }
  _formInputPreviousButtonEnabled = formInputPreviousButtonEnabled;
  self.inputAccessoryView.previousButton.enabled =
      _formInputPreviousButtonEnabled;
}

#pragma mark - Private

// Removes the custom views related to the input accessory view.
- (void)removeCustomInputAccessoryView {
  [self.inputAccessoryView removeFromSuperview];
  [self.grayBackgroundView removeFromSuperview];
}

// This searches in a keyboard view hierarchy for the best candidate to
// constrain a view to the keyboard.
- (UIView*)recursiveGetKeyboardConstraintView:(UIView*)view {
  for (UIView* subview in view.subviews) {
    // TODO(crbug.com/845472): verify this on iOS 10-12 and all devices.
    // Currently only tested on X-iOS12, 6+-iOS11 and 7+-iOS10. iPhoneX, iOS 11
    // and 12 uses "Dock" and iOS 10 uses "Backdrop". iPhone6+, iOS 11 uses
    // "Dock".
    if ([NSStringFromClass([subview class]) containsString:@"Dock"] ||
        [NSStringFromClass([subview class]) containsString:@"Backdrop"]) {
      return subview;
    }
    UIView* found = [self recursiveGetKeyboardConstraintView:subview];
    if (found) {
      return found;
    }
  }
  return nil;
}

- (UIView*)getKeyboardView {
  NSArray* windows = [UIApplication sharedApplication].windows;
  if (windows.count < 2)
    return nil;

  UIWindow* window;
  if (autofill::features::IsPasswordManualFallbackEnabled()) {
    // TODO(crbug.com/845472): verify this works on iPad with split view before
    // making this the default.
    window = windows.lastObject;
  } else {
    window = windows[1];
  }

  for (UIView* subview in window.subviews) {
    if ([NSStringFromClass([subview class]) rangeOfString:@"PeripheralHost"]
            .location != NSNotFound) {
      return subview;
    }
    if ([NSStringFromClass([subview class]) rangeOfString:@"SetContainer"]
            .location != NSNotFound) {
      for (UIView* subsubview in subview.subviews) {
        if ([NSStringFromClass([subsubview class]) rangeOfString:@"SetHost"]
                .location != NSNotFound) {
          return subsubview;
        }
      }
    }
  }

  return nil;
}

- (void)keyboardWillOrDidChangeFrame:(NSNotification*)notification {
  CGRect keyboardFrame =
      [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  UIView* keyboardView = [self getKeyboardView];
  CGRect windowRect = keyboardView.window.bounds;
  // On iPad when the keyboard is undocked, on iOS 11 and 12,
  // `UIKeyboard*HideNotification` or `UIKeyboard*ShowNotification` are not
  // being sent. So the check for all devices is done here.
  if (CGRectContainsRect(windowRect, keyboardFrame)) {
    _keyboardFrame = keyboardFrame;
    // Make sure the input accessory is there if needed.
    [self addInputAccessoryViewIfNeeded];
    [self addCustomKeyboardViewIfNeeded];
  } else {
    _keyboardFrame = CGRectZero;
  }
  // On ipad we hide the views so they don't stick around at the bottom. Only
  // needed on iPad because we add the view directly to the keyboard view.
  if (IsIPadIdiom() && self.inputAccessoryView) {
    if (CGRectEqualToRect(_keyboardFrame, CGRectZero)) {
      self.inputAccessoryView.hidden = true;
      self.grayBackgroundView.hidden = true;
    } else {
      self.inputAccessoryView.hidden = false;
      self.grayBackgroundView.hidden = false;
    }
  }
}

- (void)addCustomKeyboardViewIfNeeded {
  if (self.isPaused) {
    return;
  }
  if (self.keyboardReplacementView && !self.keyboardReplacementView.superview) {
    [self presentView:self.keyboardReplacementView];
  }
}

// Adds the inputAccessoryView and the backgroundView (on iPads), if those are
// not already in the hierarchy.
- (void)addInputAccessoryViewIfNeeded {
  if (self.isPaused) {
    return;
  }
  if (self.inputAccessoryView && !self.inputAccessoryView.superview) {
    if (IsIPadIdiom()) {
      UIView* keyboardView = [self getKeyboardView];
      self.inputAccessoryView.translatesAutoresizingMaskIntoConstraints = NO;
      [keyboardView addSubview:self.inputAccessoryView];
      [NSLayoutConstraint activateConstraints:@[
        [self.inputAccessoryView.leadingAnchor
            constraintEqualToAnchor:keyboardView.leadingAnchor],
        [self.inputAccessoryView.trailingAnchor
            constraintEqualToAnchor:keyboardView.trailingAnchor],
        [self.inputAccessoryView.bottomAnchor
            constraintEqualToAnchor:keyboardView.topAnchor],
        [self.inputAccessoryView.heightAnchor
            constraintEqualToConstant:autofill::kInputAccessoryHeight]
      ]];
      if (!self.grayBackgroundView.superview) {
        [keyboardView addSubview:self.grayBackgroundView];
        [keyboardView sendSubviewToBack:self.grayBackgroundView];
        AddSameConstraints(self.grayBackgroundView, keyboardView);
      }
    } else {
      UIResponder* firstResponder = GetFirstResponder();
      if (firstResponder.inputAccessoryView) {
        [firstResponder.inputAccessoryView addSubview:self.inputAccessoryView];
        AddSameConstraints(self.inputAccessoryView,
                           firstResponder.inputAccessoryView);
      }
    }
  }
}

#pragma mark - ManualFillAccessoryViewControllerDelegate

- (void)keyboardButtonPressed {
  [self.manualFillAccessoryViewControllerDelegate keyboardButtonPressed];
}

- (void)accountButtonPressed:(UIButton*)sender {
  UMA_HISTOGRAM_COUNTS_100("ManualFallback.VisibleSuggestions.OpenProfiles",
                           self.formSuggestionView.suggestions.count);
  [self.manualFillAccessoryViewControllerDelegate accountButtonPressed:sender];
}

- (void)cardButtonPressed:(UIButton*)sender {
  UMA_HISTOGRAM_COUNTS_100("ManualFallback.VisibleSuggestions.OpenCreditCards",
                           self.formSuggestionView.suggestions.count);
  [self.manualFillAccessoryViewControllerDelegate cardButtonPressed:sender];
}

- (void)passwordButtonPressed:(UIButton*)sender {
  UMA_HISTOGRAM_COUNTS_100("ManualFallback.VisibleSuggestions.OpenPasswords",
                           self.formSuggestionView.suggestions.count);
  [self.manualFillAccessoryViewControllerDelegate passwordButtonPressed:sender];
}

@end
