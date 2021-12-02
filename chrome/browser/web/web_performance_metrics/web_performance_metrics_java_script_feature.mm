// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/web/web_performance_metrics/web_performance_metrics_java_script_feature.h"

#include "base/logging.h"
#include "base/metrics/histogram_macros.h"
#include "base/no_destructor.h"
#include "base/strings/strcat.h"
#include "base/values.h"
#include "ios/chrome/browser/web/web_performance_metrics/web_performance_metrics_java_script_feature_util.h"
#include "ios/chrome/browser/web/web_performance_metrics/web_performance_metrics_tab_helper.h"
#include "ios/web/public/js_messaging/java_script_feature_util.h"
#include "ios/web/public/js_messaging/script_message.h"
#include "ios/web/public/js_messaging/web_frame_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const char kPerformanceMetricsScript[] = "web_performance_metrics_js";
const char kWebPerformanceMetricsScriptName[] = "WebPerformanceMetricsHandler";
}

WebPerformanceMetricsJavaScriptFeature::WebPerformanceMetricsJavaScriptFeature()
    : JavaScriptFeature(ContentWorld::kAnyContentWorld,
                        {FeatureScript::CreateWithFilename(
                            kPerformanceMetricsScript,
                            FeatureScript::InjectionTime::kDocumentStart,
                            FeatureScript::TargetFrames::kAllFrames)}) {}

WebPerformanceMetricsJavaScriptFeature::
    ~WebPerformanceMetricsJavaScriptFeature() = default;

WebPerformanceMetricsJavaScriptFeature*
WebPerformanceMetricsJavaScriptFeature::GetInstance() {
  static base::NoDestructor<WebPerformanceMetricsJavaScriptFeature> instance;
  return instance.get();
}

absl::optional<std::string>
WebPerformanceMetricsJavaScriptFeature::GetScriptMessageHandlerName() const {
  return kWebPerformanceMetricsScriptName;
}

void WebPerformanceMetricsJavaScriptFeature::ScriptMessageReceived(
    web::WebState* web_state,
    const web::ScriptMessage& message) {
  DCHECK(web_state);

  // Verify that the message is well-formed before using it
  if (!message.body()->is_dict()) {
    return;
  }

  std::string* metric = message.body()->FindStringKey("metric");
  if (!metric || metric->empty()) {
    return;
  }

  absl::optional<double> value = message.body()->FindDoubleKey("value");
  if (!value) {
    return;
  }

  absl::optional<double> frame_navigation_start_time =
      message.body()->FindDoubleKey("frameNavigationStartTime");
  if (!frame_navigation_start_time) {
    return;
  }

  LogRelativeFirstContentfulPaint(value.value(), message.is_main_frame());
  LogAggregateFirstContentfulPaint(web_state,
                                   frame_navigation_start_time.value(),
                                   value.value(), message.is_main_frame());
}

void WebPerformanceMetricsJavaScriptFeature::LogRelativeFirstContentfulPaint(
    double value,
    bool is_main_frame) {
  if (is_main_frame) {
    UMA_HISTOGRAM_TIMES("IOS.Frame.FirstContentfulPaint.MainFrame",
                        base::Milliseconds(value));
  } else {
    UMA_HISTOGRAM_TIMES("IOS.Frame.FirstContentfulPaint.SubFrame",
                        base::Milliseconds(value));
  }
}

void WebPerformanceMetricsJavaScriptFeature::LogAggregateFirstContentfulPaint(
    web::WebState* web_state,
    double frame_navigation_start_time,
    double relative_first_contentful_paint,
    bool is_main_frame) {
  WebPerformanceMetricsTabHelper* tab_helper =
      WebPerformanceMetricsTabHelper::FromWebState(web_state);

  if (!tab_helper) {
    return;
  }

  const double aggregate =
      tab_helper->GetAggregateAbsoluteFirstContentfulPaint();

  if (is_main_frame) {
    // Finds the earliest First Contentful Paint time across
    // main and subframes and logs that time to UMA.
    web_performance_metrics::FirstContentfulPaint frame = {
        frame_navigation_start_time, relative_first_contentful_paint,
        web_performance_metrics::CalculateAbsoluteFirstContentfulPaint(
            frame_navigation_start_time, relative_first_contentful_paint)};
    base::TimeDelta aggregate_first_contentful_paint =
        web_performance_metrics::CalculateAggregateFirstContentfulPaint(
            aggregate, frame);

    UMA_HISTOGRAM_TIMES("PageLoad.PaintTiming.NavigationToFirstContentfulPaint",
                        aggregate_first_contentful_paint);
  } else if (aggregate == std::numeric_limits<double>::max()) {
    tab_helper->SetAggregateAbsoluteFirstContentfulPaint(
        web_performance_metrics::CalculateAbsoluteFirstContentfulPaint(
            frame_navigation_start_time, relative_first_contentful_paint));
  }
}
