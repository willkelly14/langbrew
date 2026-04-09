import Foundation

// MARK: - Mock Passage Data

/// Provides realistic mock data for Reader view development and previews.
enum MockData {

    // MARK: - Passage Content

    // swiftlint:disable line_length
    static let spanishPassageContent = """
    Era una manana tranquila en el mercado de San Miguel. El sol entraba por las ventanas de cristal, iluminando los puestos de frutas y verduras con una luz dorada. Maria caminaba despacio entre los pasillos, disfrutando del aroma de pan recien horneado que llenaba el aire.

    Se detuvo frente a un puesto de quesos artesanales. El vendedor, un hombre mayor con un delantal blanco, le sonrio y le ofrecio una muestra de manchego curado. "Pruebe este, senora," dijo con orgullo. "Lo hacemos en nuestro pueblo, con leche de nuestras propias ovejas."

    Maria acepto la muestra y la probo con cuidado. El sabor era intenso y complejo, con notas de nuez y un toque ligeramente picante. "Esta delicioso," respondio ella. "Me llevo medio kilo, por favor."

    Mientras el vendedor cortaba el queso, Maria miro a su alrededor. Una pareja joven examinaba las aceitunas en el puesto de al lado. Un nino pequeno senalaba emocionado las frutas tropicales que nunca habia visto antes. Una mujer elegante pedia una botella de aceite de oliva virgen extra.

    El mercado era un lugar donde las historias se cruzaban. Cada persona traia su propia vida, sus propios gustos, sus propias razones para estar alli. Para Maria, venir al mercado cada sabado era mas que comprar comida. Era conectar con su barrio, con las personas que daban vida a aquellas calles estrechas y llenas de caracter.

    Despues de comprar el queso, se acerco al puesto de flores. Los tulipanes rojos le llamaron la atencion. "Cuanto cuestan los tulipanes?" pregunto. "Tres euros el ramo," contesto la florista, una mujer joven con las manos manchadas de tierra. Maria eligio un ramo y lo pago con una sonrisa.

    Con su bolsa de queso en una mano y las flores en la otra, Maria salio del mercado hacia la plaza. Se sento en un banco bajo un naranjo y respiro hondo. La ciudad vibraba a su alrededor, pero en aquel momento todo parecia perfecto y tranquilo.
    """
    // swiftlint:enable line_length

    // MARK: - Passage

    static let samplePassage = PassageResponse(
        id: "mock-passage-001",
        userId: "mock-user-001",
        userLanguageId: "mock-lang-001",
        title: "Una Manana en el Mercado",
        content: spanishPassageContent,
        language: "Spanish",
        cefrLevel: "A2",
        topic: "Daily Life",
        wordCount: 310,
        estimatedMinutes: 5,
        knownWordPercentage: 0.72,
            newWordCount: 12,
        isGenerated: true,
        style: "story",
        length: "medium",
        readingProgress: 0.0,
        bookmarkPosition: nil,
        createdAt: "2026-04-08T10:00:00Z",
        updatedAt: "2026-04-08T10:00:00Z"
    )

    // MARK: - Vocabulary Annotations

    static let sampleVocabulary: [PassageVocabulary] = [
        PassageVocabulary(
            id: "vocab-001",
            passageId: "mock-passage-001",
            word: "mercado",
            startIndex: 35,
            endIndex: 42,
            isHighlighted: true,
            definition: "A public place where goods are bought and sold; a market.",
            translation: "market",
            phonetic: "/mer.ka.do/",
            wordType: "noun",
            exampleSentence: "Voy al mercado cada domingo para comprar frutas frescas.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A public place where goods are bought and sold.",
                    example: "El mercado central esta abierto todos los dias.",
                    meaning: "marketplace"
                ),
                WordDefinition(
                    definition: "The trade or traffic in a particular commodity.",
                    example: "El mercado de valores subio hoy.",
                    meaning: "financial market"
                ),
            ],
            usageNotes: "Very common word in daily Spanish. Used for both physical markets and abstract markets (stock market, job market)."
        ),
        PassageVocabulary(
            id: "vocab-002",
            passageId: "mock-passage-001",
            word: "iluminando",
            startIndex: 102,
            endIndex: 112,
            isHighlighted: true,
            definition: "Lighting up; illuminating. Gerund form of 'iluminar'.",
            translation: "illuminating",
            phonetic: "/i.lu.mi.nan.do/",
            wordType: "verb",
            exampleSentence: "El sol estaba iluminando toda la habitacion.",
            conjugationHint: "iluminar: ilumino, iluminas, ilumina, iluminamos, iluminan",
            definitions: [
                WordDefinition(
                    definition: "To light up or make bright.",
                    example: "Las velas iluminaban la iglesia.",
                    meaning: "to illuminate"
                ),
                WordDefinition(
                    definition: "To enlighten or clarify.",
                    example: "Su explicacion ilumino el tema.",
                    meaning: "to enlighten"
                ),
            ],
            usageNotes: "Present participle (gerundio) of 'iluminar'. Used with estar for progressive tense."
        ),
        PassageVocabulary(
            id: "vocab-003",
            passageId: "mock-passage-001",
            word: "puestos",
            startIndex: 117,
            endIndex: 124,
            isHighlighted: true,
            definition: "Stalls or stands, typically in a market.",
            translation: "stalls",
            phonetic: "/pwes.tos/",
            wordType: "noun",
            exampleSentence: "Los puestos del mercado venden productos locales.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "Market stalls or stands where goods are displayed for sale.",
                    example: "Hay muchos puestos de comida en la feria.",
                    meaning: "stalls, stands"
                ),
                WordDefinition(
                    definition: "Positions or jobs.",
                    example: "Hay varios puestos disponibles en la empresa.",
                    meaning: "positions, posts"
                ),
            ],
            usageNotes: "Plural of 'puesto'. Context determines whether it means market stalls or job positions."
        ),
        PassageVocabulary(
            id: "vocab-004",
            passageId: "mock-passage-001",
            word: "disfrutando",
            startIndex: 210,
            endIndex: 221,
            isHighlighted: true,
            definition: "Enjoying. Gerund form of 'disfrutar'.",
            translation: "enjoying",
            phonetic: "/dis.fru.tan.do/",
            wordType: "verb",
            exampleSentence: "Estamos disfrutando de las vacaciones.",
            conjugationHint: "disfrutar: disfruto, disfrutas, disfruta, disfrutamos, disfrutan",
            definitions: [
                WordDefinition(
                    definition: "To enjoy or take pleasure in something.",
                    example: "Disfruta cada momento de la vida.",
                    meaning: "to enjoy"
                ),
            ],
            usageNotes: "Often used with 'de': disfrutar de algo (to enjoy something)."
        ),
        PassageVocabulary(
            id: "vocab-005",
            passageId: "mock-passage-001",
            word: "aroma",
            startIndex: 226,
            endIndex: 231,
            isHighlighted: true,
            definition: "A pleasant, distinctive smell.",
            translation: "aroma, scent",
            phonetic: "/a.ro.ma/",
            wordType: "noun",
            exampleSentence: "El aroma del cafe me despierta por la manana.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A pleasant, distinctive smell, especially from food, drink, or flowers.",
                    example: "El aroma de las rosas llenaba el jardin.",
                    meaning: "aroma, scent, fragrance"
                ),
            ],
            usageNotes: "Masculine noun despite ending in -a. El aroma, not la aroma."
        ),
        PassageVocabulary(
            id: "vocab-006",
            passageId: "mock-passage-001",
            word: "horneado",
            startIndex: 246,
            endIndex: 254,
            isHighlighted: true,
            definition: "Baked. Past participle of 'hornear'.",
            translation: "baked",
            phonetic: "/or.ne.a.do/",
            wordType: "adjective",
            exampleSentence: "El pan recien horneado tiene un sabor increible.",
            conjugationHint: "hornear: horneo, horneas, hornea, horneamos, hornean",
            definitions: [
                WordDefinition(
                    definition: "Cooked in an oven; baked.",
                    example: "Compramos pollo horneado para la cena.",
                    meaning: "baked, oven-cooked"
                ),
            ],
            usageNotes: "Past participle of 'hornear' (to bake), from 'horno' (oven)."
        ),
        PassageVocabulary(
            id: "vocab-007",
            passageId: "mock-passage-001",
            word: "delantal",
            startIndex: 369,
            endIndex: 377,
            isHighlighted: true,
            definition: "An apron worn to protect clothes.",
            translation: "apron",
            phonetic: "/de.lan.tal/",
            wordType: "noun",
            exampleSentence: "El chef siempre lleva un delantal limpio.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A protective garment worn over clothes, typically tied at the back.",
                    example: "Mi abuela tiene un delantal con flores.",
                    meaning: "apron"
                ),
            ],
            usageNotes: nil
        ),
        PassageVocabulary(
            id: "vocab-008",
            passageId: "mock-passage-001",
            word: "muestra",
            startIndex: 413,
            endIndex: 420,
            isHighlighted: true,
            definition: "A sample; also means 'shows' (verb form).",
            translation: "sample",
            phonetic: "/mwes.tra/",
            wordType: "noun",
            exampleSentence: "Le dieron una muestra gratis del perfume nuevo.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A small amount of something used to demonstrate quality.",
                    example: "Pida una muestra antes de comprar.",
                    meaning: "sample"
                ),
                WordDefinition(
                    definition: "A sign or indication of something.",
                    example: "Es una muestra de carino.",
                    meaning: "sign, token"
                ),
            ],
            usageNotes: "Can be a noun (sample/sign) or the third-person singular of 'mostrar' (to show)."
        ),
        PassageVocabulary(
            id: "vocab-009",
            passageId: "mock-passage-001",
            word: "manchego",
            startIndex: 424,
            endIndex: 432,
            isHighlighted: true,
            definition: "A Spanish cheese made from sheep's milk, from the La Mancha region.",
            translation: "Manchego (cheese)",
            phonetic: "/man.che.go/",
            wordType: "noun",
            exampleSentence: "El queso manchego es uno de los mas famosos de Espana.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A firm, buttery cheese made from Manchega sheep's milk in the La Mancha region of Spain.",
                    example: "Me gusta el manchego con membrillo.",
                    meaning: "Manchego cheese"
                ),
            ],
            usageNotes: "Named after the La Mancha region. Protected Designation of Origin (DOP) product."
        ),
        PassageVocabulary(
            id: "vocab-010",
            passageId: "mock-passage-001",
            word: "curado",
            startIndex: 433,
            endIndex: 439,
            isHighlighted: true,
            definition: "Cured; aged (referring to cheese or meat).",
            translation: "cured, aged",
            phonetic: "/ku.ra.do/",
            wordType: "adjective",
            exampleSentence: "Prefiero el jamon curado al jamon cocido.",
            conjugationHint: "curar: curo, curas, cura, curamos, curan",
            definitions: [
                WordDefinition(
                    definition: "Preserved or aged through a specific process (cheese, meat).",
                    example: "Este queso curado tiene doce meses de maduracion.",
                    meaning: "cured, aged"
                ),
                WordDefinition(
                    definition: "Healed or cured (medical context).",
                    example: "El paciente esta completamente curado.",
                    meaning: "healed, cured"
                ),
            ],
            usageNotes: "In food context, means aged/cured. In medical context, means healed."
        ),
        PassageVocabulary(
            id: "vocab-011",
            passageId: "mock-passage-001",
            word: "orgullo",
            startIndex: 473,
            endIndex: 480,
            isHighlighted: true,
            definition: "Pride; a feeling of satisfaction and self-respect.",
            translation: "pride",
            phonetic: "/or.gu.jo/",
            wordType: "noun",
            exampleSentence: "Habla de su familia con mucho orgullo.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "A feeling of deep satisfaction derived from achievements or qualities.",
                    example: "Siente orgullo por su trabajo.",
                    meaning: "pride"
                ),
            ],
            usageNotes: "Can be positive (healthy pride) or negative (arrogance) depending on context."
        ),
        PassageVocabulary(
            id: "vocab-012",
            passageId: "mock-passage-001",
            word: "sabor",
            startIndex: 608,
            endIndex: 613,
            isHighlighted: true,
            definition: "Flavor, taste.",
            translation: "flavor, taste",
            phonetic: "/sa.bor/",
            wordType: "noun",
            exampleSentence: "Este helado tiene un sabor muy rico.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "The distinctive taste of a food or drink.",
                    example: "El sabor de la paella es inconfundible.",
                    meaning: "flavor, taste"
                ),
            ],
            usageNotes: "Masculine noun. Related: saborear (to savor), sabroso (tasty)."
        ),
        PassageVocabulary(
            id: "vocab-013",
            passageId: "mock-passage-001",
            word: "aceitunas",
            startIndex: 858,
            endIndex: 867,
            isHighlighted: true,
            definition: "Olives.",
            translation: "olives",
            phonetic: "/a.sei.tu.nas/",
            wordType: "noun",
            exampleSentence: "Las aceitunas verdes son tipicas de la dieta mediterranea.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "The small oval fruit of the olive tree, eaten as food or pressed for oil.",
                    example: "Compramos un tarro de aceitunas rellenas.",
                    meaning: "olives"
                ),
            ],
            usageNotes: "Plural of 'aceituna'. From Arabic 'az-zaytuna'. Related: aceite (oil)."
        ),
        PassageVocabulary(
            id: "vocab-014",
            passageId: "mock-passage-001",
            word: "senalaba",
            startIndex: 909,
            endIndex: 917,
            isHighlighted: true,
            definition: "Was pointing at. Imperfect tense of 'senalar'.",
            translation: "was pointing at",
            phonetic: "/se.na.la.ba/",
            wordType: "verb",
            exampleSentence: "El nino senalaba las estrellas en el cielo.",
            conjugationHint: "senalar: senalo, senalas, senala, senalamos, senalan",
            definitions: [
                WordDefinition(
                    definition: "To point at or indicate something.",
                    example: "El mapa senala la ubicacion del tesoro.",
                    meaning: "to point at, to indicate"
                ),
            ],
            usageNotes: "Imperfect tense used here to describe an ongoing past action."
        ),
    ]

    // MARK: - Phrase Translations

    static let samplePhraseTranslations: [String: PhraseTranslation] = [
        "recien horneado": PhraseTranslation(
            phrase: "recien horneado",
            translation: "freshly baked",
            context: "Used to describe food that has just come out of the oven."
        ),
        "con orgullo": PhraseTranslation(
            phrase: "con orgullo",
            translation: "with pride",
            context: "A common prepositional phrase expressing the manner in which something is done."
        ),
        "aceite de oliva virgen extra": PhraseTranslation(
            phrase: "aceite de oliva virgen extra",
            translation: "extra virgin olive oil",
            context: "The highest quality grade of olive oil, very common in Spanish cuisine."
        ),
        "respiro hondo": PhraseTranslation(
            phrase: "respiro hondo",
            translation: "breathed deeply / took a deep breath",
            context: "A common expression describing a moment of relief or relaxation."
        ),
    ]
}
