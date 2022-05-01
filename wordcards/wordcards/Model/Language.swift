//
//  Language.swift
//  wordcards
//
//  Created by k191k on 2022/04/28.
//

import Foundation

enum Language: Equatable {
    case en
    case jp
   
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en-us")
        case .jp: return Locale(identifier: "ja-JP")
        }
    }
}
