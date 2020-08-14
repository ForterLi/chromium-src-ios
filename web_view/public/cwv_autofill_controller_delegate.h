// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_PUBLIC_CWV_AUTOFILL_CONTROLLER_DELEGATE_H_
#define IOS_WEB_VIEW_PUBLIC_CWV_AUTOFILL_CONTROLLER_DELEGATE_H_

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CWVAutofillController;
@class CWVAutofillForm;
@class CWVAutofillFormSuggestion;
@class CWVCreditCard;
@class CWVCreditCardExpirationFixer;
@class CWVCreditCardNameFixer;
@class CWVCreditCardSaver;
@class CWVCreditCardVerifier;
@class CWVPassword;

// User decision for saving / updating password.
// Note: CWVPasswordUserDecisionNever is only used in saving scenarios.
typedef NS_ENUM(NSInteger, CWVPasswordUserDecision) {
  CWVPasswordUserDecisionNotThisTime =
      0,                         // Do not save / update password this time.
  CWVPasswordUserDecisionNever,  // Never save password for this site.
  CWVPasswordUserDecisionYes,    // Save / update password.
};

// All possible leak type combinations.
// Keep up to date with password_manager::CredentialLeakFlags in
// components/password_manager/core/browser/leak_detection_dialog_utils.h.
typedef NS_OPTIONS(NSInteger, CWVPasswordLeakType) {
  // The leaked password is currently saved.
  CWVPasswordLeakTypeSaved = 1 << 0,
  // The leaked password is also used on other sites.
  CWVPasswordLeakTypeUsedOnOtherSites = 1 << 1,
  // The user is syncing passwords with normal encryption.
  CWVPasswordLeakTypeSyncingNormally = 1 << 2,
};

// Protocol to receive callbacks related to autofill.
// |fieldIdentifier| identifies the html field. Generated by
// __gCrWeb.form.getFieldIdentifier in form.js.
// |fieldType| is the 'type' attribute of the html field.
// |formName| is the 'name' attribute of a html <form>.
// |value| is the 'value' attribute of the html field.
// Example:
// <form name='_formName_'>
//   <input id='_fieldIdentifier_' value='_value_' type='_fieldType_'>
// </form>
@protocol CWVAutofillControllerDelegate<NSObject>

@optional

// Called when a form field element receives a "focus" event.
// |userInitiated| is YES if field was focused as a result of user interaction.
- (void)autofillController:(CWVAutofillController*)autofillController
    didFocusOnFieldWithIdentifier:(NSString*)fieldIdentifier
                        fieldType:(NSString*)fieldType
                         formName:(NSString*)formName
                          frameID:(NSString*)frameID
                            value:(NSString*)value
                    userInitiated:(BOOL)userInitiated;

// Called when a form field element receives an "input" event.
// |userInitiated| is YES if field received input as a result of user
// interaction.
- (void)autofillController:(CWVAutofillController*)autofillController
    didInputInFieldWithIdentifier:(NSString*)fieldIdentifier
                        fieldType:(NSString*)fieldType
                         formName:(NSString*)formName
                          frameID:(NSString*)frameID
                            value:(NSString*)value
                    userInitiated:(BOOL)userInitiated;

// Called when a form field element receives a "blur" (un-focused) event.
// |userInitiated| is YES if field was blurred as a result of user interaction.
- (void)autofillController:(CWVAutofillController*)autofillController
    didBlurOnFieldWithIdentifier:(NSString*)fieldIdentifier
                       fieldType:(NSString*)fieldType
                        formName:(NSString*)formName
                         frameID:(NSString*)frameID
                           value:(NSString*)value
                   userInitiated:(BOOL)userInitiated;

// Called when a form was submitted.
// |userInitiated| is YES if form was submitted as a result of user interaction.
- (void)autofillController:(CWVAutofillController*)autofillController
     didSubmitFormWithName:(NSString*)formName
                   frameID:(NSString*)frameID
             userInitiated:(BOOL)userInitiated;

// Called when |forms| are found in a frame with |frameID|.
// Will be called after initial load and after any form mutations.
// Always includes all forms in the frame.
- (void)autofillController:(CWVAutofillController*)autofillController
              didFindForms:(NSArray<CWVAutofillForm*>*)forms
                   frameID:(NSString*)frameID;

// Called when it is possible to save a new credit card. This is usually called
// after a new card was entered in a form and submitted.
// |saver| encapsulates information needed to assist with this save attempt.
// Life time of |saver| should be managed by the delegate.
- (void)autofillController:(CWVAutofillController*)autofillController
    saveCreditCardWithSaver:(CWVCreditCardSaver*)saver;

// Called if the card holder's name needs to be confirmed by the user before the
// card can be saved. This can happen if a user doesn't have a GPay account or
// attempted to save a credit card without providing a name for it.
// |fixer| encapsulates information needed to assist with this fix attempt.
// Life time of |fixer| should be managed by the delegate.
- (void)autofillController:(CWVAutofillController*)autofillController
    confirmCreditCardNameWithFixer:(CWVCreditCardNameFixer*)fixer;

// Called if the card's expiration needs to be corrected before the the card can
// be saved. This can happen if a user attempted to save a credit card with an
// expired expiration date.
// |fixer| encapsulates information needed to assist with this fix attempt.
// Life time of |fixer| should be managed by the delegate.
- (void)autofillController:(CWVAutofillController*)autofillController
    confirmCreditCardExpirationWithFixer:(CWVCreditCardExpirationFixer*)fixer;

// Called when the user needs to use |verifier| to verify a credit card.
// Lifetime of |verifier| should be managed by the delegate.
- (void)autofillController:(CWVAutofillController*)autofillController
    verifyCreditCardWithVerifier:(CWVCreditCardVerifier*)verifier;

// Called when user needs to decide on whether or not to save the |password|.
// This can happen when user successfully logs into a web site with a new
// username.
// Pass user decision to |decisionHandler|. This block should be called only
// once if user made the decision, or not get called if user ignores the prompt.
// Not implementing it is equivalent of not calling |decisionHandler|.
- (void)autofillController:(CWVAutofillController*)autofillController
    decideSavePolicyForPassword:(CWVPassword*)password
                decisionHandler:
                    (void (^)(CWVPasswordUserDecision decision))decisionHandler;

// Called when user needs to decide on whether or not to update the |password|.
// This can happen when user successfully logs into a web site with a new
// password and an existing username.
// Pass user decision to |decisionHandler|. This block should be called only
// once if user made the decision, or not get called if user ignores the prompt.
// Not implementing it is equivalent of not calling |decisionHandler|.
- (void)autofillController:(CWVAutofillController*)autofillController
    decideUpdatePolicyForPassword:(CWVPassword*)password
                  decisionHandler:(void (^)(CWVPasswordUserDecision decision))
                                      decisionHandler;

// Called if a submitted username and password combination is determined to be
// leaked for |URL|. |leakType| provides additional context of the leak.
- (void)autofillController:(CWVAutofillController*)autofillController
    notifyUserOfPasswordLeakOnURL:(NSURL*)URL
                         leakType:(CWVPasswordLeakType)leakType;

@end

NS_ASSUME_NONNULL_END

#endif  // IOS_WEB_VIEW_PUBLIC_CWV_AUTOFILL_CONTROLLER_DELEGATE_H_
