//
//  ViewState.swift
//  ViewState
//
//  Created by Sam Warnick on 9/11/21.
//

import SwiftUI

class ViewState: ObservableObject {
    @Published var presentNoiseLevel = false
    @Published var presentSettings = false
}
