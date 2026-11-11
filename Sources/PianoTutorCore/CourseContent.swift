import Foundation

/// The built-in course: eight units that go from finding Middle C to playing
/// a tune with left-hand chords.
public enum Curriculum {
    public static let units: [CourseUnit] = [
        unit1, unit2, unit3, unit4, unit5, unit6, unit7, unit8,
    ]

    public static var allLessons: [Lesson] {
        var result: [Lesson] = []
        for unit in units {
            result.append(contentsOf: unit.lessons)
        }
        return result
    }

    private static let waits = "The music waits for you. Take your time and find each key."
    private static let inTime = "Listen to the count-in, then play along with the clicks."

    // MARK: Unit 1

    static let unit1 = CourseUnit(
        id: "u1",
        title: "Meet the Keys",
        summary: "Find your way around the keyboard and play your first notes.",
        lessons: [
            Lesson(id: "u1-l1", title: "Finding Middle C", summary: "Use the black keys as landmarks.", steps: [
                info("Black keys come in twos and threes", [
                    "Look at your keyboard. The black keys are arranged in groups of two and groups of three, repeating all the way up.",
                    "These groups are your landmarks. Once you can spot them, you can find any note without counting from the end.",
                ], marks: [mark("C#4"), mark("D#4"), mark("F#4"), mark("G#4"), mark("A#4")]),
                info("C lives to the left of the two black keys", [
                    "Find any group of two black keys. The white key just to the left of the group is always C.",
                    "Your keyboard has six of them. Each one starts a new set of the same seven note names: C, D, E, F, G, A, B.",
                ], marks: [mark("C2", "C"), mark("C3", "C"), mark("C4", "C"), mark("C5", "C"), mark("C6", "C"), mark("C7", "C")]),
                find("Find three different Cs", "Play any C on your keyboard, then two more in other places.", ["C4", "C4", "C4"], anyOctave: true, hint: false),
                info("Middle C", [
                    "Middle C is the C closest to the centre of the keyboard. On a 61-key keyboard such as the Casio CT-S300, it is the third C from the left.",
                    "Almost everything you play at first starts here, so it is worth knowing where it is without looking for long.",
                ], marks: [mark("C4", "Middle C")]),
                find("Play Middle C", "It is lit up on the keyboard below.", ["C4"]),
                find("Now from memory", "Middle C, the C below it, the C above it, then Middle C again.", ["C4", "C3", "C5", "C4"], hint: false),
            ]),
            Lesson(id: "u1-l2", title: "Three Notes: C, D, E", summary: "Thumb on Middle C, and your first tune.", steps: [
                info("Fingers have numbers", [
                    "Pianists number their fingers from 1 to 5. In both hands the thumb is 1 and the little finger is 5.",
                    "Rest your right thumb on Middle C and let fingers 2 and 3 sit on the next two white keys, D and E. Keep your fingers gently curved, as if you were holding a small ball.",
                ], marks: [mark("C4", "1", hand: .right), mark("D4", "2", hand: .right), mark("E4", "3", hand: .right)]),
                find("Play C, D, E", "One finger per key: 1, 2, 3.", ["C4", "D4", "E4"]),
                practice("Stepping up and down", waits, sc("C4 D4 E4 D4 | C4 D4 E4/h | E4 D4 C4 D4 | E4 D4 C4/h")),
                practice("Mix them up", "Watch the note heads move up and down, and follow them with your fingers.", sc("C4 E4 D4 C4 | E4 C4 D4/h | E4 E4 D4 D4 | C4/w")),
                practice("Hot Cross Buns", "A traditional tune that needs only these three notes.", sc(Tunes.hotCrossBunsSimple)),
            ]),
            Lesson(id: "u1-l3", title: "Five-Finger Position", summary: "One finger for each key from C to G.", steps: [
                info("One finger for each key", [
                    "Add F and G. Now every finger has a key of its own: 1 on C, 2 on D, 3 on E, 4 on F and 5 on G.",
                    "This is called the C position. Your hand stays in one place and only your fingers move, so you never need to look down to find the next note.",
                ], marks: [mark("C4", "1", hand: .right), mark("D4", "2", hand: .right), mark("E4", "3", hand: .right), mark("F4", "4", hand: .right), mark("G4", "5", hand: .right)]),
                find("Find F and G", "Follow the lit keys.", ["F4", "G4", "C4", "G4", "E4"]),
                practice("Climb and come back", waits, sc("C4 D4 E4 F4 | G4/h G4/h | G4 F4 E4 D4 | C4/w")),
                practice("Skipping keys", "Sometimes the tune jumps over a key. The finger numbers show you which finger to use.", sc("C4 E4 D4 F4 | E4 G4 F4 D4 | C4 E4 G4 E4 | C4/w")),
                practice("Lightly Row", "A German folk tune that uses all five notes.", sc(Tunes.lightlyRowFirstHalf)),
            ]),
        ]
    )

    // MARK: Unit 2

    static let unit2 = CourseUnit(
        id: "u2",
        title: "Feel the Beat",
        summary: "Play in time: quarter, half and whole notes, and rests.",
        lessons: [
            Lesson(id: "u2-l1", title: "Quarter and Half Notes", summary: "Keep a steady beat with the metronome.", steps: [
                info("Music has a steady beat", [
                    "Underneath every piece runs a steady pulse, like a ticking clock. From now on some exercises are played in time: you will hear a click on every beat, and one measure of clicks to count you in.",
                    "A quarter note has a filled-in head and a stem. It lasts one beat. A half note has a hollow head and a stem. It lasts two beats: play it, then keep the key down through the next click.",
                ], figure: sc("C4 C4 C4/h | C4/h C4/h")),
                play("One note, steady beat", inTime, sc("C4 C4 C4 C4 | C4/h C4/h | C4 C4 C4/h | C4/h C4/h", tempo: 66)),
                play("Steps in time", "Same rhythm idea, now moving between notes.", sc("C4 D4 E4/h | E4 D4 C4/h | C4 D4 E4 D4 | C4/h C4/h", tempo: 66)),
                play("Hot Cross Buns", "You know the notes. This time, keep it with the beat.", sc(Tunes.hotCrossBunsSimple, tempo: 72)),
            ]),
            Lesson(id: "u2-l2", title: "Whole Notes and Rests", summary: "Long notes, and the sound of silence.", steps: [
                info("Whole notes last four beats", [
                    "A whole note is a hollow head with no stem. Play it on the first beat and hold the key down for all four.",
                    "Silence is written down too. A rest tells you to wait: the zigzag is a quarter rest (one beat), the small block sitting on a line is a half rest (two beats), and a block hanging under a line means a whole measure of silence.",
                ], figure: sc("C4/w | C4 r/q C4/h | r/h C4/h")),
                play("Hold it", "Count to four on the whole notes.", sc("C4/w | E4/h G4/h | E4/h C4/h | C4/w", tempo: 66)),
                play("Leave a gap", "Lift your finger on the rests and let the click pass.", sc("C4 r/q E4 r/q | G4/h r/h | G4 r/q E4 r/q | C4/w", tempo: 66)),
                practice("Mary Had a Little Lamb", "Learn the notes first. " + waits, sc(Tunes.mary)),
                play("Mary Had a Little Lamb", "Now in time. Watch out for the long notes.", sc(Tunes.mary, tempo: 80)),
            ]),
            Lesson(id: "u2-l3", title: "Song: Lightly Row", summary: "A complete tune in C position.", steps: [
                info("Putting it together", [
                    "You already know the first half of this German folk tune. The second half repeats one note several times before returning to the opening.",
                    "Learn the notes in practice mode first, then play it in time.",
                ]),
                practice("Lightly Row", waits, sc(Tunes.lightlyRow)),
                play("Lightly Row", inTime, sc(Tunes.lightlyRow, tempo: 84)),
            ]),
            Lesson(id: "u2-l4", title: "Song: Ode to Joy", summary: "Beethoven's famous theme.", steps: [
                info("A melody everybody knows", [
                    "Beethoven built the grand finale of his Ninth Symphony on a tune that moves almost entirely by step, using just the five notes under your fingers.",
                    "This version keeps the rhythm simple. You will meet the original rhythm later in the course.",
                ]),
                practice("Ode to Joy", waits, sc(Tunes.odeSimple)),
                play("Ode to Joy", inTime, sc(Tunes.odeSimple, tempo: 84)),
            ]),
        ]
    )

    // MARK: Unit 3

    static let unit3 = CourseUnit(
        id: "u3",
        title: "Read the Staff",
        summary: "Learn to read notes without the letter names.",
        lessons: [
            Lesson(id: "u3-l1", title: "Lines and Spaces", summary: "Where your five notes live on the staff.", steps: [
                info("The staff", [
                    "Notes are written on a set of five lines called a staff. The higher a note sits on the staff, the further to the right it is on the keyboard.",
                    "The curly sign at the start is the treble clef, which is used for the right hand. A note sits either on a line, with the line running through its head, or in the space between two lines.",
                ], figure: sc("C4 D4 E4 F4 | G4/w")),
                info("Your five notes", [
                    "Middle C hangs below the staff on a short line of its own. D sits just under the bottom line. E is on the bottom line, F is in the first space and G is on the second line.",
                    "So far the letter names have been printed inside the notes. In this lesson they are gradually taken away.",
                ], marks: [mark("C4", "C", hand: .right), mark("D4", "D", hand: .right), mark("E4", "E", hand: .right), mark("F4", "F", hand: .right), mark("G4", "G", hand: .right)], figure: sc("C4 D4 E4 F4 | G4/w")),
                practice("Names and key hints", "Notice where each note sits on the staff as you play it.", sc("C4 D4 E4 F4 | G4 F4 E4 D4 | C4 E4 G4 E4 | C4/w")),
                practice("Names only", "The keyboard no longer lights up. Use the letters.", sc("E4 E4 G4 G4 | F4 F4 D4/h | C4 D4 E4 F4 | G4/h C4/h"), hints: false),
                practice("Key hints only", "The letters are gone. Check the keyboard only if you get stuck.", sc("C4 C4 E4 E4 | G4 G4 E4/h | F4 F4 D4 D4 | C4/w"), names: false),
                practice("On your own", "No names and no hints: you are reading music.", sc("G4 E4 C4 E4 | G4/h G4/h | F4 D4 F4 D4 | C4/w"), names: false, hints: false),
            ]),
            Lesson(id: "u3-l2", title: "Steps and Skips", summary: "Read by shape instead of naming every note.", steps: [
                info("Read the distance, not every name", [
                    "When a note moves from a line to the very next space, or from a space to the next line, play the neighbouring key. That is a step.",
                    "When it jumps from one line to the next line, or from a space to the next space, miss out a key. That is a skip. Fluent readers follow these shapes instead of naming each note.",
                ], figure: sc("C4 D4 E4/h | C4 E4 G4/h")),
                practice("Steps", "Every note here moves to its neighbour, or repeats.", sc("C4 D4 E4 D4 | E4 F4 G4/h | G4 F4 E4 F4 | E4 D4 C4/h"), names: false, hints: false),
                practice("Skips", "Line to line, space to space.", sc("C4 E4 C4 E4 | D4 F4 D4 F4 | E4 G4 E4 G4 | E4 C4 C4/h"), names: false, hints: false),
                play("Steps and skips together", inTime, sc("C4 D4 E4 G4 | F4 D4 E4/h | G4 E4 F4 D4 | C4/w", tempo: 72), names: false, hints: false),
            ]),
            Lesson(id: "u3-l3", title: "Song: Au Clair de la Lune", summary: "Read a French folk tune.", steps: [
                info("Read it yourself", [
                    "This French folk tune is more than two hundred years old. It moves mostly by step, with one skip.",
                    "There are no letter names this time. Find the first note, then follow the shape of the line.",
                ]),
                practice("Au Clair de la Lune", waits, sc(Tunes.auClairPhrase), names: false),
                play("Au Clair de la Lune", inTime, sc(Tunes.auClairPhrase, tempo: 80), names: false, hints: false),
            ]),
            Lesson(id: "u3-l4", title: "Song: Go Tell Aunt Rhody", summary: "Half notes and quarter notes in a folk song.", steps: [
                info("Look ahead", [
                    "This folk song mixes half notes and quarter notes. While you hold a long note, use the time to look at what comes next.",
                ]),
                practice("Go Tell Aunt Rhody", waits, sc(Tunes.auntRhody), names: false),
                play("Go Tell Aunt Rhody", inTime, sc(Tunes.auntRhody, tempo: 84), names: false, hints: false),
            ]),
        ]
    )

    // MARK: Unit 4

    static let unit4 = CourseUnit(
        id: "u4",
        title: "The Left Hand",
        summary: "A second hand and a second clef.",
        lessons: [
            Lesson(id: "u4-l1", title: "Left-Hand Position", summary: "Little finger on the C below Middle C.", steps: [
                info("Meet your left hand", [
                    "Fingers are numbered the same way in the left hand, with the thumb as 1. Because the left hand mirrors the right, your little finger now plays the lowest note.",
                    "Find the C below Middle C. Put finger 5 on it and let the other fingers rest on D, E, F and G. Your left thumb ends up on G.",
                ], marks: [mark("C3", "5", hand: .left), mark("D3", "4", hand: .left), mark("E3", "3", hand: .left), mark("F3", "2", hand: .left), mark("G3", "1", hand: .left)]),
                find("Find your left-hand notes", "Follow the lit keys with your left hand.", ["C3", "G3", "E3", "D3", "F3"], hand: .left),
                practice("Left hand climbs", waits, sc(left: "C3 D3 E3 F3 | G3/h G3/h | G3 F3 E3 D3 | C3/w")),
                practice("Left hand skips", "Fingers 5, 3 and 1 play C, E and G.", sc(left: "C3 E3 G3 E3 | C3 E3 G3/h | G3 E3 F3 D3 | C3/w")),
            ]),
            Lesson(id: "u4-l2", title: "The Bass Clef", summary: "Reading low notes.", steps: [
                info("A staff for low notes", [
                    "Left-hand music is written in the bass clef. Its two dots sit either side of the line for F, which is why it is also called the F clef.",
                    "In the bass clef your five notes are: C in the second space, D on the middle line, E in the third space, F on the fourth line and G in the top space.",
                ], marks: [mark("C3", "C", hand: .left), mark("D3", "D", hand: .left), mark("E3", "E", hand: .left), mark("F3", "F", hand: .left), mark("G3", "G", hand: .left)], figure: sc(left: "C3 D3 E3 F3 | G3/w")),
                practice("Names, no key hints", "Read the letters and notice where each note sits.", sc(left: "C3 D3 E3 D3 | C3 E3 G3/h | F3 E3 D3 E3 | C3/w"), hints: false),
                practice("Key hints, no names", "Now read the positions.", sc(left: "G3 F3 E3 D3 | C3/h G3/h | E3 E3 F3 F3 | G3/w"), names: false),
                play("Low and steady", inTime, sc(left: "C3/h G3/h | E3/h G3/h | C3 E3 G3 E3 | C3/w", tempo: 66), names: false),
            ]),
            Lesson(id: "u4-l3", title: "Passing the Tune", summary: "Both staves at once, one hand at a time.", steps: [
                info("Two staves, one piece", [
                    "Piano music joins two staves together: the treble staff on top for the right hand and the bass staff underneath for the left. Both are read from left to right at the same time.",
                    "In this lesson the tune passes from hand to hand, so only one hand plays at a time. Keep both hands resting in position, ready for their turn.",
                ]),
                practice("Question and answer", waits, sc(
                    "C4 D4 E4/h | r/w | E4 F4 G4/h | r/w | G4 F4 E4 D4 | r/w | C4/w",
                    left: "r/w | C3 D3 E3/h | r/w | E3 F3 G3/h | r/w | G3 F3 E3 D3 | C3/w"
                )),
                play("Question and answer", "The last note is your first with both hands together.", sc(
                    "C4 D4 E4/h | r/w | E4 F4 G4/h | r/w | G4 F4 E4 D4 | r/w | C4/w",
                    left: "r/w | C3 D3 E3/h | r/w | E3 F3 G3/h | r/w | G3 F3 E3 D3 | C3/w",
                    tempo: 69
                )),
                play("Echo", "The left hand copies the right.", sc(
                    "C4 E4 G4/h | r/w | G4 E4 C4/h | r/w | C4/w",
                    left: "r/w | C3 E3 G3/h | r/w | G3 E3 C3/h | C3/w",
                    tempo: 72
                ), names: false),
            ]),
        ]
    )

    // MARK: Unit 5

    static let unit5 = CourseUnit(
        id: "u5",
        title: "Hands Together",
        summary: "Play a tune in one hand over long notes in the other.",
        lessons: [
            Lesson(id: "u5-l1", title: "Hold and Play", summary: "One long note under a moving tune.", steps: [
                info("Start with one held note", [
                    "Playing with both hands is a new skill for your brain, so start small: the left hand holds one long note while the right hand plays over the top.",
                    "Practise each hand alone, then join them. In practice mode the music waits until both hands are on the right keys.",
                ]),
                practice("Right hand alone", waits, holdAndPlay, hands: [.right]),
                practice("Left hand alone", "Four slow notes. Count four beats for each.", holdAndPlay, hands: [.left]),
                practice("Hands together", "Where notes line up vertically, press them at the same moment.", holdAndPlay),
                play("Hands together, in time", inTime, holdAndPlay),
            ]),
            Lesson(id: "u5-l2", title: "Song: Mary Had a Little Lamb", summary: "A tune you know, now with both hands.", steps: [
                info("Add a bass line", [
                    "You have played this tune with your right hand. Now the left hand adds one long note in every measure, either C or G.",
                ]),
                practice("Left hand alone", waits, sc(Tunes.mary, left: Tunes.maryLeft), hands: [.left]),
                practice("Hands together", waits, sc(Tunes.mary, left: Tunes.maryLeft)),
                play("Mary Had a Little Lamb", inTime, sc(Tunes.mary, left: Tunes.maryLeft, tempo: 76)),
            ]),
            Lesson(id: "u5-l3", title: "Song: Ode to Joy", summary: "Beethoven with both hands.", steps: [
                info("The left hand changes more often", [
                    "The bass line again uses only C and G, but watch the final measure: the left hand plays two half notes there instead of one whole note.",
                ]),
                practice("Left hand alone", waits, sc(Tunes.odeSimple, left: Tunes.odeLeft), hands: [.left]),
                practice("Hands together", waits, sc(Tunes.odeSimple, left: Tunes.odeLeft)),
                play("Ode to Joy", inTime, sc(Tunes.odeSimple, left: Tunes.odeLeft, tempo: 80)),
            ]),
        ]
    )

    private static let holdAndPlay: Score = sc(
        "C4 D4 E4 D4 | C4 E4 G4/h | G4 F4 E4 D4 | C4/w",
        left: "C3/w | C3/w | G3/w | C3/w",
        tempo: 66
    )

    // MARK: Unit 6

    static let unit6 = CourseUnit(
        id: "u6",
        title: "Quicker Notes",
        summary: "Eighth notes and dotted rhythms.",
        lessons: [
            Lesson(id: "u6-l1", title: "Eighth Notes", summary: "Two notes to every beat.", steps: [
                info("Two notes to a beat", [
                    "Eighth notes move twice as fast as quarter notes, so two of them fit into one beat. They are usually joined in pairs by a thick beam.",
                    "Count them \"one-and, two-and\". Play the first of each pair on the click and the second exactly halfway to the next click.",
                ], figure: sc("C4/e D4/e E4/e F4/e G4/h")),
                play("Running up and down", inTime, sc("C4/e D4/e E4/e F4/e G4/h | G4/e F4/e E4/e D4/e C4/h | C4 E4/e E4/e G4 E4/e E4/e | C4/w", tempo: 60)),
                practice("Hot Cross Buns, as written", "The real rhythm has a measure of eighth notes.", sc(Tunes.hotCrossBuns)),
                play("Hot Cross Buns, as written", inTime, sc(Tunes.hotCrossBuns, tempo: 66)),
                play("Quick and slow", "Keep the quarter notes just as steady as before.", sc("E4/e D4/e C4 E4/e F4/e G4 | F4/e E4/e D4 F4/e E4/e D4 | C4/e D4/e E4/e F4/e G4 E4 | C4/w", tempo: 66)),
            ]),
            Lesson(id: "u6-l2", title: "Dotted Quarter Notes", summary: "Long-short rhythms.", steps: [
                info("A dot makes a note longer", [
                    "A dot after a note adds half of its length again. A dotted quarter note lasts one and a half beats, and it is nearly always followed by a single eighth note that completes the second beat.",
                    "Count \"one, (two), and\": hold the dotted note through the second click, then slip the short note in just after it.",
                ], figure: sc("E4/q. D4/e D4/h")),
                play("Long, short, long", inTime, sc("C4/q. D4/e E4/h | E4/q. F4/e G4/h | G4/q. F4/e E4 D4 | C4/w", tempo: 63)),
                practice("Largo", "The slow theme from Dvořák's \"New World\" Symphony is built on this rhythm.", sc(Tunes.largo)),
                play("Largo", "Slow and calm.", sc(Tunes.largo, tempo: 66)),
                play("Ode to Joy, as Beethoven wrote it", "The fourth and last measures now have the dotted rhythm.", sc(Tunes.ode, tempo: 84)),
            ]),
            Lesson(id: "u6-l3", title: "Song: Jingle Bells", summary: "Both hands, with everything so far.", steps: [
                info("Everything so far", [
                    "The chorus of this 1857 song stays inside the C position and uses quarter notes, half notes, whole notes, eighth notes and a dotted rhythm.",
                    "The left hand has one long note per measure: C, F or G.",
                ]),
                practice("Right hand", waits, sc(Tunes.jingle, left: Tunes.jingleLeft), hands: [.right]),
                practice("Hands together", waits, sc(Tunes.jingle, left: Tunes.jingleLeft)),
                play("Jingle Bells", inTime, sc(Tunes.jingle, left: Tunes.jingleLeft, tempo: 92)),
            ]),
        ]
    )

    // MARK: Unit 7

    static let unit7 = CourseUnit(
        id: "u7",
        title: "Beyond Five Notes",
        summary: "Stretch, move, and use the black keys.",
        lessons: [
            Lesson(id: "u7-l1", title: "Reaching Up to A", summary: "One more note than you have fingers.", steps: [
                info("Six notes, five fingers", [
                    "Many tunes need one more note than your hand covers. A is the white key just above G.",
                    "To reach it, let your hand open a little so that finger 5 can stretch up to A while finger 4 takes G. Then let the hand close back into the C position.",
                ], marks: [mark("C4", "C", hand: .right), mark("G4", "G", hand: .right), mark("A4", "A", hand: .right)]),
                find("Find A", "G, up to A, and back.", ["G4", "A4", "G4"]),
                practice("Twinkle, Twinkle, Little Star", "Follow the finger numbers in the first two measures.", sc(Tunes.twinkle)),
                play("Twinkle, Twinkle, Little Star", inTime, sc(Tunes.twinkle, tempo: 84)),
                practice("Long, Long Ago", "One reach up to A in the third measure.", sc(Tunes.longLongAgo), names: false),
                play("Long, Long Ago", inTime, sc(Tunes.longLongAgo, tempo: 88), names: false),
            ]),
            Lesson(id: "u7-l2", title: "Sharps and Flats", summary: "The black keys get names.", steps: [
                info("Black keys are named after their neighbours", [
                    "A sharp (♯) means the very next key to the right. A flat (♭) means the very next key to the left. So the black key just above F is F sharp, and the black key just below B is B flat.",
                    "Every black key therefore has two names: F sharp is also G flat. On the staff the sign is written just before the note, and it stays in force until the end of the measure.",
                ], marks: [mark("F#4", "F♯"), mark("Bb4", "B♭")]),
                find("Find the black keys", "Each one is named from the white key beside it.", ["F#4", "Bb4", "C#4", "Eb4"]),
                practice("D position", "Move your thumb to D. Finger 3 now plays F sharp.", sc("D4 E4 F#4 G4 | A4/h F#4/h | G4 F#4 E4 D4 | D4/w", rp: "D4")),
                practice("F position", "Thumb on F. Finger 4 plays B flat.", sc("F4 G4 A4 Bb4 | C5/h A4/h | Bb4 A4 G4 F4 | F4/w", rp: "F4")),
                info("Key signatures", [
                    "When a piece uses the same sharps or flats all the way through, they are written once at the start of every staff instead of in front of each note. This is called a key signature.",
                    "Two sharps, on the lines for F and C, mean that every F and every C in the piece is played sharp.",
                ], figure: sc("D4 E4 F#4 G4 | A4/w", key: 2, rp: "D4")),
                practice("Remember the key signature", "There are no sharp signs in front of the notes now, but every F is still F sharp.", sc("D4 E4 F#4 G4 | A4 G4 F#4 E4 | D4 F#4 A4 F#4 | D4/w", key: 2, rp: "D4")),
            ]),
            Lesson(id: "u7-l3", title: "G Position", summary: "Move the whole hand to a new place.", steps: [
                info("Positions can move", [
                    "Put your right thumb on the G above Middle C. Your five fingers now cover G, A, B, C and D.",
                    "The finger pattern is exactly the same as before. Only the notes are new.",
                ], marks: [mark("G4", "1", hand: .right), mark("A4", "2", hand: .right), mark("B4", "3", hand: .right), mark("C5", "4", hand: .right), mark("D5", "5", hand: .right)]),
                find("Find the G position", "Follow the lit keys.", ["G4", "B4", "D5", "C5", "A4"]),
                practice("Five new notes", waits, sc("G4 A4 B4 C5 | D5/h D5/h | D5 C5 B4 A4 | G4/w", rp: "G4")),
                practice("Ode to Joy in G", "The same tune you know, five notes higher.", sc(Tunes.odeInG, key: 1, rp: "G4"), names: false),
                play("Ode to Joy in G", inTime, sc(Tunes.odeInG, tempo: 84, key: 1, rp: "G4"), names: false),
            ]),
            Lesson(id: "u7-l4", title: "Song: Frère Jacques", summary: "A round that leaves the position.", steps: [
                info("Leaving the position", [
                    "This French round reaches up to A in the quick notes and then dips down to the G below Middle C at the end.",
                    "For the last two measures, let finger 2 take Middle C so that your thumb is free to reach down to G.",
                ]),
                practice("Frère Jacques", waits, sc(Tunes.frereJacques)),
                play("Frère Jacques", inTime, sc(Tunes.frereJacques, tempo: 88)),
            ]),
        ]
    )

    // MARK: Unit 8

    static let unit8 = CourseUnit(
        id: "u8",
        title: "Chords",
        summary: "Play several notes at once and accompany a tune.",
        lessons: [
            Lesson(id: "u8-l1", title: "Your First Chord", summary: "C, E and G together.", steps: [
                info("Three notes at once", [
                    "A chord is several notes played together. The C major chord uses every other key of your five-finger position: C, E and G, played with fingers 1, 3 and 5.",
                    "Press all three keys at exactly the same moment, with a relaxed wrist. On the staff the notes of a chord are stacked on top of each other.",
                ], marks: [mark("C4", "1", hand: .right), mark("E4", "3", hand: .right), mark("G4", "5", hand: .right)], figure: sc("C4 E4 G4/h | C4+E4+G4/w")),
                practice("Build the chord", "First one note at a time, then all three together.", sc("C4 E4 G4/h | C4+E4+G4/w | C4 E4 G4/h | C4+E4+G4/w")),
                practice("Left-hand chord", "The same three notes with fingers 5, 3 and 1.", sc(left: "C3 E3 G3/h | C3+E3+G3/w | C3 E3 G3/h | C3+E3+G3/w")),
                play("Chords in time", "Lift and replay the chord cleanly on each beat.", sc(left: "C3+E3+G3/w | C3+E3+G3/h C3+E3+G3/h | C3+E3+G3 C3+E3+G3 C3+E3+G3 C3+E3+G3 | C3+E3+G3/w", tempo: 66)),
            ]),
            Lesson(id: "u8-l2", title: "Three Chords: C, F and G", summary: "Change chords without moving far.", steps: [
                info("Three chords go a long way", [
                    "The chords of C, F and G are enough to accompany hundreds of songs. To keep the hand still, the notes of F and G are rearranged so that they sit close to the C chord.",
                    "For F, keep the little finger on C and move the upper two fingers up to F and A. For G, keep the thumb on G and move the lower two fingers down to B and D.",
                ], figure: sc(left: "C3+E3+G3/w | C3+F3+A3/w | B2+D3+G3/w | C3+E3+G3/w")),
                practice("Changing chords", "Move only the fingers that need to move.", sc(left: "C3+E3+G3/w | C3+F3+A3/w:5-2-1 | C3+E3+G3/w | B2+D3+G3/w:5-3-1 | C3+E3+G3/w")),
                play("Changing chords in time", "Look ahead to the next chord while you hold the current one.", sc(left: "C3+E3+G3/h C3+E3+G3/h | C3+F3+A3/h:5-2-1 C3+E3+G3/h | B2+D3+G3/h:5-3-1 B2+D3+G3/h:5-3-1 | C3+E3+G3/w", tempo: 63)),
            ]),
            Lesson(id: "u8-l3", title: "Song: Twinkle with Chords", summary: "Melody and accompaniment.", steps: [
                info("Melody and accompaniment", [
                    "This is how a great deal of piano music works: the right hand plays the tune while the left hand supplies chords underneath.",
                    "Learn the left-hand chord changes first. They follow the tune closely, changing twice in most measures.",
                ]),
                practice("Left-hand chords", waits, sc(Tunes.twinkle, left: Tunes.twinkleChords), hands: [.left]),
                practice("Hands together", waits, sc(Tunes.twinkle, left: Tunes.twinkleChords)),
                play("Twinkle, Twinkle, Little Star", inTime, sc(Tunes.twinkle, left: Tunes.twinkleChords, tempo: 76)),
            ]),
        ]
    )
}
