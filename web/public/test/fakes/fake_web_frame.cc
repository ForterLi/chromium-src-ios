// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/web/public/test/fakes/fake_web_frame.h"

#include <string>
#include <utility>

#include "base/bind.h"
#include "base/callback.h"
#include "base/json/json_writer.h"
#include "base/task/post_task.h"
#include "base/values.h"
#include "ios/web/public/thread/web_task_traits.h"

namespace web {

// Frame ids are base16 string of 128 bit numbers.
const char kMainFakeFrameId[] = "1effd8f52a067c8d3a01762d3c41dfd1";
const char kInvalidFrameId[] = "1effd8f52a067c8d3a01762d3c4;dfd1";
const char kChildFakeFrameId[] = "1effd8f52a067c8d3a01762d3c41dfd2";
const char kChildFakeFrameId2[] = "1effd8f52a067c8d3a01762d3c41dfd3";

FakeWebFrame::FakeWebFrame(const std::string& frame_id,
                           bool is_main_frame,
                           GURL security_origin)
    : frame_id_(frame_id),
      is_main_frame_(is_main_frame),
      security_origin_(security_origin) {}

FakeWebFrame::~FakeWebFrame() {}

std::string FakeWebFrame::GetFrameId() const {
  return frame_id_;
}
bool FakeWebFrame::IsMainFrame() const {
  return is_main_frame_;
}
GURL FakeWebFrame::GetSecurityOrigin() const {
  return security_origin_;
}
bool FakeWebFrame::CanCallJavaScriptFunction() const {
  return can_call_function_;
}

bool FakeWebFrame::CallJavaScriptFunction(
    const std::string& name,
    const std::vector<base::Value>& parameters) {
  if (!can_call_function_) {
    return false;
  }
  std::string javascript_call = std::string("__gCrWeb." + name + "(");
  bool first = true;
  for (auto& param : parameters) {
    if (!first) {
      javascript_call += ", ";
    }
    first = false;
    std::string paramString;
    base::JSONWriter::Write(param, &paramString);
    javascript_call += paramString;
  }
  javascript_call += ");";
  java_script_calls_.push_back(javascript_call);
  return can_call_function_;
}

bool FakeWebFrame::CallJavaScriptFunction(
    const std::string& name,
    const std::vector<base::Value>& parameters,
    base::OnceCallback<void(const base::Value*)> callback,
    base::TimeDelta timeout) {
  bool success = CallJavaScriptFunction(name, parameters);
  if (!success) {
    return false;
  }

  if (force_timeout_) {
    base::PostDelayedTask(FROM_HERE, {web::WebThread::UI},
                          base::BindOnce(std::move(callback), nullptr),
                          timeout);
  } else {
    const base::Value* js_result = result_map_[name].get();
    base::PostTask(FROM_HERE, {WebThread::UI},
                   base::BindOnce(std::move(callback), js_result));
  }
  return true;
}

void FakeWebFrame::AddJsResultForFunctionCall(
    std::unique_ptr<base::Value> js_result,
    const std::string& function_name) {
  result_map_[function_name] = std::move(js_result);
}

// FakeMainWebFrame
FakeMainWebFrame::FakeMainWebFrame(GURL security_origin)
    : FakeWebFrame(kMainFakeFrameId, /*is_main_frame=*/true, security_origin) {}

FakeMainWebFrame::~FakeMainWebFrame() {}

// FakeChildWebFrame
FakeChildWebFrame::FakeChildWebFrame(GURL security_origin)
    : FakeWebFrame(kChildFakeFrameId,
                   /*is_main_frame=*/false,
                   security_origin) {}

FakeChildWebFrame::~FakeChildWebFrame() {}

}  // namespace web
