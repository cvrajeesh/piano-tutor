import Foundation

/// Melodies shared by the course and the song library, written in the text
/// notation described in Notation.swift. All are traditional or long out of
/// copyright; arrangements and accompaniments are our own simple ones.
enum Tunes {
    // Hot Cross Buns (English traditional)
    static let hotCrossBunsSimple = "E4 D4 C4/h | E4 D4 C4/h | C4 C4 C4 C4 | D4 D4 D4 D4 | E4 D4 C4/h"
    static let hotCrossBuns = "E4 D4 C4/h | E4 D4 C4/h | C4/e C4/e C4/e C4/e D4/e D4/e D4/e D4/e | E4 D4 C4/h"

    // Mary Had a Little Lamb (traditional)
    static let mary = "E4 D4 C4 D4 | E4 E4 E4/h | D4 D4 D4/h | E4 G4 G4/h | "
        + "E4 D4 C4 D4 | E4 E4 E4 E4 | D4 D4 E4 D4 | C4/w"
    static let maryLeft = "C3/w | C3/w | G3/w | C3/w | C3/w | C3/w | G3/w | C3/w"

    // Lightly Row (German traditional)
    static let lightlyRowFirstHalf = "G4 E4 E4/h | F4 D4 D4/h | C4 D4 E4 F4 | G4 G4 G4/h | "
        + "G4 E4 E4/h | F4 D4 D4/h | C4 E4 G4 G4 | E4/w"
    static let lightlyRow = "G4 E4 E4/h | F4 D4 D4/h | C4 D4 E4 F4 | G4 G4 G4/h | "
        + "G4 E4 E4/h | F4 D4 D4/h | C4 E4 G4 G4 | E4/w | "
        + "D4 D4 D4 D4 | D4 E4 F4/h | E4 E4 E4 E4 | E4 F4 G4/h | "
        + "G4 E4 E4/h | F4 D4 D4/h | C4 E4 G4 G4 | C4/w"

    // Ode to Joy (Ludwig van Beethoven, 1824)
    static let odeSimple = "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4/h D4/h | "
        + "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4/h C4/h"
    static let ode = "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4/q. D4/e D4/h | "
        + "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4/q. C4/e C4/h"
    static let odeLeft = "C3/w | G3/w | C3/w | G3/w | C3/w | G3/w | C3/w | G3/h C3/h"
    static let odeFull = "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4/q. D4/e D4/h | "
        + "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4/q. C4/e C4/h | "
        + "D4 D4 E4 C4 | D4 E4/e F4/e E4 C4 | D4 E4/e F4/e E4 D4 | C4 D4 G3/h | "
        + "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4/q. C4/e C4/h"
    static let odeFullLeft = "C3/w | G3/w | C3/w | G3/w | C3/w | G3/w | C3/w | G3/h C3/h | "
        + "G3/w | G3/h C3/h | G3/w | C3/h D3/h | "
        + "C3/w | G3/w | C3/w | G3/h C3/h"
    static let odeInG = "B4 B4 C5 D5 | D5 C5 B4 A4 | G4 G4 A4 B4 | B4/q. A4/e A4/h | "
        + "B4 B4 C5 D5 | D5 C5 B4 A4 | G4 G4 A4 B4 | A4/q. G4/e G4/h"

    // Au Clair de la Lune (French traditional)
    static let auClairPhrase = "C4 C4 C4 D4 | E4/h D4/h | C4 E4 D4 D4 | C4/w | "
        + "C4 C4 C4 D4 | E4/h D4/h | C4 E4 D4 D4 | C4/w"
    static let auClair = "C4 C4 C4 D4 | E4/h D4/h | C4 E4 D4 D4 | C4/w | "
        + "C4 C4 C4 D4 | E4/h D4/h | C4 E4 D4 D4 | C4/w | "
        + "D4 D4 D4 D4 | A3/h A3/h | D4 C4 B3 A3 | G3/w | "
        + "C4 C4 C4 D4 | E4/h D4/h | C4 E4 D4 D4 | C4/w"

    // Go Tell Aunt Rhody (traditional)
    static let auntRhody = "E4/h E4 D4 | C4/h C4/h | D4/h D4 F4 | E4 D4 C4/h | "
        + "G4/h G4 F4 | E4/h E4/h | D4 C4 D4 E4 | C4/w"

    // Largo from the "New World" Symphony (Antonín Dvořák, 1893)
    static let largo = "E4/q. G4/e G4/h | E4/q. D4/e C4/h | D4/q. E4/e G4/q. E4/e | D4/w | "
        + "E4/q. G4/e G4/h | E4/q. D4/e C4/h | D4 E4 D4/q. C4/e | C4/w"
    static let largoLeft = "C3/w | C3/w | G3/w | G3/w | C3/w | C3/w | G3/w | C3/w"

    // Jingle Bells, chorus (James Pierpont, 1857)
    static let jingle = "E4 E4 E4/h | E4 E4 E4/h | E4 G4 C4/q. D4/e | E4/w | "
        + "F4 F4 F4/q. F4/e | F4 E4 E4 E4/e E4/e | E4 D4 D4 E4 | D4/h G4/h | "
        + "E4 E4 E4/h | E4 E4 E4/h | E4 G4 C4/q. D4/e | E4/w | "
        + "F4 F4 F4/q. F4/e | F4 E4 E4 E4/e E4/e | G4 G4 F4 D4 | C4/w"
    static let jingleLeft = "C3/w | C3/w | C3/w | C3/w | F3/w | C3/w | G3/w | G3/w | "
        + "C3/w | C3/w | C3/w | C3/w | F3/w | C3/w | G3/w | C3/w"

    // Twinkle, Twinkle, Little Star (French melody, 18th century)
    static let twinkle = "C4:1 C4:1 G4:4 G4:4 | A4:5 A4:5 G4/h:4 | F4 F4 E4 E4 | D4 D4 C4/h | "
        + "G4 G4 F4 F4 | E4 E4 D4/h | G4 G4 F4 F4 | E4 E4 D4/h | "
        + "C4:1 C4:1 G4:4 G4:4 | A4:5 A4:5 G4/h:4 | F4 F4 E4 E4 | D4 D4 C4/h"
    static let twinkleChords = "C3+E3+G3/w | C3+F3+A3/h:5-2-1 C3+E3+G3/h | C3+F3+A3/h:5-2-1 C3+E3+G3/h | B2+D3+G3/h:5-3-1 C3+E3+G3/h | "
        + "C3+E3+G3/h C3+F3+A3/h:5-2-1 | C3+E3+G3/h B2+D3+G3/h:5-3-1 | C3+E3+G3/h C3+F3+A3/h:5-2-1 | C3+E3+G3/h B2+D3+G3/h:5-3-1 | "
        + "C3+E3+G3/w | C3+F3+A3/h:5-2-1 C3+E3+G3/h | C3+F3+A3/h:5-2-1 C3+E3+G3/h | B2+D3+G3/h:5-3-1 C3+E3+G3/h"

    // Long, Long Ago (Thomas Haynes Bayly, 1833)
    static let longLongAgo = "C4/h C4 D4 | E4/h E4 F4 | G4/h:4 A4:5 G4:4 | E4/w | "
        + "G4/h F4 E4 | D4/w | F4/h E4 D4 | C4/w"

    // Frère Jacques (French traditional)
    static let frereJacques = "C4 D4 E4 C4 | C4 D4 E4 C4 | E4 F4 G4/h | E4 F4 G4/h | "
        + "G4/e:4 A4/e:5 G4/e:4 F4/e:3 E4:2 C4:1 | G4/e:4 A4/e:5 G4/e:4 F4/e:3 E4:2 C4:1 | "
        + "C4:2 G3:1 C4/h:2 | C4:2 G3:1 C4/h:2"

    // London Bridge (English traditional)
    static let londonBridge = "G4/q. A4/e G4 F4 | E4 F4 G4/h | D4 E4 F4/h | E4 F4 G4/h | "
        + "G4/q. A4/e G4 F4 | E4 F4 G4/h | D4/h G4/h | E4 C4/h."

    // Oh! Susanna (Stephen Foster, 1848)
    static let ohSusanna = "C4/e D4/e | E4 G4 G4/q. A4/e | G4 E4 C4/q. D4/e | E4 E4 D4 C4 | D4/h. C4/e D4/e | "
        + "E4 G4 G4/q. A4/e | G4 E4 C4/q. D4/e | E4 E4 D4 D4 | C4/h."

    // Yankee Doodle (traditional)
    static let yankeeDoodle = "C4 C4 D4 E4 | C4 E4 D4 G3 | C4 C4 D4 E4 | C4/h B3/h | "
        + "C4 C4 D4 E4 | F4 E4 D4 C4 | B3 G3 A3 B3 | C4/h C4/h"

    // Old MacDonald (traditional)
    static let oldMacDonald = "G4 G4 G4 D4 | E4 E4 D4/h | B4 B4 A4 A4 | G4/h. D4 | "
        + "G4 G4 G4 D4 | E4 E4 D4/h | B4 B4 A4 A4 | G4/w"

    // Amazing Grace (traditional tune "New Britain")
    static let amazingGrace = "D4 | G4/h B4/e G4/e | B4/h A4 | G4/h E4 | D4/h D4 | "
        + "G4/h B4/e G4/e | B4/h A4 | D5/h.~ | D5/h B4 | "
        + "D5/q. B4/e D5/e B4/e | G4/h D4 | E4/q. G4/e G4/e E4/e | D4/h D4 | "
        + "G4/h B4/e G4/e | B4/h A4 | G4/h.~ | G4/h"

    // Minuet in G (Christian Petzold, from the Anna Magdalena Notebook)
    static let minuet = "D5 G4/e A4/e B4/e C5/e | D5 G4 G4 | E5 C5/e D5/e E5/e F#5/e | G5 G4 G4 | "
        + "C5 D5/e C5/e B4/e A4/e | B4 C5/e B4/e A4/e G4/e | F#4 G4/e A4/e B4/e G4/e | A4/h. | "
        + "D5 G4/e A4/e B4/e C5/e | D5 G4 G4 | E5 C5/e D5/e E5/e F#5/e | G5 G4 G4 | "
        + "C5 D5/e C5/e B4/e A4/e | B4 C5/e B4/e A4/e G4/e | A4 B4/e A4/e G4/e F#4/e | G4/h."
    static let minuetLeft = "G3/h. | B3/h. | C4/h. | B3/h. | A3/h. | G3/h. | D4 B3 G3 | D4/h. | "
        + "B3/h A3 | G3 B3 G3 | C4/h. | B3 C4/e B3/e A3/e G3/e | "
        + "A3/h F#3 | G3/h B3 | C4 D4 D3 | G3/h."

    // Für Elise, opening (Ludwig van Beethoven, 1810), written in 3/4 for easier reading
    static let furElise = "E5/e D#5/e | E5/e D#5/e E5/e B4/e D5/e C5/e | A4 r/e C4/e E4/e A4/e | B4 r/e E4/e G#4/e B4/e | "
        + "C5 r/e E4/e E5/e D#5/e | E5/e D#5/e E5/e B4/e D5/e C5/e | A4 r/e C4/e E4/e A4/e | B4 r/e E4/e C5/e B4/e | A4/h"
}
