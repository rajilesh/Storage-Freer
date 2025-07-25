//
//  ContentView.swift
//  Storage Freer
//
//  Created by Rajilesh Panoli on 24/07/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            FileExplorerView()
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

