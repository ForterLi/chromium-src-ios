// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

// Adds easy SwiftUI access to the Chrome color palette
extension Color {
  /// The secondary grouped background color
  public static var cr_groupedSecondaryBackground: Color {
    return Color(kGroupedSecondaryBackgroundColor)
  }
}
