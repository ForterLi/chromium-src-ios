// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import SwiftUI
import WidgetKit

struct SearchWidget: Widget {
  let kind: String = "Search_Widget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      SearchWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(
      Text("IDS_IOS_WIDGET_KIT_EXTENSION_SEARCH_DISPLAY_NAME")
    )
    .description(Text("IDS_IOS_WIDGET_KIT_EXTENSION_SEARCH_DESCRIPTION"))
    .supportedFamilies([.systemSmall])
  }
}

struct SearchWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    ZStack {
      Color("widget_background_color")
        .unredacted()
      VStack(alignment: .leading, spacing: 0) {
        ZStack {
          RoundedRectangle(cornerRadius: 26)
            .frame(height: 52)
            .foregroundColor(Color("widget_search_bar_color"))
          HStack(spacing: 0) {
            Image("widget_chrome_logo")
              .clipShape(Circle())
              .padding(.leading, 8)
              .unredacted()
            Spacer()
          }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding([.leading, .trailing], 11)
        .padding(.top, 16)
        Spacer()
        Text("IDS_IOS_WIDGET_KIT_EXTENSION_SEARCH_TITLE")
          .foregroundColor(Color("widget_text_color"))
          .fontWeight(.semibold)
          .font(.subheadline)
          .padding([.leading, .bottom, .trailing], 16)
      }
    }
    .widgetURL(WidgetConstants.SearchWidget.url)
    .accessibility(
      label: Text("IDS_IOS_WIDGET_KIT_EXTENSION_SEARCH_A11Y_LABEL")
    )
  }
}
