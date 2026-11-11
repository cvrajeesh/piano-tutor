import Foundation

/// Free-standing songs that can be practised at any speed, with either hand or both.
public enum SongLibrary {
    public static let songs: [Song] = [
        Song(id: "hot-cross-buns", title: "Hot Cross Buns", credit: "English traditional", level: 1,
             score: sc(Tunes.hotCrossBuns, tempo: 80)),
        Song(id: "mary", title: "Mary Had a Little Lamb", credit: "Traditional", level: 1,
             score: sc(Tunes.mary, left: Tunes.maryLeft, tempo: 92)),
        Song(id: "lightly-row", title: "Lightly Row", credit: "German traditional", level: 1,
             score: sc(Tunes.lightlyRow, tempo: 96)),
        Song(id: "aunt-rhody", title: "Go Tell Aunt Rhody", credit: "Traditional", level: 1,
             score: sc(Tunes.auntRhody, tempo: 92)),
        Song(id: "au-clair", title: "Au Clair de la Lune", credit: "French traditional", level: 1,
             score: sc(Tunes.auClair, tempo: 88)),
        Song(id: "ode-to-joy", title: "Ode to Joy", credit: "Ludwig van Beethoven", level: 2,
             score: sc(Tunes.odeFull, left: Tunes.odeFullLeft, tempo: 100)),
        Song(id: "largo", title: "Largo from the \"New World\" Symphony", credit: "Antonín Dvořák", level: 2,
             score: sc(Tunes.largo, left: Tunes.largoLeft, tempo: 66)),
        Song(id: "twinkle", title: "Twinkle, Twinkle, Little Star", credit: "French melody, 18th century", level: 2,
             score: sc(Tunes.twinkle, left: Tunes.twinkleChords, tempo: 92)),
        Song(id: "jingle-bells", title: "Jingle Bells", credit: "James Pierpont", level: 2,
             score: sc(Tunes.jingle, left: Tunes.jingleLeft, tempo: 108)),
        Song(id: "long-long-ago", title: "Long, Long Ago", credit: "Thomas Haynes Bayly", level: 2,
             score: sc(Tunes.longLongAgo, tempo: 96)),
        Song(id: "frere-jacques", title: "Frère Jacques", credit: "French traditional", level: 2,
             score: sc(Tunes.frereJacques, tempo: 100)),
        Song(id: "london-bridge", title: "London Bridge", credit: "English traditional", level: 2,
             score: sc(Tunes.londonBridge, tempo: 100)),
        Song(id: "old-macdonald", title: "Old MacDonald", credit: "Traditional", level: 2,
             score: sc(Tunes.oldMacDonald, tempo: 108, key: 1, rp: nil)),
        Song(id: "oh-susanna", title: "Oh! Susanna", credit: "Stephen Foster", level: 2,
             score: sc(Tunes.ohSusanna, tempo: 104, pickup: 1)),
        Song(id: "yankee-doodle", title: "Yankee Doodle", credit: "Traditional", level: 2,
             score: sc(Tunes.yankeeDoodle, tempo: 112, rp: nil)),
        Song(id: "amazing-grace", title: "Amazing Grace", credit: "Traditional", level: 3,
             score: sc(Tunes.amazingGrace, time: .threeFour, tempo: 84, key: 1, pickup: 1, rp: nil)),
        Song(id: "minuet-in-g", title: "Minuet in G", credit: "Christian Petzold", level: 3,
             score: sc(Tunes.minuet, left: Tunes.minuetLeft, time: .threeFour, tempo: 96, key: 1, rp: nil, lp: nil)),
        Song(id: "fur-elise", title: "Für Elise (opening)", credit: "Ludwig van Beethoven", level: 3,
             score: sc(Tunes.furElise, time: .threeFour, tempo: 100, pickup: 1, rp: nil)),
    ]

    public static func levelName(_ level: Int) -> String {
        switch level {
        case 1: return "First tunes"
        case 2: return "Getting going"
        default: return "A challenge"
        }
    }
}
