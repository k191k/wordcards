//
//  WordCell.swift
//  wordcards
//
//  Created by k191k on 2022/04/28.
//

import SwiftUI

struct WordCell: View {
    var word: String
    var meaning: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(word)
                .padding(.bottom)
            Text(meaning)
        }.padding()
    }
}

struct WordCell_Previews: PreviewProvider {
    static var previews: some View {
        WordCell(word: "How are You", meaning: "お元気ですか")
    }
}
