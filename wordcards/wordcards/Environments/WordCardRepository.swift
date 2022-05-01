//
//  WordCardRepository.swift
//  wordbook
//
//  Created by k191k on 2022/04/28.
//

import Foundation
import CoreData
import OrderedCollections

class WordCardsRepository {
    
    private (set) var context: NSManagedObjectContext
    
    required init (context: NSManagedObjectContext) {
        self.context = context
    }
    
    func saveCard(word: String, meaning: String) {
        let newCard = Card(context: context)
        newCard.word = word
        newCard.meaning = meaning
        newCard.timestamp = Date()
        save()
    }
    
    func getCards() -> [Card] {
        var wordCards = getAllData()
        wordCards.sort(by: {$0.word! < $1.word!})
        return wordCards
    }
    
    func deleteCard( _ card: Card) {
        context.delete(card)
        save()
    }
}


private extension WordCardsRepository {
    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        }
        catch let error as NSError {
            print("Error: \(error), \(error.userInfo)")
        }
    }
    
    func getAllData() -> [Card] {
        let request = NSFetchRequest<Card>(entityName: "Card")
        do {
            let cards = try context.fetch(request)
            return cards
        }
        catch {
            fatalError()
        }
    }

}
