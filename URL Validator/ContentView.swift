//
//  ContentView.swift
//  URL Validator
//
//  Created by Peter Ina on 9/18/19.
//  Copyright © 2019 Peter Ina. All rights reserved.
//

import SwiftUI
import Combine

class NewSiteViewModel: ObservableObject {
    
    @Published var validatedURL: URL?
    
    @Published var urlString: String = ""
    @Published var isValidURL: Bool = false
    
    private var cancellable = Set<AnyCancellable>()
    
    init() {
        $urlString
            .dropFirst(1)
            .debounce(for: 0.5, scheduler: RunLoop.main)
            
            // .throttle(for: 0.5, scheduler: DispatchQueue(label: "Validator"), latest: true)
            .removeDuplicates()
            .compactMap { string -> AnyPublisher<URL?, Never> in
                return URL.testURLPublisher(string: string)
        }
        .switchToLatest()
        .receive(on: RunLoop.main)
        .sink { recievedURL in
            guard let url = recievedURL else {
                self.validatedURL = nil
                self.isValidURL = false
                return
            }
            self.validatedURL = url
            self.isValidURL = true
            
        }
        .store(in: &cancellable)
    }
}


struct ContentView: View {
    
    @ObservedObject var model: NewSiteViewModel = NewSiteViewModel()
    
    @State var networkActivity = false
    
    var body: some View {
        VStack{
            TextField("url string", text: $model.urlString)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("Network activity: \(networkActivity ? "true" : "false")")
            Text("Is valid: \(model.isValidURL ? "true" : "false")")
            if model.isValidURL {
                Text("Validated URL: \(model.validatedURL?.absoluteString ?? "")")
            }
        }.onReceive(URL.networkActivityPublisher
            .receive(on: DispatchQueue.main)) {
                self.networkActivity = $0
        }.padding()
    }
}
