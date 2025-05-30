//
//  ContentView.swift
//  chimetime
//
//  Created by Liam McShane on 30/5/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("ChimeTime")
                .font(.largeTitle)
                .fontWeight(.bold)
             
            Text("Running in Menu Bar")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Look for the 🔔 icon in your menu bar to configure chime settings.")
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(40)
        .frame(maxWidth: 400, maxHeight: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
