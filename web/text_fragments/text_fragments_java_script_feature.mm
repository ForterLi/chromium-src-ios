// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/text_fragments/text_fragments_java_script_feature.h"

#include <vector>

#import "ios/web/public/js_messaging/script_message.h"
#import "ios/web/public/js_messaging/web_frame.h"
#import "ios/web/public/js_messaging/web_frame_util.h"
#import "ios/web/text_fragments/text_fragments_manager_impl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const char kScriptName[] = "text_fragments_js";
const char kHandleFragmentsScript[] = "textFragments.handleTextFragments";

const double kMaxSelectorCount = 200.0;
const double kMinSelectorCount = 0.0;
}

namespace web {

TextFragmentsJavaScriptFeature::TextFragmentsJavaScriptFeature()
    : JavaScriptFeature(
          ContentWorld::kAnyContentWorld,
          {FeatureScript::CreateWithFilename(
              kScriptName,
              FeatureScript::InjectionTime::kDocumentStart,
              FeatureScript::TargetFrames::kMainFrame,
              FeatureScript::ReinjectionBehavior::kInjectOncePerWindow)}) {}

TextFragmentsJavaScriptFeature::~TextFragmentsJavaScriptFeature() = default;

// static
TextFragmentsJavaScriptFeature* TextFragmentsJavaScriptFeature::GetInstance() {
  static base::NoDestructor<TextFragmentsJavaScriptFeature> instance;
  return instance.get();
}

void TextFragmentsJavaScriptFeature::ProcessTextFragments(
    WebState* web_state,
    base::Value parsed_fragments,
    std::string background_color_hex_rgb,
    std::string foreground_color_hex_rgb) {
  DCHECK(web_state);
  auto* frame = web::GetMainFrame(web_state);
  DCHECK(frame);

  base::Value bg_color = background_color_hex_rgb.empty()
                             ? base::Value()
                             : base::Value(background_color_hex_rgb);
  base::Value fg_color = foreground_color_hex_rgb.empty()
                             ? base::Value()
                             : base::Value(foreground_color_hex_rgb);

  std::vector<base::Value> parameters;
  parameters.push_back(std::move(parsed_fragments));
  parameters.emplace_back(/*scroll=*/true);
  parameters.push_back(std::move(bg_color));
  parameters.push_back(std::move(fg_color));

  CallJavaScriptFunction(frame, kHandleFragmentsScript, parameters);
}

void TextFragmentsJavaScriptFeature::ScriptMessageReceived(
    WebState* web_state,
    const ScriptMessage& script_message) {
  auto* manager = TextFragmentsManagerImpl::FromWebState(web_state);
  if (!manager) {
    return;
  }

  base::Value* response = script_message.body();
  if (!response || !response->is_dict()) {
    return;
  }

  // Extract success metrics.
  absl::optional<double> optional_fragment_count =
      response->FindDoublePath("result.fragmentsCount");
  absl::optional<double> optional_success_count =
      response->FindDoublePath("result.successCount");

  // Since the response can't be trusted, don't log metrics if the results look
  // invalid.
  if (!optional_fragment_count ||
      optional_fragment_count.value() > kMaxSelectorCount ||
      optional_fragment_count.value() <= kMinSelectorCount) {
    return;
  }
  if (!optional_success_count ||
      optional_success_count.value() > kMaxSelectorCount ||
      optional_success_count.value() < kMinSelectorCount) {
    return;
  }
  if (optional_success_count.value() > optional_fragment_count.value()) {
    return;
  }

  int fragment_count = static_cast<int>(optional_fragment_count.value());
  int success_count = static_cast<int>(optional_success_count.value());

  manager->OnProcessingComplete(success_count, fragment_count);
}

}  // namespace web