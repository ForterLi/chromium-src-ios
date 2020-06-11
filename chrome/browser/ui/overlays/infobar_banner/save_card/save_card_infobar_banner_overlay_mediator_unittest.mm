// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/overlays/infobar_banner/save_card/save_card_infobar_banner_overlay_mediator.h"

#include "base/bind.h"
#include "base/feature_list.h"
#include "base/guid.h"
#include "base/strings/sys_string_conversions.h"
#include "base/test/scoped_feature_list.h"
#include "components/autofill/core/browser/autofill_client.h"
#include "components/autofill/core/browser/autofill_test_utils.h"
#include "components/autofill/core/browser/data_model/credit_card.h"
#include "components/autofill/core/browser/payments/autofill_save_card_infobar_delegate_mobile.h"
#include "components/infobars/core/infobar_feature.h"
#include "components/prefs/pref_service.h"
#include "ios/chrome/browser/infobars/infobar_ios.h"
#import "ios/chrome/browser/overlays/public/infobar_banner/save_card_infobar_banner_overlay_request_config.h"
#import "ios/chrome/browser/ui/infobars/banners/test/fake_infobar_banner_consumer.h"
#import "ios/chrome/browser/ui/infobars/infobar_feature.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using save_card_infobar_overlays::SaveCardBannerRequestConfig;

// Test fixture for SaveCardInfobarBannerOverlayMediator.
class SaveCardInfobarBannerOverlayMediatorTest : public PlatformTest {
 public:
  SaveCardInfobarBannerOverlayMediatorTest() {
    feature_list_.InitWithFeatures({kIOSInfobarUIReboot},
                                   {kInfobarUIRebootOnlyiOS13});
  }

 private:
  base::test::ScopedFeatureList feature_list_;
};

// Tests that a SaveCardInfobarBannerOverlayMediator correctly sets up its
// consumer.
TEST_F(SaveCardInfobarBannerOverlayMediatorTest, SetUpConsumer) {
  // Create an InfoBarIOS with a ConfirmInfoBarDelegate.
  autofill::CreditCard credit_card(base::GenerateGUID(),
                                   "https://www.example.com/");
  std::unique_ptr<PrefService> prefs = autofill::test::PrefServiceForTesting();
  std::unique_ptr<autofill::AutofillSaveCardInfoBarDelegateMobile>
      passed_delegate =
          std::make_unique<autofill::AutofillSaveCardInfoBarDelegateMobile>(
              /*upload=*/false,
              autofill::AutofillClient::SaveCreditCardOptions(), credit_card,
              autofill::LegalMessageLines(),
              autofill::AutofillClient::UploadSaveCardPromptCallback(),
              base::BindOnce(
                  ^(autofill::AutofillClient::SaveCardOfferUserDecision
                        user_decision){
                  }),
              prefs.get());
  autofill::AutofillSaveCardInfoBarDelegateMobile* delegate =
      passed_delegate.get();
  InfoBarIOS infobar(InfobarType::kInfobarTypeSaveCard,
                     std::move(passed_delegate));

  // Package the infobar into an OverlayRequest, then create a mediator that
  // uses this request in order to set up a fake consumer.
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<SaveCardBannerRequestConfig>(&infobar);
  SaveCardInfobarBannerOverlayMediator* mediator =
      [[SaveCardInfobarBannerOverlayMediator alloc]
          initWithRequest:request.get()];
  FakeInfobarBannerConsumer* consumer =
      [[FakeInfobarBannerConsumer alloc] init];
  mediator.consumer = consumer;
  // Verify that the infobar was set up properly.
  NSString* title = base::SysUTF16ToNSString(delegate->GetMessageText());
  EXPECT_NSEQ(title, consumer.titleText);
  EXPECT_NSEQ(base::SysUTF16ToNSString(
                  delegate->GetButtonLabel(ConfirmInfoBarDelegate::BUTTON_OK)),
              consumer.buttonText);
  EXPECT_NSEQ(base::SysUTF16ToNSString(delegate->card_label()),
              consumer.subtitleText);
}
