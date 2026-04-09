import Foundation

// MARK: - Mock Passage Data

/// Provides sample passage data for building and testing Library and Reader views
/// before backend integration. All data here is hardcoded and will be replaced
/// by real API calls in the integration phase.
enum MockPassageData {

    /// Sample passages spanning multiple CEFR levels and topics.
    static let passages: [PassageResponse] = [
        PassageResponse(
            id: "mock-001",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: "The Morning Market",
            content: "El mercado abre temprano cada ma\u{00F1}ana. Los vendedores llegan antes del amanecer para preparar sus puestos. Las frutas frescas llenan el aire con un aroma dulce. Mar\u{00ED}a camina entre los puestos, buscando los tomates m\u{00E1}s rojos. Ella siempre compra pan fresco del se\u{00F1}or Garc\u{00ED}a, que tiene la mejor panader\u{00ED}a del barrio. Hoy tambi\u{00E9}n necesita aceite de oliva y unas cebollas. El mercado est\u{00E1} lleno de gente que habla y r\u{00ED}e mientras compra. Es un lugar especial donde todos se conocen.",
            language: "es",
            cefrLevel: "A2",
            topic: "Daily Life",
            wordCount: 89,
            estimatedMinutes: 4,
            knownWordPercentage: 0.96,
            newWordCount: 12,
            isGenerated: true,
            style: "story",
            length: "short",
            readingProgress: 0.65,
            bookmarkPosition: nil,
            createdAt: "2026-04-07T10:30:00Z",
            updatedAt: "2026-04-07T11:15:00Z"
        ),
        PassageResponse(
            id: "mock-002",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: "A Trip to Barcelona",
            content: "Barcelona es una ciudad fascinante que combina historia y modernidad. La Sagrada Familia, dise\u{00F1}ada por Antoni Gaud\u{00ED}, es uno de los monumentos m\u{00E1}s impresionantes del mundo. Cada a\u{00F1}o, millones de turistas visitan esta bas\u{00ED}lica \u{00FA}nica. Las Ramblas son el coraz\u{00F3}n de la ciudad, donde puedes pasear, comer tapas y disfrutar del ambiente mediterr\u{00E1}neo. El barrio G\u{00F3}tico guarda los secretos de la ciudad medieval, con calles estrechas y plazas escondidas.",
            language: "es",
            cefrLevel: "B1",
            topic: "Travel",
            wordCount: 112,
            estimatedMinutes: 5,
            knownWordPercentage: 0.85,
            newWordCount: 15,
            isGenerated: true,
            style: "article",
            length: "medium",
            readingProgress: 0.0,
            bookmarkPosition: nil,
            createdAt: "2026-04-06T14:20:00Z",
            updatedAt: "2026-04-06T14:20:00Z"
        ),
        PassageResponse(
            id: "mock-003",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: "Letter to a Friend",
            content: "Querida Ana,\n\nEspero que est\u{00E9}s bien. Te escribo desde mi nuevo apartamento en Madrid. La mudanza fue dif\u{00ED}cil, pero ya estoy instalada. El barrio es muy bonito y tranquilo. Hay un parque peque\u{00F1}o cerca de mi casa donde paseo cada tarde. Los vecinos son muy amables.\n\nEcho de menos nuestras tardes de caf\u{00E9} en Sevilla. Cuando vengas a visitarme, te llevar\u{00E9} a un restaurante incre\u{00ED}ble que descubr\u{00ED} la semana pasada.\n\nUn abrazo fuerte,\nLuc\u{00ED}a",
            language: "es",
            cefrLevel: "A2",
            topic: "Daily Life",
            wordCount: 95,
            estimatedMinutes: 4,
            knownWordPercentage: 0.94,
            newWordCount: 8,
            isGenerated: true,
            style: "letter",
            length: "short",
            readingProgress: 1.0,
            bookmarkPosition: nil,
            createdAt: "2026-04-05T09:00:00Z",
            updatedAt: "2026-04-05T09:45:00Z"
        ),
        PassageResponse(
            id: "mock-004",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: "Technology and Daily Life",
            content: "La tecnolog\u{00ED}a ha transformado nuestra vida cotidiana de maneras que nuestros abuelos jam\u{00E1}s hubieran imaginado. Los tel\u{00E9}fonos inteligentes se han convertido en herramientas indispensables que utilizamos para comunicarnos, trabajar y entretenernos. Sin embargo, esta dependencia tecnol\u{00F3}gica tambi\u{00E9}n plantea desaf\u{00ED}os significativos. Algunos expertos advierten sobre los efectos negativos del uso excesivo de pantallas en la salud mental, especialmente entre los j\u{00F3}venes. La clave est\u{00E1} en encontrar un equilibrio saludable entre el mundo digital y las interacciones humanas reales.",
            language: "es",
            cefrLevel: "B2",
            topic: "Technology",
            wordCount: 142,
            estimatedMinutes: 7,
            knownWordPercentage: 0.78,
            newWordCount: 22,
            isGenerated: true,
            style: "article",
            length: "long",
            readingProgress: 0.30,
            bookmarkPosition: 45,
            createdAt: "2026-04-04T16:45:00Z",
            updatedAt: "2026-04-07T08:20:00Z"
        ),
        PassageResponse(
            id: "mock-005",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: "At the Caf\u{00E9}",
            content: "\u{2014}Buenos d\u{00ED}as. \u{00BF}Qu\u{00E9} desea?\n\u{2014}Hola. Quiero un caf\u{00E9} con leche, por favor.\n\u{2014}Muy bien. \u{00BF}Grande o peque\u{00F1}o?\n\u{2014}Grande, por favor.\n\u{2014}\u{00BF}Quiere algo m\u{00E1}s? Tenemos churros frescos hoy.\n\u{2014}\u{00A1}S\u{00ED}! Me encantan los churros. Quiero tres.\n\u{2014}Perfecto. Son cuatro euros con cincuenta.\n\u{2014}Aqu\u{00ED} tiene. Gracias.\n\u{2014}Gracias a usted. \u{00A1}Que disfrute!",
            language: "es",
            cefrLevel: "A1",
            topic: "Food & Cooking",
            wordCount: 68,
            estimatedMinutes: 3,
            knownWordPercentage: 0.96,
            newWordCount: 5,
            isGenerated: true,
            style: "dialogue",
            length: "short",
            readingProgress: 0.0,
            bookmarkPosition: nil,
            createdAt: "2026-04-03T11:30:00Z",
            updatedAt: "2026-04-03T11:30:00Z"
        ),
    ]

    /// Sample vocabulary annotations for the first passage ("The Morning Market").
    static let sampleVocabulary: [PassageVocabulary] = [
        PassageVocabulary(
            id: "vocab-001",
            passageId: "mock-001",
            word: "mercado",
            startIndex: 3,
            endIndex: 10,
            isHighlighted: true,
            definition: "A place where goods are bought and sold",
            translation: "market",
            phonetic: "/mer\u{02C8}ka.do/",
            wordType: "noun",
            exampleSentence: "Voy al mercado cada s\u{00E1}bado.",
            conjugationHint: nil,
            definitions: nil,
            usageNotes: nil
        ),
        PassageVocabulary(
            id: "vocab-002",
            passageId: "mock-001",
            word: "vendedores",
            startIndex: 42,
            endIndex: 52,
            isHighlighted: true,
            definition: "People who sell goods or services",
            translation: "sellers, vendors",
            phonetic: "/ben.de\u{02C8}do.res/",
            wordType: "noun",
            exampleSentence: "Los vendedores ofrecen precios buenos.",
            conjugationHint: nil,
            definitions: nil,
            usageNotes: nil
        ),
        PassageVocabulary(
            id: "vocab-003",
            passageId: "mock-001",
            word: "amanecer",
            startIndex: 70,
            endIndex: 78,
            isHighlighted: true,
            definition: "The time of day when the sun rises",
            translation: "dawn, sunrise",
            phonetic: "/a.ma.ne\u{02C8}ser/",
            wordType: "noun",
            exampleSentence: "El amanecer es muy bonito en la playa.",
            conjugationHint: nil,
            definitions: nil,
            usageNotes: nil
        ),
        PassageVocabulary(
            id: "vocab-004",
            passageId: "mock-001",
            word: "panader\u{00ED}a",
            startIndex: 292,
            endIndex: 301,
            isHighlighted: true,
            definition: "A shop where bread and pastries are made and sold",
            translation: "bakery",
            phonetic: "/pa.na.de\u{02C8}ri.a/",
            wordType: "noun",
            exampleSentence: "La panader\u{00ED}a huele a pan reci\u{00E9}n hecho.",
            conjugationHint: nil,
            definitions: nil,
            usageNotes: nil
        ),
        PassageVocabulary(
            id: "vocab-005",
            passageId: "mock-001",
            word: "aceite",
            startIndex: 335,
            endIndex: 341,
            isHighlighted: true,
            definition: "Oil, especially olive oil used in cooking",
            translation: "oil",
            phonetic: "/a\u{02C8}sei.te/",
            wordType: "noun",
            exampleSentence: "El aceite de oliva es muy saludable.",
            conjugationHint: nil,
            definitions: nil,
            usageNotes: nil
        ),
    ]

    /// Suggested topics for the custom generate mode suggested-topic box.
    static let suggestedTopics: [String] = [
        "A trip to the local market",
        "Ordering food at a restaurant",
        "A weekend at the beach",
        "Meeting a new friend",
        "A visit to the museum",
        "Cooking a family recipe",
    ]

    /// Status messages displayed during passage generation loading.
    static let loadingMessages: [String] = [
        "Brewing your passage...",
        "Simmering the vocab...",
        "Steeping in Spanish...",
        "Blending the words...",
        "Almost ready...",
    ]

    /// Sample floating words for the loading animation.
    static let floatingWords: [String] = [
        "hola", "libro", "palabra", "leer", "sol",
        "historia", "tiempo", "vida", "mundo", "luz",
        "sue\u{00F1}o", "camino",
    ]

    /// Creates a new mock passage with a generated ID and current timestamp.
    /// Used when simulating passage generation.
    static func createGeneratedPassage(
        topic: String,
        cefrLevel: String,
        style: String,
        length: String
    ) -> PassageResponse {
        let wordCount: Int = switch length {
        case "short": Int.random(in: 60...90)
        case "long": Int.random(in: 130...180)
        default: Int.random(in: 90...130)
        }

        let estimatedMinutes = max(2, wordCount / 20)

        return PassageResponse(
            id: "mock-\(UUID().uuidString.prefix(8))",
            userId: "user-001",
            userLanguageId: "lang-001",
            title: generatedTitle(for: topic),
            content: generatedContent(for: topic),
            language: "es",
            cefrLevel: cefrLevel,
            topic: topic,
            wordCount: wordCount,
            estimatedMinutes: estimatedMinutes,
            knownWordPercentage: Double.random(in: 0.80...0.96),
            newWordCount: Int.random(in: 5...20),
            isGenerated: true,
            style: style,
            length: length,
            readingProgress: 0.0,
            bookmarkPosition: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Private Helpers

    private static func generatedTitle(for topic: String) -> String {
        let titles: [String: [String]] = [
            "Travel": ["A Weekend in Seville", "The Train to Granada", "Lost in the Old Town"],
            "Food & Cooking": ["Grandmother's Recipe", "The Secret Ingredient", "Dinner for Two"],
            "Technology": ["The Digital Garden", "A New Connection", "Life Without Screens"],
            "Music & Art": ["The Last Concert", "Colors of the City", "A Song for Tomorrow"],
            "Sports": ["The Big Match", "Running at Dawn", "The Coach's Lesson"],
            "Daily Life": ["A Quiet Sunday", "The Neighbor's Dog", "Morning Routine"],
            "Nature": ["The Mountain Path", "Rain in the Forest", "By the River"],
            "History": ["The Old Bridge", "Letters from the Past", "A Forgotten Village"],
            "Science": ["Stars Above the City", "The Garden Experiment", "Water and Light"],
        ]
        let options = titles[topic] ?? ["A New Story", "Today's Passage", "Something New"]
        return options.randomElement() ?? "A New Story"
    }

    private static func generatedContent(for topic: String) -> String {
        let contents: [String: String] = [
            "Travel": "El tren sale de la estaci\u{00F3}n a las ocho de la ma\u{00F1}ana. Por la ventana se ven campos verdes y pueblos peque\u{00F1}os. El viaje dura tres horas, pero el tiempo pasa r\u{00E1}pido. Una se\u{00F1}ora mayor se sienta a mi lado y empieza a hablar de su pueblo natal. Me cuenta que vivi\u{00F3} all\u{00ED} toda su vida antes de mudarse a la ciudad.",
            "Food & Cooking": "Mi abuela siempre dec\u{00ED}a que el secreto de una buena comida est\u{00E1} en la paciencia. Ella cocinaba despacio, probando cada salsa, ajustando cada especia. Su tortilla de patatas era famosa en todo el barrio. Los s\u{00E1}bados, la cocina se llenaba del aroma del aceite caliente y las cebollas doradas.",
            "Technology": "Cada ma\u{00F1}ana, lo primero que hacemos es mirar el tel\u{00E9}fono. Las notificaciones nos esperan como peque\u{00F1}as voces que piden atenci\u{00F3}n. Pero hoy decid\u{00ED} dejarlo en la mesa y salir a caminar sin \u{00E9}l. El mundo parec\u{00ED}a diferente sin la pantalla entre mis ojos y la realidad.",
        ]
        return contents[topic] ?? "Esta es una historia nueva, escrita especialmente para ti. Cada palabra fue elegida con cuidado para ayudarte a aprender. Lee despacio, disfruta del texto, y no te preocupes si no entiendes todo. Lo importante es seguir leyendo y descubrir nuevas palabras cada d\u{00ED}a."
    }
}
