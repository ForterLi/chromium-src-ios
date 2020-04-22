// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/overlays/common/alerts/alert_overlay_mediator.h"

#include "base/bind.h"
#import "ios/chrome/browser/overlays/public/common/alerts/alert_overlay.h"
#include "ios/chrome/browser/overlays/public/overlay_callback_manager.h"
#include "ios/chrome/browser/overlays/public/overlay_request.h"
#include "ios/chrome/browser/overlays/public/overlay_request_config.h"
#include "ios/chrome/browser/overlays/public/overlay_response_info.h"
#import "ios/chrome/browser/ui/alert_view/alert_action.h"
#import "ios/chrome/browser/ui/alert_view/test/fake_alert_consumer.h"
#import "ios/chrome/browser/ui/elements/text_field_configuration.h"
#import "ios/chrome/browser/ui/overlays/common/alerts/alert_overlay_mediator+alert_consumer_support.h"
#import "ios/chrome/browser/ui/overlays/common/alerts/test/alert_overlay_mediator_test.h"
#import "ios/chrome/browser/ui/overlays/common/alerts/test/fake_alert_overlay_mediator_data_source.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using alert_overlays::AlertRequest;
using alert_overlays::AlertResponse;
using alert_overlays::ButtonConfig;

namespace {
// Alert setup consts.
const size_t kButtonIndexOk = 0;
const size_t kTextFieldIndex = 0;

// Fake response for use in tests.
class FakeResponseInfo : public OverlayResponseInfo<FakeResponseInfo> {
 public:
  ~FakeResponseInfo() override {}

  // Whether the user tapped the OK button on the dialog.
  bool ok_button_tapped() const { return ok_button_tapped_; }
  // The text field input.
  NSString* input() const { return input_; }

 private:
  OVERLAY_USER_DATA_SETUP(FakeResponseInfo);
  FakeResponseInfo(bool ok_button_tapped, NSString* input)
      : ok_button_tapped_(ok_button_tapped), input_(input) {}

  const bool ok_button_tapped_ = false;
  NSString* const input_ = nil;
};
OVERLAY_USER_DATA_SETUP_IMPL(FakeResponseInfo);

// Creates an OverlayResponse with a FakeResponseInfo from one created with an
// AlertResponse.
std::unique_ptr<OverlayResponse> CreateFakeResponse(
    std::unique_ptr<OverlayResponse> alert_response) {
  AlertResponse* alert_info = alert_response->GetInfo<AlertResponse>();
  return OverlayResponse::CreateWithInfo<FakeResponseInfo>(
      alert_info->tapped_button_index() == kButtonIndexOk,
      alert_info->text_field_values()[kTextFieldIndex]);
}

// Fake request for use in tests.
class FakeRequestConfig : public OverlayResponseInfo<FakeRequestConfig> {
 public:
  ~FakeRequestConfig() override {}

 private:
  OVERLAY_USER_DATA_SETUP(FakeRequestConfig);
  FakeRequestConfig() {}

  void CreateAuxiliaryData(base::SupportsUserData* user_data) override {
    // Creates an AlertRequest with an OK and Cancel button and a single
    // text field.
    NSArray<TextFieldConfiguration*>* text_field_configs = @[
      [[TextFieldConfiguration alloc] initWithText:@""
                                       placeholder:@""
                           accessibilityIdentifier:@""
                                   secureTextEntry:NO],
    ];
    const std::vector<ButtonConfig> button_configs{
        ButtonConfig(@"OK"),
        ButtonConfig(@"Cancel", UIAlertActionStyleDefault)};
    AlertRequest::CreateForUserData(user_data, @"title", @"message",
                                    @"accessibility_identifier",
                                    text_field_configs, button_configs,
                                    base::BindRepeating(&CreateFakeResponse));
  }
};
OVERLAY_USER_DATA_SETUP_IMPL(FakeRequestConfig);
}  // namespace

// Tests that the AlertOverlayMediator's subclassing properties are correctly
// applied to the consumer.
TEST_F(AlertOverlayMediatorTest, SetUpConsumer) {
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<FakeRequestConfig>();
  AlertRequest* config = request->GetConfig<AlertRequest>();
  AlertOverlayMediator* mediator =
      [[AlertOverlayMediator alloc] initWithRequest:request.get()];
  SetMediator(mediator);
  EXPECT_NSEQ(config->title(), consumer().title);
  EXPECT_NSEQ(config->message(), consumer().message);
  EXPECT_NSEQ(config->accessibility_identifier(),
              consumer().alertAccessibilityIdentifier);
  EXPECT_NSEQ(config->text_field_configs(), consumer().textFieldConfigurations);
  for (size_t i = 0; i < config->button_configs().size(); ++i) {
    AlertAction* consumer_action = consumer().actions[i];
    const ButtonConfig& button_config = config->button_configs()[i];
    EXPECT_NSEQ(button_config.title, consumer_action.title);
    EXPECT_EQ(button_config.style, consumer_action.style);
  }
}

// Tests that AlertOverlayMediator successfully converts OverlayResponses
// created with AlertResponses into their feature-specific response.
TEST_F(AlertOverlayMediatorTest, ResponseConversion) {
  // Create a request with FakeRequestConfig and create the mediator for that
  // request.
  std::unique_ptr<OverlayRequest> request =
      OverlayRequest::CreateWithConfig<FakeRequestConfig>();
  AlertOverlayMediator* mediator =
      [[AlertOverlayMediator alloc] initWithRequest:request.get()];
  SetMediator(mediator);

  // Set up a fake datasource for the text field values.
  FakeAlertOverlayMediatorDataSource* data_source =
      [[FakeAlertOverlayMediatorDataSource alloc] init];
  data_source.textFieldValues = @[ @"TextFieldValue" ];
  mediator.dataSource = data_source;

  // Simulate a tap on the OK button.
  AlertAction* ok_button_action = consumer().actions[kButtonIndexOk];
  ok_button_action.handler(ok_button_action);

  // Verify that the request's completion callback is a FakeResponseInfo with
  // the expected values.
  OverlayResponse* response =
      request->GetCallbackManager()->GetCompletionResponse();
  ASSERT_TRUE(response);
  FakeResponseInfo* info = response->GetInfo<FakeResponseInfo>();
  ASSERT_TRUE(info);
  EXPECT_TRUE(info->ok_button_tapped());
  EXPECT_NSEQ(data_source.textFieldValues[0], info->input());
}
