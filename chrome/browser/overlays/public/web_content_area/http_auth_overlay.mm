// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/overlays/public/web_content_area/http_auth_overlay.h"

#include "base/bind.h"
#import "base/strings/sys_string_conversions.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/overlays/public/common/alerts/alert_overlay.h"
#import "ios/chrome/browser/ui/elements/text_field_configuration.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using alert_overlays::AlertRequest;
using alert_overlays::AlertResponse;
using alert_overlays::ButtonConfig;

namespace {
// The index of the alert for the OK button.
const size_t kButtonIndexOk = 0;

// Indices of the text fields.
const size_t kTextFieldIndexUsername = 0;
const size_t kTextFieldIndexPassword = 1;

// Creates an OverlayRequest with HTTPAuthOverlayResponseInfo from one created
// with an AlertResponse.
std::unique_ptr<OverlayResponse> CreateHttpAuthResponse(
    std::unique_ptr<OverlayResponse> alert_response) {
  AlertResponse* alert_info = alert_response->GetInfo<AlertResponse>();
  if (!alert_info || alert_info->tapped_button_index() != kButtonIndexOk)
    return nullptr;

  NSArray<NSString*>* text_field_values = alert_info->text_field_values();
  return OverlayResponse::CreateWithInfo<HTTPAuthOverlayResponseInfo>(
      base::SysNSStringToUTF8(text_field_values[kTextFieldIndexUsername]),
      base::SysNSStringToUTF8(text_field_values[kTextFieldIndexPassword]));
}
}  // namespace

#pragma mark - HTTPAuthOverlayRequestConfig

OVERLAY_USER_DATA_SETUP_IMPL(HTTPAuthOverlayRequestConfig);

HTTPAuthOverlayRequestConfig::HTTPAuthOverlayRequestConfig(
    const GURL& url,
    const std::string& message,
    const std::string& default_username)
    : url_(url), message_(message), default_username_(default_username) {}

HTTPAuthOverlayRequestConfig::~HTTPAuthOverlayRequestConfig() = default;

void HTTPAuthOverlayRequestConfig::CreateAuxiliaryData(
    base::SupportsUserData* user_data) {
  NSString* alert_title =
      l10n_util::GetNSStringWithFixup(IDS_LOGIN_DIALOG_TITLE);
  NSString* alert_message = base::SysUTF8ToNSString(message());
  NSString* username_placeholder =
      l10n_util::GetNSString(IDS_IOS_HTTP_LOGIN_DIALOG_USERNAME_PLACEHOLDER);
  NSString* password_placeholder =
      l10n_util::GetNSString(IDS_IOS_HTTP_LOGIN_DIALOG_PASSWORD_PLACEHOLDER);
  NSArray<TextFieldConfiguration*>* alert_text_field_configs = @[
    [[TextFieldConfiguration alloc]
                   initWithText:base::SysUTF8ToNSString(default_username())
                    placeholder:username_placeholder
        accessibilityIdentifier:nil
                secureTextEntry:NO],
    [[TextFieldConfiguration alloc] initWithText:nil
                                     placeholder:password_placeholder
                         accessibilityIdentifier:nil
                                 secureTextEntry:YES],
  ];
  NSString* ok_label =
      l10n_util::GetNSStringWithFixup(IDS_LOGIN_DIALOG_OK_BUTTON_LABEL);
  NSString* cancel_label = l10n_util::GetNSString(IDS_CANCEL);
  const std::vector<ButtonConfig> alert_button_configs{
      ButtonConfig(ok_label),
      ButtonConfig(cancel_label, UIAlertActionStyleCancel)};
  AlertRequest::CreateForUserData(
      user_data, alert_title, alert_message,
      /*accessibility_identifier=*/nil, alert_text_field_configs,
      alert_button_configs, base::BindRepeating(&CreateHttpAuthResponse));
}

#pragma mark - HTTPAuthOverlayResponseInfo

OVERLAY_USER_DATA_SETUP_IMPL(HTTPAuthOverlayResponseInfo);

HTTPAuthOverlayResponseInfo::HTTPAuthOverlayResponseInfo(
    const std::string& username,
    const std::string& password)
    : username_(username), password_(password) {}

HTTPAuthOverlayResponseInfo::~HTTPAuthOverlayResponseInfo() = default;
