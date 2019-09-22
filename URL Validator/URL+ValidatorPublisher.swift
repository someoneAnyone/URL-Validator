//
//  URL Validator.swift
//  NightscouterSwiftUI
//
//  Created by Peter Ina on 9/15/19.
//  Copyright © 2019 Peter Ina. All rights reserved.
//

import Foundation
import Combine

enum URLValidatorError: Error {
    case empty(String)
    case onlyPrefix(String)
    case containsWhitespace(String)
    case couldNotCreateURL(String)
    case serverError(String)
}

public extension URL {
    
    static let networkActivityPublisher = PassthroughSubject<Bool, Never>()
    static let isValidURLPublisher = PassthroughSubject<Bool, Never>()
    static let isReachableURLPublisher = PassthroughSubject<Bool, Never>()

    
    fileprivate static func validateURL(string: String) throws -> URL {
        
        // Ignore Nils & Empty Strings
        if (string.isEmpty || string.count < 3 )
        {
            isValidURLPublisher.send(false)
            throw URLValidatorError.empty("Url String was empty or less than 3 characters.")
        }
        
        // Ignore prefixes (including partials)
        let prefixes = ["http://www.", "https://www.", "www."]
        for prefix in prefixes
        {
            if ((prefix.range(of: string, options: .caseInsensitive, range: nil, locale: nil)) != nil) {
                isValidURLPublisher.send(false)
                throw URLValidatorError.onlyPrefix("Url String was prefix only")
            }
        }
    
        var formattedUrlString = string.replacingOccurrences(of: " ", with: "")

        // Check that URL already contains required 'http://' or 'https://', prepend if it does not
        if (!formattedUrlString.hasPrefix("http://") && !formattedUrlString.hasPrefix("https://"))
        {
            formattedUrlString = "https://"+string
        }
        
        guard let finalURL = URL(string: formattedUrlString) else {
            isValidURLPublisher.send(false)
            throw URLValidatorError.couldNotCreateURL("Url could not be created.")
        }
        
    
        isValidURLPublisher.send(true)
        return finalURL
    }
    
    static func testURLPublisher(string: String) -> AnyPublisher<URL?, Never> {
        
        let validatedURL = try? validateURL(string: string)
        
        guard let urlToCheck = validatedURL else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: urlToCheck)
        request.httpMethod = "HEAD"
        
        let publisher = URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveSubscription: { _ in
                networkActivityPublisher.send(true)
            }, receiveCompletion: { _ in
                networkActivityPublisher.send(false)
            }, receiveCancel: {
                networkActivityPublisher.send(false)
            })
            .tryMap { data, response -> URL? in
                // URL Responded - Check Status Code
                guard let urlResponse = response as? HTTPURLResponse, ((urlResponse.statusCode >= 200 && urlResponse.statusCode < 400) || urlResponse.statusCode == 405) else {
                    
                    isReachableURLPublisher.send(false)
                        throw URLValidatorError.serverError("Could not find the a servr at: \(urlToCheck)")
                }
                isReachableURLPublisher.send(true)
                        return urlResponse.url?.absoluteURL
            }
        .catch { err in
            return Just(nil)
        }
        .eraseToAnyPublisher()
        return publisher
    }
}
