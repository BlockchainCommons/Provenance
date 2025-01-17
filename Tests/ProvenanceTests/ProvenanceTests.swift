import Testing
@testable import Provenance
import WolfBase
import Foundation
import BCRandom

struct ProvenanceTests {
    @Test func testSHA256() throws {
        let data = "Hello World".utf8Data
        let digest = sha256(data)
        #expect(digest.hex == "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
    }
    
    @Test func testSHA256Joined() throws {
        let data1 = "Hello ".utf8Data
        let data2 = "World".utf8Data
        let digest = sha256([data1, data2])
        #expect(digest.hex == "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
    }
    
    @Test func testSHA256Prefix() throws {
        let data1 = "Hello ".utf8Data
        let data2 = "World".utf8Data
        let digest = sha256([data1, data2], prefix: 4)
        #expect(digest.hex == "a591a6d4")
    }
    
    @Test func testExtendKey() throws {
        let key = "Hello World".utf8Data
        let extendedKey = extendKey(key)
        #expect(extendedKey.hex == "813085a508d5fec645abe5a1fb9a23c2a6ac6bef0a99650017b3ef50538dba39")
    }
    
    @Test func testRNG() throws {
        let data = "Hello World".utf8Data
        let digest = sha256(data)
        var rng = Xoshiro256StarStar(digest)
        let key = rng.nextBytes(32)
        #expect(key.hex == "b18b446df414ec00714f19cb0f03e45cd3c3d5d071d2e7483ba8627c65b9926a")
    }
    
    @Test func testObfuscate() throws {
        let key = "Hello".utf8Data
        let message = "World".utf8Data
        let obfuscated = obfuscate(key: key, message: message)
        #expect(obfuscated.hex == "c43889aafa")
        let deobfuscated = obfuscate(key: key, message: obfuscated)
        #expect(String(decoding: deobfuscated, as: UTF8.self) == "World")
    }
    
    @Test func test2ByteDates() throws {
        let baseDate = try Date(iso8601: "2023-06-20")
        let baseDateSerialized = baseDate.serialize2Bytes()!
        #expect(baseDateSerialized.hex == "00d4")
        let baseDate2 = Date.deserialize2Bytes(‡"00d4")!
        #expect(baseDate == baseDate2)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 00000000 00100001 == 0x0021
        let minDate = try Date(iso8601: "2023-01-01")
        #expect(Date.deserialize2Bytes(‡"0021")! == minDate)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 11111111 10011111 == 0xff9f
        let maxDate = try Date(iso8601: "2150-12-31")
        #expect(Date.deserialize2Bytes(‡"ff9f")! == maxDate)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 00000000 01011110 == 0x005e == 2023-02-30 (invalid)
        #expect(Date.deserialize2Bytes(‡"005e") == nil)
    }

    @Test func test4ByteDates() throws {
        let baseDate = try Date(iso8601: "2023-06-20T12:34:56Z")
        let baseDateSerialized = baseDate.serialize4Bytes()!
        #expect(baseDateSerialized.hex == "2a41d470")
        let baseDate2 = Date.deserialize4Bytes(‡"2a41d470")!
        #expect(baseDate == baseDate2)
        
        let minDate = Date.deserialize4Bytes(‡"00000000")!
        #expect(try minDate == Date(iso8601: "2001-01-01"))
        //print(minDate.ISO8601Format())
        let maxDate = Date.deserialize4Bytes(‡"ffffffff")!
        #expect(try maxDate == Date(iso8601: "2137-02-07T06:28:15Z"))
        //print(maxDate.ISO8601Format())
    }

    @Test func test6ByteDates() throws {
        let format = Date
            .ISO8601FormatStyle()
            .year()
            .month()
            .day()
            .dateSeparator(.dash)
            .timeSeparator(.colon)
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
        let baseDate = try format.parse("2023-06-20T12:34:56.789Z")
        let baseDateSerialized = baseDate.serialize6Bytes()!
        #expect(baseDateSerialized.hex == "00a51125d895")
        let baseDate2 = Date.deserialize6Bytes(‡"00a51125d895")!
        #expect(baseDate == baseDate2)
        
        let minDate = Date.deserialize6Bytes(‡"000000000000")!
        //print(minDate.formatted(format))
        #expect(try minDate == format.parse("2001-01-01T00:00:00.000Z"))
        
        let maxDate = try format.parse("9999-12-31T23:59:59.999Z")
        #expect(maxDate.serialize6Bytes()! == ‡"e5940a78a7ff")

        // Outside allowed range <-- Y10K bug right here!
        #expect(Date.deserialize6Bytes(‡"e5940a78a800") == nil)
    }
    
    @Test func testSaveRNGState() {
        let state: (UInt64, UInt64, UInt64, UInt64) = (17295166580085024720, 422929670265678780, 5577237070365765850, 7953171132032326923)
        let data = Xoshiro256StarStar.toData(from: state)
        #expect(data.hex == "d0e72cf15ec604f0bcab28594b8cde05dab04ae79053664d0b9dadc201575f6e")
        let state2 = Xoshiro256StarStar.toState(from: data)
        let data2 = Xoshiro256StarStar.toData(from: state2)
        #expect(data == data2)
    }

    func runTest(
        resolution: ProvenanceMarkResolution,
        includeInfo: Bool = false,
        expectedDescriptions: [String] = [],
        expectedDebugDescriptions: [String] = [],
        expectedBytewords: [String] = [],
        expectedBytewordsIdentifiers: [String] = [],
        expectedBytemojiIdentifiers: [String] = [],
        expectedURs: [String] = [],
        expectedURLs: [String] = [],
        onlyPrint: Bool = false,
        rustFormat: Bool = false
    ) throws {
        let provenanceGen = ProvenanceMarkGenerator(resolution: resolution, passphrase: "Wolf")
        let count = 10
        let baseDate = try Date(iso8601: "2023-06-20T12:00:00Z")
        var calendar = Calendar.init(identifier: .gregorian)
        calendar.timeZone = .gmt
        let dates = (0..<count).map {
            calendar.date(byAdding: .day, value: $0, to: baseDate)!
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var encodedGenerator = try encoder.encode(provenanceGen)
        
        let marks = try dates.map {
            let decoder = JSONDecoder()
            var gen = try decoder.decode(ProvenanceMarkGenerator.self, from: encodedGenerator)
            
            let title: String?
            if includeInfo {
                title = "Lorem ipsum sit dolor amet."
            } else {
                title = nil
            }
            let result = gen.next(date: $0, info: title)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            encodedGenerator = try encoder.encode(gen)
            
            return result
        }
        
        #expect(ProvenanceMark.isSequenceValid(marks: marks))

        #expect(!marks[1].precedes(next: marks[0]))

        //marks.forEach { print($0.cborData.hex) }
        
        func printStart(_ swift: String, _ rust: String) {
            let s = rustFormat ? rust : swift
            print("let \(s) = [")
        }
        
        func printEnd() {
            print(rustFormat ? "];" : "]")
        }
        
        if onlyPrint || expectedDescriptions.isEmpty {
            printStart("expectedDescriptions", "expected_display")
            marks.forEach { print ("\t\"\($0.description)\",")}
            printEnd()
        } else if !expectedDescriptions.isEmpty {
            #expect(marks.map { $0.description } == expectedDescriptions)
        }
        
        if onlyPrint || expectedDebugDescriptions.isEmpty {
            printStart("expectedDebugDescriptions", "expected_debug")
            marks.forEach {
                if rustFormat {
                    print("\tr#\"\($0.debugDescription)\"#,")
                } else {
                    print("\t#\"\($0.debugDescription)\"#,")
                }
            }
            printEnd()
        } else if !expectedDebugDescriptions.isEmpty {
            #expect(marks.map { $0.debugDescription } == expectedDebugDescriptions)
        }

        let bytewords = marks.map { $0.bytewords(style: .standard) }
        if onlyPrint || expectedBytewords.isEmpty {
            printStart("expectedBytewords", "expected_bytewords")
            bytewords.forEach { print("\t\"\($0)\",") }
            printEnd()
        } else if !expectedBytewords.isEmpty {
            #expect(zip(bytewords, expectedBytewords).allSatisfy { $0.0 == $0.1 })
        }
        let bytewordsMarks = bytewords.map {
            ProvenanceMark(resolution: resolution, bytewords: $0)!
        }
        #expect(marks == bytewordsMarks)
        
        let bytewordsIdentifiers = marks.map { $0.bytewordsIdentifier(prefix: false) }
        if onlyPrint || expectedBytewordsIdentifiers.isEmpty {
            printStart("expectedBytewordsIdentifiers", "expected_id_words")
            bytewordsIdentifiers.forEach { print("\t\"\($0)\",") }
            printEnd()
        } else if !expectedBytewordsIdentifiers.isEmpty {
            #expect(zip(bytewordsIdentifiers, expectedBytewordsIdentifiers).allSatisfy { $0.0 == $0.1 })
        }
        
        let bytemojiIdentifiers = marks.map { $0.bytemojiIdentifier(prefix: false) }
        if onlyPrint || expectedBytemojiIdentifiers.isEmpty {
            printStart("expectedBytemojiIdentifiers", "expected_bytemoji_ids")
            bytemojiIdentifiers.forEach { print ("\t\"\($0)\",") }
            printEnd()
        } else if !expectedBytemojiIdentifiers.isEmpty {
            #expect(zip(bytemojiIdentifiers, expectedBytemojiIdentifiers).allSatisfy { $0.0 == $0.1 })
        }

        let urs = marks.map { $0.urString }
        if onlyPrint || expectedURs.isEmpty {
            printStart("expectedURs", "expected_urs")
            urs.forEach { print("\t\"\($0)\",") }
            printEnd()
        } else if !expectedURs.isEmpty {
            #expect(zip(urs, expectedURs).allSatisfy { $0.0 == $0.1 })
        }
        let urMarks = try urs.map {
            try ProvenanceMark(urString: $0)
        }
        #expect(marks == urMarks)

        let baseURL = URL(string: "https://example.com/validate")!
        let urls = marks.map { $0.url(base: baseURL) }
        if onlyPrint || expectedURLs.isEmpty {
            printStart("expectedURLs", "expected_urls")
            urls.forEach { print("\t\"\($0)\",") }
            printEnd()
        } else if !expectedURLs.isEmpty {
            #expect(zip(urls, expectedURLs).allSatisfy { $0.0.description == $0.1 })
        }
        let urlMarks = urls.map {
            ProvenanceMark(url: $0)!
        }
        #expect(marks == urlMarks)
                
        for mark in marks {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(mark)
            let decoder = JSONDecoder()
            let mark2 = try decoder.decode(ProvenanceMark.self, from: data)
            #expect(mark == mark2)
        }
    }
    
    @Test func testLow() throws {
        let expectedDescriptions = [
            "ProvenanceMark(5bdcec81)",
            "ProvenanceMark(477e3ce6)",
            "ProvenanceMark(3e5da986)",
            "ProvenanceMark(41c525a1)",
            "ProvenanceMark(8095afb4)",
            "ProvenanceMark(3bcacc8d)",
            "ProvenanceMark(41486af2)",
            "ProvenanceMark(5fa35da9)",
            "ProvenanceMark(e369288f)",
            "ProvenanceMark(7ce8f8bc)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8, hash: 5bdcec81, chainID: 090bf2f8, seq: 0, date: 2023-06-20)"#,
            #"ProvenanceMark(key: 558dbfc6, hash: 477e3ce6, chainID: 090bf2f8, seq: 1, date: 2023-06-21)"#,
            #"ProvenanceMark(key: 536b2968, hash: 3e5da986, chainID: 090bf2f8, seq: 2, date: 2023-06-22)"#,
            #"ProvenanceMark(key: 75bb47d0, hash: 41c525a1, chainID: 090bf2f8, seq: 3, date: 2023-06-23)"#,
            #"ProvenanceMark(key: 85cf746e, hash: 8095afb4, chainID: 090bf2f8, seq: 4, date: 2023-06-24)"#,
            #"ProvenanceMark(key: ca274110, hash: 3bcacc8d, chainID: 090bf2f8, seq: 5, date: 2023-06-25)"#,
            #"ProvenanceMark(key: de5cbde4, hash: 41486af2, chainID: 090bf2f8, seq: 6, date: 2023-06-26)"#,
            #"ProvenanceMark(key: 0f34e1b6, hash: 5fa35da9, chainID: 090bf2f8, seq: 7, date: 2023-06-27)"#,
            #"ProvenanceMark(key: 51372ca2, hash: e369288f, chainID: 090bf2f8, seq: 8, date: 2023-06-28)"#,
            #"ProvenanceMark(key: abc6aa64, hash: 7ce8f8bc, chainID: 090bf2f8, seq: 9, date: 2023-06-29)"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga rich join body jazz yurt wall monk fact urge cola exam arch kick fuel omit echo",
            "gyro lung runs skew flew yank yawn lung king sets luau idle draw aunt knob high jazz veto cola road",
            "guru jade diet iris gift zoom slot list omit ruby visa noon dark vibe road stub tied waxy race huts",
            "keep rock fuel taxi jugs fish fair fish help dull hope rust claw next urge zoom monk fern maze diet",
            "limp task jury jolt vows surf cost silk yoga king huts claw vibe mint yell quiz zinc wall join cost",
            "song deli flap blue work zone jump item heat stub mint kick gems vows love rock iris undo legs yell",
            "urge high ruby vibe fish jolt iced diet safe lion webs stub exam user work part wave fish back logo",
            "bias edge very ramp free surf wasp void hawk door also zoom gray down wall tent holy waxy leaf mint",
            "gray exam draw oboe unit yawn surf junk curl eyes keno belt crux navy need cats ruby noon yell noon",
            "play skew peck idle tent many song vibe open urge slot plus bulb free dice able keno buzz girl gear",
        ]
        let expectedBytewordsIdentifiers = [
            "HELP UNDO WASP LAZY",
            "FUEL KNOB FERN VISA",
            "FILM HILL PART LION",
            "FLAP SILK DATA OBEY",
            "LAVA MILD POSE QUIZ",
            "FAIR SONG SURF LUNG",
            "FLAP FUND ITEM WHIZ",
            "HOPE OMIT HILL PART",
            "VIAL IRON DICE MANY",
            "KITE VOWS YOGA ROOF",
        ]
        let expectedBytemojiIdentifiers = [
            "🌮 🐰 🦄 💔",
            "🍍 🪐 🦶 🐵",
            "🍊 🍱 🧮 🚩",
            "🍉 🔥 👽 🪑",
            "💛 🚀 📡 🎁",
            "🤚 🩳 👔 🛑",
            "🍉 🥝 🍄 🐢",
            "🍤 💌 🍱 🧮",
            "🐮 🍁 😻 🚗",
            "💫 🐥 🪼 🏆",
        ]
        let expectedURs = [
            "ur:provenance/lfaegdasbdwzyarhjnbyjzytwlmkftuecaemahwmfgaxcl",
            "ur:provenance/lfaegdgolgrsswfwykynlgkgssluiedwatkbhhzevlrypd",
            "ur:provenance/lfaegdgujedtisgtzmstltotryvanndkverdsbfzwsbzjk",
            "ur:provenance/lfaegdkprkfltijsfhfrfhhpdlhertcwntuezmbkfsehfr",
            "ur:provenance/lfaegdlptkjyjtvssfctskyakghscwvemtylqzjlvssnbt",
            "ur:provenance/lfaegdsgdifpbewkzejpimhtsbmtkkgsvslerkzsutcnvw",
            "ur:provenance/lfaegduehhryvefhjtiddtselnwssbemurwkptlbfmpkny",
            "ur:provenance/lfaegdbseevyrpfesfwpvdhkdraozmgydnwlttsfwscplr",
            "ur:provenance/lfaegdgyemdwoeutynsfjkcleskobtcxnyndcsdlnehglk",
            "ur:provenance/lfaegdpyswpkiettmysgveonuestpsbbfedeaevebbwyhk",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaegdasbdwzyarhjnbyjzytwlmkftuecaemahdpbswmkb",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdgolgrsswfwykynlgkgssluiedwatkbhhetpkgoyl",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdgujedtisgtzmstltotryvanndkverdsblnolzcdw",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdkprkfltijsfhfrfhhpdlhertcwntuezmsfjytaie",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdlptkjyjtvssfctskyakghscwvemtylqzptoydagm",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdsgdifpbewkzejpimhtsbmtkkgsvslerkfnmwsbrd",
            "https://example.com/validate?provenance=tngdgmgwhflfaegduehhryvefhjtiddtselnwssbemurwkptrhktfwsk",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdbseevyrpfesfwpvdhkdraozmgydnwlttbkolsguy",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdgyemdwoeutynsfjkcleskobtcxnyndcswltbrste",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdpyswpkiettmysgveonuestpsbbfedeaecphlamam",
        ]
        try runTest(
            resolution: .low,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testLowWithInfo() throws {
        let expectedDescriptions = [
            "ProvenanceMark(baee34c2)",
            "ProvenanceMark(7b80837c)",
            "ProvenanceMark(548fecfb)",
            "ProvenanceMark(f3365320)",
            "ProvenanceMark(bd61dc41)",
            "ProvenanceMark(e7d3f969)",
            "ProvenanceMark(4921b6e9)",
            "ProvenanceMark(f3d069fd)",
            "ProvenanceMark(bc4ca470)",
            "ProvenanceMark(5e798c9a)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8, hash: baee34c2, chainID: 090bf2f8, seq: 0, date: 2023-06-20, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 558dbfc6, hash: 7b80837c, chainID: 090bf2f8, seq: 1, date: 2023-06-21, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 536b2968, hash: 548fecfb, chainID: 090bf2f8, seq: 2, date: 2023-06-22, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 75bb47d0, hash: f3365320, chainID: 090bf2f8, seq: 3, date: 2023-06-23, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 85cf746e, hash: bd61dc41, chainID: 090bf2f8, seq: 4, date: 2023-06-24, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: ca274110, hash: e7d3f969, chainID: 090bf2f8, seq: 5, date: 2023-06-25, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: de5cbde4, hash: 4921b6e9, chainID: 090bf2f8, seq: 6, date: 2023-06-26, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 0f34e1b6, hash: f3d069fd, chainID: 090bf2f8, seq: 7, date: 2023-06-27, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 51372ca2, hash: bc4ca470, chainID: 090bf2f8, seq: 8, date: 2023-06-28, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: abc6aa64, hash: 5e798c9a, chainID: 090bf2f8, seq: 9, date: 2023-06-29, info: "Lorem ipsum sit dolor amet.")"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga rich join body jazz cats ugly fizz kick urge cola exam arch girl navy jugs flew unit keys flap very cyan cola flew rock zero jazz yoga owls fair glow film quad runs scar barn glow belt onyx foxy cost apex purr data wave poem",
            "gyro lung runs skew flew yank yawn lung fuel fact edge zone draw aunt knob high king wave axis game chef need mint roof stub jugs dull dull exam iron claw runs dice skew many unit vibe free taco silk code horn yurt door game rich purr wasp brag",
            "guru jade diet iris gift zoom slot list solo jowl omit vial dark vibe road stub real curl hawk lamb gyro kiln peck love lamb peck omit ramp aunt blue inky omit runs gyro fair crux lava safe real foxy zero ruby heat keep visa duty saga exit user",
            "keep rock fuel taxi jugs fish fair fish wall undo diet flap claw next urge zoom acid many kite beta time hope brag nail loud mild zero gray bias jury keep iced zoom bias real cook beta jowl very paid stub puma grim numb iced cost tied purr race",
            "limp task jury jolt vows surf cost silk silk many brag waxy vibe mint yell quiz visa curl race curl hawk visa silk axis dull skew gush jury days game data curl flap undo flux fact deli wave film swan jade lion fuel cyan menu waxy game twin even",
            "song deli flap blue work zone jump item lion tied omit next gems vows love rock fair maze ruby half need days high hope barn buzz cash keep numb city fuel cost part cats jowl webs zinc meow tuna hard view lion noon yawn yoga maze exam dice king",
            "urge high ruby vibe fish jolt iced diet solo webs echo taxi exam user work part swan user monk soap keys gush yank lazy edge yell mild half code zinc wave tiny monk gift lazy gear help saga draw down frog easy inch omit wolf memo leaf owls love",
            "bias edge very ramp free surf wasp void yank hawk even play gray down wall tent foxy puma swan jump miss gems quad lamb axis what blue mint film epic open cola visa mild zero noon hang surf purr miss also meow nail iron undo film zone arch miss",
            "gray exam draw oboe unit yawn surf junk knob code zaps whiz crux navy need cats numb cost zest buzz jump stub keno fair body need fish gush aqua bias gray urge fair curl dice bald jury days join cusp fizz fair code game miss flew oval gyro foxy",
            "play skew peck idle tent many song vibe list glow quad love bulb free dice able quad brew gray news jury flew into data oval scar veto also runs love gear legs unit runs epic task jump bias also owls luau skew trip buzz help chef note tied film",
        ]
        let expectedBytewordsIdentifiers = [
            "ROAD WAXY EDGE SAGA",
            "KING LAVA LEGS KITE",
            "GUSH MANY WASP ZERO",
            "WOLF EVEN GURU CRUX",
            "RUBY HUTS UNDO FLAP",
            "VOID TIME YURT IRON",
            "GALA CURL RAMP WALL",
            "WOLF TAXI IRON ZINC",
            "ROOF GEMS ONYX JUDO",
            "HOLY KICK LUCK NAVY",
        ]
        let expectedBytemojiIdentifiers = [
            "🔭 🐛 💪 🎾",
            "🌎 💛 💖 💫",
            "🧀 🚗 🦄 🐚",
            "🐺 🦷 🍞 😈",
            "🥁 🥠 🐰 🍉",
            "🐔 👟 🦞 🍁",
            "🍆 👹 🎉 🦆",
            "🐺 🧵 🍁 🐟",
            "🏆 🍅 📦 💨",
            "🍜 🌜 🟩 🎡",
        ]
        let expectedURs = [
            "ur:provenance/lfaehddpasbdwzyarhjnbyjzcsuyfzkkuecaemahglnyjsfwutksfpvycncafwrkzojzyaosfrgwfmqdrssrbngwbtoxfyctaxgwgewmqd",
            "ur:provenance/lfaehddpgolgrsswfwykynlgflfteezedwatkbhhkgweasgecfndmtrfsbjsdldlemincwrsdeswmyutvefetoskcehnytdrgefyutwdbn",
            "ur:provenance/lfaehddpgujedtisgtzmstltsojlotvldkverdsbrlclhklbgoknpklelbpkotrpatbeiyotrsgofrcxlaserlfyzoryhtkpvasnpmfmse",
            "ur:provenance/lfaehddpkprkfltijsfhfrfhwluodtfpcwntuezmadmykebatehebgnlldmdzogybsjykpidzmbsrlckbajlvypdsbpagmnbidvoryqzpy",
            "ur:provenance/lfaehddplptkjyjtvssfctskskmybgwyvemtylqzvaclreclhkvaskasdlswghjydsgedaclfpuofxftdiwefmsnjelnflcnmubwdauode",
            "ur:provenance/lfaehddpsgdifpbewkzejpimlntdotntgsvslerkfrmeryhfnddshhhebnbzchkpnbcyflctptcsjlwszcmwtahdvwlnnnynyajzhddmih",
            "ur:provenance/lfaehddpuehhryvefhjtiddtsowseotiemurwkptsnurmkspksghyklyeeylmdhfcezcwetymkgtlygrhpsadwdnfgeyihotwfjlweoymw",
            "ur:provenance/lfaehddpbseevyrpfesfwpvdykhkenpygydnwlttfypasnjpmsgsqdlbaswtbemtfmeconcavamdzonnhgsfprmsaomwnlinuosrmeaxld",
            "ur:provenance/lfaehddpgyemdwoeutynsfjkkbcezswzcxnyndcsnbctztbzjpsbkofrbyndfhghaabsgyuefrcldebdjydsjncpfzfrcegemsrssoguht",
            "ur:provenance/lfaehddppyswpkiettmysgveltgwqdlebbfedeaeqdbwgynsjyfwiodaolsrvoaorslegrlsutrsectkjpbsaoosluswtpbzhpvewttycx",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpasbdwzyarhjnbyjzcsuyfzkkuecaemahglnyjsfwutksfpvycncafwrkzojzyaosfrgwfmqdrssrbngwbtoxfyctaxpdkpyahl",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpgolgrsswfwykynlgflfteezedwatkbhhkgweasgecfndmtrfsbjsdldlemincwrsdeswmyutvefetoskcehnytdrgeotvoytvo",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpgujedtisgtzmstltsojlotvldkverdsbrlclhklbgoknpklelbpkotrpatbeiyotrsgofrcxlaserlfyzoryhtkpvadrmodpdl",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpkprkfltijsfhfrfhwluodtfpcwntuezmadmykebatehebgnlldmdzogybsjykpidzmbsrlckbajlvypdsbpagmnbidahlfosfe",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddplptkjyjtvssfctskskmybgwyvemtylqzvaclreclhkvaskasdlswghjydsgedaclfpuofxftdiwefmsnjelnflcnmuwkcytksw",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpsgdifpbewkzejpimlntdotntgsvslerkfrmeryhfnddshhhebnbzchkpnbcyflctptcsjlwszcmwtahdvwlnnnynyaluiofslu",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpuehhryvefhjtiddtsowseotiemurwkptsnurmkspksghyklyeeylmdhfcezcwetymkgtlygrhpsadwdnfgeyihotwflotdprkn",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpbseevyrpfesfwpvdykhkenpygydnwlttfypasnjpmsgsqdlbaswtbemtfmeconcavamdzonnhgsfprmsaomwnlinuodkplbeio",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddpgyemdwoeutynsfjkkbcezswzcxnyndcsnbctztbzjpsbkofrbyndfhghaabsgyuefrcldebdjydsjncpfzfrcegemshdynfzqz",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddppyswpkiettmysgveltgwqdlebbfedeaeqdbwgynsjyfwiodaolsrvoaorslegrlsutrsectkjpbsaoosluswtpbzhpaxtkstto",
        ]
        try runTest(
            resolution: .low,
            includeInfo: true,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testMedium() throws {
        let expectedDescriptions = [
            "ProvenanceMark(188d6bd9)",
            "ProvenanceMark(a5e79a0c)",
            "ProvenanceMark(f0580498)",
            "ProvenanceMark(161820ef)",
            "ProvenanceMark(ab14cd40)",
            "ProvenanceMark(be52dd20)",
            "ProvenanceMark(10a0cfe0)",
            "ProvenanceMark(a6378b0c)",
            "ProvenanceMark(9e740bf4)",
            "ProvenanceMark(a298dc7c)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b, hash: 188d6bd9ad8bc4f3, chainID: 090bf2f8b55be45b, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 558dbfc6536b2968, hash: a5e79a0c4ac31e1d, chainID: 090bf2f8b55be45b, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: 75bb47d085cf746e, hash: f0580498d879ef1d, chainID: 090bf2f8b55be45b, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: ca274110de5cbde4, hash: 161820ef30016ef1, chainID: 090bf2f8b55be45b, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: 0f34e1b651372ca2, hash: ab14cd40dc6c6924, chainID: 090bf2f8b55be45b, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: abc6aa642861a61a, hash: be52dd20857e89e2, chainID: 090bf2f8b55be45b, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 42c751c2012df374, hash: 10a0cfe0c0a8cc38, chainID: 090bf2f8b55be45b, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: e6528cad9d939b51, hash: a6378b0caeb1821d, chainID: 090bf2f8b55be45b, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: 5e78dd288b3915f9, hash: 9e740bf4b82e0848, chainID: 090bf2f8b55be45b, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc, hash: a298dc7c4f57bcba, chainID: 090bf2f8b55be45b, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help scar many list undo buzz puma urge hawk omit memo judo away void leaf maze numb slot back back vial join play days open tent cola visa memo",
            "gyro lung runs skew guru jade diet iris wasp rust body yoga jowl apex drop dark kite lava aunt road yank iced memo unit wasp gems echo wave diet limp tomb vial saga draw edge fact",
            "keep rock fuel taxi limp task jury jolt frog hang gems void saga epic legs curl even lava numb view toil tuna bias film drop cost flap roof slot glow aqua race aqua hard onyx peck",
            "song deli flap blue urge high ruby vibe yawn keno draw yell twin safe ramp rich silk grim apex vial surf veto limp aqua love note keys inch half solo tuna tied zinc cusp whiz hawk",
            "bias edge very ramp gray exam draw oboe redo glow tied quad onyx memo scar dull keno open cyan king ruin buzz puma urge vast scar many rich blue kiwi drop tent into runs ruby luau",
            "play skew peck idle dice huts oval city cash fizz cola idea task idea road time ugly cook grim apex zinc body into vial rich lung yawn holy gift cook undo fish iron veto puma idle",
            "flew slot gray saga acid drop wolf jury ruby easy noon luau song kept waxy list part task gush dark play huts high webs warm back kept city beta fish toys bald good exit tent yurt",
            "visa grim luck poem next menu need gray void nail epic also idle knob king kiwi unit heat buzz game news guru vial holy film figs logo help quiz apex peck free high purr zaps tomb",
            "holy keys unit dice luau eyes buzz yurt zero hard pool city curl tiny dark kiln logo quiz note tent jade gear ruby brew toil dark cyan swan whiz stub lion zone idle frog visa rock",
            "lamb slot purr keno redo blue vibe zest inky whiz drum ugly knob saga tied puff road crux yurt zinc leaf swan zero flap dark hope memo race zest jowl tiny brag code jugs cusp webs",
        ]
        let expectedBytewordsIdentifiers = [
            "CATS LUNG JADE TUNA",
            "OPEN VOID NAVY BARN",
            "WHAT HARD AQUA MONK",
            "CALM CATS CRUX WEBS",
            "PLAY BULB SWAN FIZZ",
            "RUIN GRIM UNIT CRUX",
            "BLUE NUMB TASK VAST",
            "OVAL EXAM LUAU BARN",
            "NOON JURY BALD WORK",
            "OBOE MONK UNDO KITE",
        ]
        let expectedBytemojiIdentifiers = [
            "🤠 🛑 🌹 🐶",
            "📫 🐔 🎡 🤩",
            "🐌 🍔 🙄 🚦",
            "🤢 🤠 😈 🦋",
            "💎 😵 🧢 🍌",
            "🎷 🥯 🦊 😈",
            "🥵 🚪 🧶 🐨",
            "📖 👂 🔷 🤩",
            "🔔 🌀 🥱 🐍",
            "🎈 🚦 🐰 💫",
        ]
        let expectedURs = [
            "ur:provenance/lfadhdcxasbdwzyarehpvehpsrmyltuobzpauehkotmojoayvdlfmenbstbkbkvljnpydsonurlefxhf",
            "ur:provenance/lfadhdcxgolgrsswgujedtiswprtbyyajlaxdpdkkelaatrdykidmoutwpgseowedtlptbvlsfrkmeze",
            "ur:provenance/lfadhdcxkprkfltilptkjyjtfghggsvdsaeclsclenlanbvwtltabsfmdpctfprfstgwaarebktkadjt",
            "ur:provenance/lfadhdcxsgdifpbeuehhryveynkodwyltnserprhskgmaxvlsfvolpaaleneksihhfsotatdwfrehgnt",
            "ur:provenance/lfadhdcxbseevyrpgyemdwoerogwtdqdoxmosrdlkooncnkgrnbzpauevtsrmyrhbekidpttindecsgw",
            "ur:provenance/lfadhdcxpyswpkiedehsolcychfzcaiatkiardteuyckgmaxzcbyiovlrhlgynhygtckuofhiokpbbnb",
            "ur:provenance/lfadhdcxfwstgysaaddpwfjyryeynnlusgktwyltpttkghdkpyhshhwswmbkktcybafhtsbdhypejyfs",
            "ur:provenance/lfadhdcxvagmlkpmntmundgyvdnlecaoiekbkgkiuthtbzgensguvlhyfmfslohpqzaxpkfegmdahebg",
            "ur:provenance/lfadhdcxhyksutdeluesbzytzohdplcycltydkknloqznettjegrrybwtldkcnsnwzsblnzeimttfxlb",
            "ur:provenance/lfadhdcxlbstprkorobeveztiywzdmuykbsatdpfrdcxytzclfsnzofpdkhemoreztjltybgbgvaltdn",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxasbdwzyarehpvehpsrmyltuobzpauehkotmojoayvdlfmenbstbkbkvljnpydsonsrehgsly",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxgolgrsswgujedtiswprtbyyajlaxdpdkkelaatrdykidmoutwpgseowedtlptbvltiaenndt",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxkprkfltilptkjyjtfghggsvdsaeclsclenlanbvwtltabsfmdpctfprfstgwaarecmjybarh",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxsgdifpbeuehhryveynkodwyltnserprhskgmaxvlsfvolpaaleneksihhfsotatdwsbahdge",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxbseevyrpgyemdwoerogwtdqdoxmosrdlkooncnkgrnbzpauevtsrmyrhbekidpttkpmuchmk",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxpyswpkiedehsolcychfzcaiatkiardteuyckgmaxzcbyiovlrhlgynhygtckuofhkgtocwkt",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxfwstgysaaddpwfjyryeynnlusgktwyltpttkghdkpyhshhwswmbkktcybafhtsbdfwbbkgwd",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxvagmlkpmntmundgyvdnlecaoiekbkgkiuthtbzgensguvlhyfmfslohpqzaxpkfeglnngdsk",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxhyksutdeluesbzytzohdplcycltydkknloqznettjegrrybwtldkcnsnwzsblnzekoimgspd",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxlbstprkorobeveztiywzdmuykbsatdpfrdcxytzclfsnzofpdkhemoreztjltybgbahllozt",
        ]
        try runTest(
            resolution: .medium,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testMediumWithInfo() throws {
        let expectedDescriptions = [
            "ProvenanceMark(999b6a32)",
            "ProvenanceMark(cefdeacc)",
            "ProvenanceMark(a1cb0985)",
            "ProvenanceMark(f8f50783)",
            "ProvenanceMark(317961c4)",
            "ProvenanceMark(679dce5f)",
            "ProvenanceMark(ce0d6942)",
            "ProvenanceMark(fd0e42a9)",
            "ProvenanceMark(6b3452d4)",
            "ProvenanceMark(87f1c482)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b, hash: 999b6a32516e7ff8, chainID: 090bf2f8b55be45b, seq: 0, date: 2023-06-20T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 558dbfc6536b2968, hash: cefdeacc3f161286, chainID: 090bf2f8b55be45b, seq: 1, date: 2023-06-21T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 75bb47d085cf746e, hash: a1cb09851a4b0e63, chainID: 090bf2f8b55be45b, seq: 2, date: 2023-06-22T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: ca274110de5cbde4, hash: f8f507836a2944ae, chainID: 090bf2f8b55be45b, seq: 3, date: 2023-06-23T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 0f34e1b651372ca2, hash: 317961c4b69daec5, chainID: 090bf2f8b55be45b, seq: 4, date: 2023-06-24T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: abc6aa642861a61a, hash: 679dce5fc17f6ce0, chainID: 090bf2f8b55be45b, seq: 5, date: 2023-06-25T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 42c751c2012df374, hash: ce0d69422ce2c3dd, chainID: 090bf2f8b55be45b, seq: 6, date: 2023-06-26T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: e6528cad9d939b51, hash: fd0e42a9448fca02, chainID: 090bf2f8b55be45b, seq: 7, date: 2023-06-27T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 5e78dd288b3915f9, hash: 6b3452d45e5e467d, chainID: 090bf2f8b55be45b, seq: 8, date: 2023-06-28T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc, hash: 87f1c4826fbc5d23, chainID: 090bf2f8b55be45b, seq: 9, date: 2023-06-29T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help scar many list undo buzz puma urge hawk cusp liar jugs vial claw into door play slot back back vial join play days open void mint visa help grim peck waxy jowl tuna play onyx yank many fuel brag cash brew girl tiny arch webs very vial lamb safe owls iron onyx fair lamb data flux wall",
            "gyro lung runs skew guru jade diet iris wasp rust body yoga jowl apex drop dark cash navy kept kiln lava real noon frog wasp gems echo wave diet limp tomb vial iris race even aqua bias tiny back good dice puma keys knob jazz foxy hope body gems road real able cost cost dark waxy flux jade bald zoom liar flap chef cyan lava",
            "keep rock fuel taxi limp task jury jolt frog hang gems void saga epic legs curl into brew poem yoga cash warm waxy fizz drop cost flap roof slot glow aqua race kiln peck soap inch waxy fuel flux eyes legs item hawk brag apex mild surf guru junk tomb quad high roof eyes frog pool tomb grim inky undo jowl data road into race",
            "song deli flap blue urge high ruby vibe yawn keno draw yell twin safe ramp rich down runs dark many mint song pose help love note keys inch half solo tuna tied toys into gift deli toys heat gush math kiwi flew wolf lava door eyes zero cusp fact limp leaf brew jade zoom flap knob ugly keep twin omit need oboe item dark cats",
            "bias edge very ramp gray exam draw oboe redo glow tied quad onyx memo scar dull wasp soap many zoom tiny vibe keno fish vast scar many rich blue kiwi drop tent king crux belt dark when glow king flew help diet quiz webs horn junk pool judo down mint waxy cyan keys gear chef keys urge iced each code horn bias exit love yawn",
            "play skew peck idle dice huts oval city cash fizz cola idea task idea road time also tent flap kite rich blue leaf very rich lung yawn holy gift cook undo fish void figs visa quad numb eyes taxi aunt scar guru miss kick vast echo liar atom beta gems zero duty quad memo inch quiz meow jump oboe bald ramp oboe gala fund aunt",
            "flew slot gray saga acid drop wolf jury ruby easy noon luau song kept waxy list kept iced whiz lion fuel down guru back warm back kept city beta fish toys bald vows jugs bald cyan cost zest hard able grim tomb knob wave city loud scar huts twin away heat vows frog main acid void monk foxy puma roof vast tied acid vial brew",
            "visa grim luck poem next menu need gray void nail epic also idle knob king kiwi lion idea undo webs keno join play flap film figs logo help quiz apex peck free limp zoom quiz holy jury undo maze data leaf fuel tomb huts silk keys part liar brew eyes vial fern aunt curl open lava cusp legs part nail vast wolf logo dice away",
            "holy keys unit dice luau eyes buzz yurt zero hard pool city curl tiny dark kiln kiwi work skew when lung fair wolf days toil dark cyan swan whiz stub lion zone draw yoga hawk dull rich swan tuna loud luau jury flew also oval lung axis gush song warm fish knob lava even each main glow girl tuna redo miss soap kiln noon belt",
            "lamb slot purr keno redo blue vibe zest inky whiz drum ugly knob saga tied puff note gala very apex oboe days city trip dark hope memo race zest jowl tiny brag real silk mild trip jugs quiz monk poem hang quiz numb iron what fair noon poem luau taco unit ramp figs twin veto menu wall away solo figs skew kick cola zest apex",
        ]
        let expectedBytewordsIdentifiers = [
            "NAIL NEED ITEM EASY",
            "TACO ZINC WAND SURF",
            "OBEY STUB AXIS LIMP",
            "YOGA YANK AUNT LEGS",
            "EACH KICK HUTS SETS",
            "INTO NEXT TACO HOPE",
            "TACO BELT IRON FLEW",
            "ZINC BETA FLEW PART",
            "JADE EDGE GRIM TINY",
            "LIST WHEN SETS LEAF",
        ]
        let expectedBytemojiIdentifiers = [
            "🏰 🎢 🍄 👈",
            "👓 🐟 🦉 👔",
            "🪑 👗 😭 🏁",
            "🪼 🪽 😍 💖",
            "👎 🌜 🥠 ✨",
            "🌱 🏠 👓 🍤",
            "👓 😶 🍁 🍇",
            "🐟 🤨 🍇 🧮",
            "🌹 💪 🥯 🧦",
            "💬 🐞 ✨ 💘",
        ]
        let expectedURs = [
            "ur:provenance/lfadhdfsasbdwzyarehpvehpsrmyltuobzpauehkcplrjsvlcwiodrpystbkbkvljnpydsonvdmtvahpgmpkwyjltapyoxykmyflbgchbwgltyahwsvyvllbseosinoxfrdttlhffg",
            "ur:provenance/lfadhdfsgolgrsswgujedtiswprtbyyajlaxdpdkchnyktknlarlnnfgwpgseowedtlptbvlisreenaabstybkgddepakskbjzfyhebygsrdrlaectctdkwyfxjebdzmlrchwlendl",
            "ur:provenance/lfadhdfskprkfltilptkjyjtfghggsvdsaeclscliobwpmyachwmwyfzdpctfprfstgwaareknpkspihwyflfxeslsimhkbgaxmdsfgujktbqdhhrfesfgpltbgmiyuojljkgejpcy",
            "ur:provenance/lfadhdfssgdifpbeuehhryveynkodwyltnserprhdnrsdkmymtsgpehpleneksihhfsotatdtsiogtditshtghmhkifwwfladreszocpftlplfbwjezmfpkbuykptnotndwknyehrl",
            "ur:provenance/lfadhdfsbseevyrpgyemdwoerogwtdqdoxmosrdlwpspmyzmtyvekofhvtsrmyrhbekidpttkgcxbtdkwngwkgfwhpdtqzwshnjkpljodnmtwycnksgrcfksueidehcehnhkspnehk",
            "ur:provenance/lfadhdfspyswpkiedehsolcychfzcaiatkiardteaottfpkerhbelfvyrhlgynhygtckuofhvdfsvaqdnbestiatsrgumskkvteolrambagszodyqdmoihqzmwjpoebdrpwkrhhlpd",
            "ur:provenance/lfadhdfsfwstgysaaddpwfjyryeynnlusgktwyltktidwzlnfldngubkwmbkktcybafhtsbdvsjsbdcnctzthdaegmtbkbwecyldsrhstnayhtvsfgmnadvdmkfyparfvtlrwnynrf",
            "ur:provenance/lfadhdfsvagmlkpmntmundgyvdnlecaoiekbkgkilniauowskojnpyfpfmfslohpqzaxpkfelpzmqzhyjyuomedalffltbhsskksptlrbwesvlfnatclonlacplsptnlvtonksfsos",
            "ur:provenance/lfadhdfshyksutdeluesbzytzohdplcycltydkknkiwkswwnlgfrwfdstldkcnsnwzsblnzedwyahkdlrhsntaldlujyfwaoollgasghsgwmfhkblaenehmngwgltaromsnnleluoe",
            "ur:provenance/lfadhdfslbstprkorobeveztiywzdmuykbsatdpfnegavyaxoedscytpdkhemoreztjltybgrlskmdtpjsqzmkpmhgqznbinwtfrnnpmlutoutrpfstnvomuwlaysofsswdlwewlps",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfsasbdwzyarehpvehpsrmyltuobzpauehkcplrjsvlcwiodrpystbkbkvljnpydsonvdmtvahpgmpkwyjltapyoxykmyflbgchbwgltyahwsvyvllbseosinoxfrchhhfnzo",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfsgolgrsswgujedtiswprtbyyajlaxdpdkchnyktknlarlnnfgwpgseowedtlptbvlisreenaabstybkgddepakskbjzfyhebygsrdrlaectctdkwyfxjebdzmlrdthnhhmo",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfskprkfltilptkjyjtfghggsvdsaeclscliobwpmyachwmwyfzdpctfprfstgwaareknpkspihwyflfxeslsimhkbgaxmdsfgujktbqdhhrfesfgpltbgmiyuojlgtsrcsos",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfssgdifpbeuehhryveynkodwyltnserprhdnrsdkmymtsgpehpleneksihhfsotatdtsiogtditshtghmhkifwwfladreszocpftlplfbwjezmfpkbuykptnotndsgbwhpbk",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfsbseevyrpgyemdwoerogwtdqdoxmosrdlwpspmyzmtyvekofhvtsrmyrhbekidpttkgcxbtdkwngwkgfwhpdtqzwshnjkpljodnmtwycnksgrcfksueidehcehniofpykve",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfspyswpkiedehsolcychfzcaiatkiardteaottfpkerhbelfvyrhlgynhygtckuofhvdfsvaqdnbestiatsrgumskkvteolrambagszodyqdmoihqzmwjpoebdrpsgdyembz",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfsfwstgysaaddpwfjyryeynnlusgktwyltktidwzlnfldngubkwmbkktcybafhtsbdvsjsbdcnctzthdaegmtbkbwecyldsrhstnayhtvsfgmnadvdmkfyparfvtrdksnsad",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfsvagmlkpmntmundgyvdnlecaoiekbkgkilniauowskojnpyfpfmfslohpqzaxpkfelpzmqzhyjyuomedalffltbhsskksptlrbwesvlfnatclonlacplsptnlvtndwnhgcy",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfshyksutdeluesbzytzohdplcycltydkknkiwkswwnlgfrwfdstldkcnsnwzsblnzedwyahkdlrhsntaldlujyfwaoollgasghsgwmfhkblaenehmngwgltaromsnbaxvyct",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfslbstprkorobeveztiywzdmuykbsatdpfnegavyaxoedscytpdkhemoreztjltybgrlskmdtpjsqzmkpmhgqznbinwtfrnnpmlutoutrpfstnvomuwlaysofsswbyielsby",
        ]
        try runTest(
            resolution: .medium,
            includeInfo: true,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testQuartile() throws {
        let expectedDescriptions = [
            "ProvenanceMark(4a0738a3)",
            "ProvenanceMark(d95dc357)",
            "ProvenanceMark(a427f3d2)",
            "ProvenanceMark(706fada0)",
            "ProvenanceMark(2ad78680)",
            "ProvenanceMark(94169f21)",
            "ProvenanceMark(479cac60)",
            "ProvenanceMark(575cbdd1)",
            "ProvenanceMark(cfc526bf)",
            "ProvenanceMark(a308d3f2)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b4661b24b7e9c340c, hash: 4a0738a31a3e9073f1c01999cd01ff0a, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 558dbfc6536b296875bb47d085cf746e, hash: d95dc3573bee6e1f4504ce6e971de31a, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: ca274110de5cbde40f34e1b651372ca2, hash: a427f3d2f56c956e715d05089a9c1125, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: abc6aa642861a61a42c751c2012df374, hash: 706fada07359cfc46e9f227405e5a50a, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: e6528cad9d939b515e78dd288b3915f9, hash: 2ad78680ddfa4a7789cfc974b99edab3, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc14a72ac53b5cd9b5, hash: 94169f216caa0853c1108435cf51856f, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 445dbfc1264fd6de95b5ca8c060c24ba, hash: 479cac604e8b022e0f63688f165a4334, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 1dadf8aa6a2b2fa657fc7a0225d1880e, hash: 575cbdd132391fc3a0d5f1f2038d1923, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: 5946b5fd32e588c593923750478d74d4, hash: cfc526bf20716acb922a0eb52c4e88f7, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 469cbdca128f2d85d803e81b3e0e3a7d, hash: a308d3f2b0cb42330b971ceef18a168e, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help frog huts purr gear knob news edge barn inky jump mild warm warm pose obey ruby very hill yank song frog into maze work exam veto foxy iron quiz edge arch cusp blue gray zaps task saga half monk jolt menu peck fern fizz item cost rich mild nail omit lazy song meow claw",
            "gyro lung runs skew guru jade diet iris keep rock fuel taxi limp task jury jolt fair puma luau fact lamb days eyes eyes omit ruin lava eyes soap huts fact part swan many king visa scar yank part trip drop fund toys twin sets door tied whiz huts guru logo skew exam scar brew jolt work memo flew knob inch list",
            "song deli flap blue urge high ruby vibe bias edge very ramp gray exam draw oboe redo loud lion item yurt lion taxi oval chef crux song quiz need pose rust void wave aunt oval tomb aqua numb limp grim buzz body navy wave taxi flux cook kite wave owls ruby work view memo frog road tomb ruin webs owls rock frog",
            "play skew peck idle dice huts oval city flew slot gray saga acid drop wolf jury fern tomb hope keys down plus keno able twin claw oval jugs bulb horn taxi twin jury draw deli bias exam love vial item song silk saga curl runs fact flux vast rock road toil ramp diet cusp buzz eyes gear flew part math drop yoga",
            "visa grim luck poem next menu need gray holy keys unit dice luau eyes buzz yurt zone jazz tomb days purr when main vast work eyes diet kept onyx visa fact iron limp drop swan gear fair paid kiln grim math scar flew cash soap memo cusp flew jump zone oval unit main ramp taxi also memo wall numb dull webs vial",
            "lamb slot purr keno redo blue vibe zest bulb owls door silk fair high tuna race idle main scar gear vast numb urge wasp lamb memo poem into void idle ruin arch horn kick even zone unit gift easy puma flux view edge edge gift lava zest mild apex wall logo hang film webs tent race safe huts visa gems away undo",
            "foxy hill runs safe days glow tomb urge mild race song luck atom barn dark road work foxy meow crux flux back jugs also flew purr liar jugs knob drum monk race bias idle oval peck leaf noon soap cats grim king wasp keys gems flap bald news king kick arch fern guru kick edge eyes fern pose gift curl join curl",
            "cola poem yoga peck item down dull oval hang zest kiln also data tent logo beta body yurt mint code jugs scar task oval wolf belt stub hard edge memo cost fish heat miss gala jade main cook safe help belt kick even liar idle lung vows chef unit toil hope crux liar yell what cusp noon aqua yurt dull fund taxi",
            "hawk frog race zinc easy view logo silk menu memo exam good fuel lung jury tiny able kick iced iced free visa down undo time ruin tent jump body kiwi cook saga hope body owls beta half flux free gray keep mild slot edge jump join undo judo aqua owls work safe vast apex song aqua help eyes jade zone zinc gems",
            "frog news ruby song brag many drop limp trip apex vows claw film beta fact kiwi fern ruin luck hard city paid nail grim flux zaps ramp kiwi exam tent free even gray film brag purr pool cost skew body zone zinc eyes half yoga easy vial puma brew loud real surf warm ugly cats away lamb beta hawk exam trip plus",
        ]
        let expectedBytewordsIdentifiers = [
            "GAME AUNT EXIT OMIT",
            "TUNA HILL SCAR HANG",
            "ONYX DELI WOLF TIED",
            "JUDO JOWL POEM NUMB",
            "DOOR TOYS LION LAVA",
            "MEOW CALM NOTE CURL",
            "FUEL NEWS PLUS HORN",
            "HANG HIGH RUBY TENT",
            "TASK SILK DAYS RUNS",
            "OMIT AWAY TIME WHIZ",
        ]
        let expectedBytemojiIdentifiers = [
            "🥑 😍 👃 💌",
            "🐶 🍱 🏓 🌭",
            "📦 😹 🐺 👠",
            "💨 🌸 ⏰ 🚪",
            "🙀 👜 🚩 💛",
            "🚨 🤢 🔑 👹",
            "🍍 🎠 📷 🍚",
            "🌭 🥙 🥁 💍",
            "🧶 🔥 😺 🎺",
            "💌 😘 👟 🐢",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdftasbdwzyarehpvehpfghsprgrkbnseebniyjpmdwmwmpeoyryvyhlyksgfgiomewkemvofyinqzeeahcpbegyzstksahfmkjtmupkfnfzimctrhmdnlotcywzfrzo",
            "ur:provenance/lfaohdftgolgrsswgujedtiskprkfltilptkjyjtfrpaluftlbdsesesotrnlaessphsftptsnmykgvasrykpttpdpfdtstnssdrtdwzhsguloswemsrbwjtwkmotafgsgio",
            "ur:provenance/lfaohdftsgdifpbeuehhryvebseevyrpgyemdwoeroldlnimytlntiolcfcxsgqzndpertvdweatoltbaanblpgmbzbynywetifxckkeweosrywkvwmofgrdtbrnjynebbol",
            "ur:provenance/lfaohdftpyswpkiedehsolcyfwstgysaaddpwfjyfntbheksdnpskoaetncwoljsbbhntitnjydwdibsemlevlimsgsksaclrsftfxvtrkrdtlrpdtcpbzesgrfweypdlfcs",
            "ur:provenance/lfaohdftvagmlkpmntmundgyhyksutdeluesbzytzejztbdsprwnmnvtwkesdtktoxvaftinlpdpsngrfrpdkngmmhsrfwchspmocpfwjpzeolutmnrptiaomowlfrchfzax",
            "ur:provenance/lfaohdftlbstprkorobeveztbbosdrskfrhhtareiemnsrgrvtnbuewplbmopmiovdiernahhnkkenzeutgteypafxvweeeegtlaztmdaxwllohgfmwsttresehskijyosfn",
            "ur:provenance/lfaohdftfyhlrssedsgwtbuemdresglkambndkrdwkfymwcxfxbkjsaofwprlrjskbdmmkrebsieolpklfnnspcsgmkgwpksgsfpbdnskgkkahfngukkeeesfnpetbcfsase",
            "ur:provenance/lfaohdftcapmyapkimdndlolhgztknaodattlobabyytmtcejssrtkolwfbtsbhdeemoctfhhtmsgajemncksehpbtkkenlrielgvscfuttlhecxlrylwtcpnnaaidchvddy",
            "ur:provenance/lfaohdfthkfgrezceyvwloskmumoemgdfllgjytyaekkididfevadnuoternttjpbykicksahebyosbahffxfegykpmdsteejpjnuojoaaoswksevtaxsgaahpeswtswgmps",
            "ur:provenance/lfaohdftfgnsrysgbgmydplptpaxvscwfmbaftkifnrnlkhdcypdnlgmfxzsrpkiemttfeengyfmbgprplctswbyzezceshfyaeyvlpabwldrlsfwmuycsaylbbasabsktgs",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftasbdwzyarehpvehpfghsprgrkbnseebniyjpmdwmwmpeoyryvyhlyksgfgiomewkemvofyinqzeeahcpbegyzstksahfmkjtmupkfnfzimctrhmdnlothposhyuo",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftgolgrsswgujedtiskprkfltilptkjyjtfrpaluftlbdsesesotrnlaessphsftptsnmykgvasrykpttpdpfdtstnssdrtdwzhsguloswemsrbwjtwkmomkbwpefz",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftsgdifpbeuehhryvebseevyrpgyemdwoeroldlnimytlntiolcfcxsgqzndpertvdweatoltbaanblpgmbzbynywetifxckkeweosrywkvwmofgrdtbrnecsgjsly",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftpyswpkiedehsolcyfwstgysaaddpwfjyfntbheksdnpskoaetncwoljsbbhntitnjydwdibsemlevlimsgsksaclrsftfxvtrkrdtlrpdtcpbzesgrfwjkzcvdfh",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftvagmlkpmntmundgyhyksutdeluesbzytzejztbdsprwnmnvtwkesdtktoxvaftinlpdpsngrfrpdkngmmhsrfwchspmocpfwjpzeolutmnrptiaomowlknfwdadk",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftlbstprkorobeveztbbosdrskfrhhtareiemnsrgrvtnbuewplbmopmiovdiernahhnkkenzeutgteypafxvweeeegtlaztmdaxwllohgfmwsttresehsfnclsacw",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftfyhlrssedsgwtbuemdresglkambndkrdwkfymwcxfxbkjsaofwprlrjskbdmmkrebsieolpklfnnspcsgmkgwpksgsfpbdnskgkkahfngukkeeesfnpemsgsosva",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftcapmyapkimdndlolhgztknaodattlobabyytmtcejssrtkolwfbtsbhdeemoctfhhtmsgajemncksehpbtkkenlrielgvscfuttlhecxlrylwtcpnnaacnfwlfch",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfthkfgrezceyvwloskmumoemgdfllgjytyaekkididfevadnuoternttjpbykicksahebyosbahffxfegykpmdsteejpjnuojoaaoswksevtaxsgaahpespamuemlu",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftfgnsrysgbgmydplptpaxvscwfmbaftkifnrnlkhdcypdnlgmfxzsrpkiemttfeengyfmbgprplctswbyzezceshfyaeyvlpabwldrlsfwmuycsaylbbalshtbgje",
        ]
        try runTest(
            resolution: .quartile,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testQuartileWithInfo() throws {
        let expectedDescriptions = [
            "ProvenanceMark(5bbcccab)",
            "ProvenanceMark(9b1f7fe6)",
            "ProvenanceMark(89272fb4)",
            "ProvenanceMark(363c21c2)",
            "ProvenanceMark(8a9828a8)",
            "ProvenanceMark(50aeeb37)",
            "ProvenanceMark(84e26272)",
            "ProvenanceMark(25c8850f)",
            "ProvenanceMark(9ade9daa)",
            "ProvenanceMark(1c0b6f5e)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b4661b24b7e9c340c, hash: 5bbcccab578f10c794a2a66fd42abff1, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 0, date: 2023-06-20T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 558dbfc6536b296875bb47d085cf746e, hash: 9b1f7fe61f3f9a2fbfc5f896b5e1bb5c, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 1, date: 2023-06-21T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: ca274110de5cbde40f34e1b651372ca2, hash: 89272fb4945aa03ce0efe8bb7d454773, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 2, date: 2023-06-22T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: abc6aa642861a61a42c751c2012df374, hash: 363c21c2ca486cd34922912670a6c525, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 3, date: 2023-06-23T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: e6528cad9d939b515e78dd288b3915f9, hash: 8a9828a898c97d76e114d00af3bcdc1d, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 4, date: 2023-06-24T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc14a72ac53b5cd9b5, hash: 50aeeb375a05e2f870f302b221972dd2, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 5, date: 2023-06-25T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 445dbfc1264fd6de95b5ca8c060c24ba, hash: 84e2627277ea03eb2384ce167bba24a3, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 6, date: 2023-06-26T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 1dadf8aa6a2b2fa657fc7a0225d1880e, hash: 25c8850f0d4f74aefaea5460f5990317, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 7, date: 2023-06-27T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 5946b5fd32e588c593923750478d74d4, hash: 9ade9daaa70c28c38b6de6b5e93f7174, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 8, date: 2023-06-28T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 469cbdca128f2d85d803e81b3e0e3a7d, hash: 1c0b6f5e7521a6ebd2d2e96adae4df25, chainID: 090bf2f8b55be45b4661b24b7e9c340c, seq: 9, date: 2023-06-29T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help frog huts purr gear knob news edge barn inky jump mild warm warm pose obey ruby very hill yank song frog into maze work days hawk puff huts yurt limp limp mint keep echo free eyes ugly kiwi trip mild menu peck fern fizz item cost rich mild nail omit drum meow sets work zinc edge beta zero draw redo king math real dice onyx cats help iris join oboe nail slot barn news jury fact miss eyes love jury soap surf nail",
            "gyro lung runs skew guru jade diet iris keep rock fuel taxi limp task jury jolt fair puma luau fact lamb days eyes eyes omit ruin lava eyes soap huts fact part many swan slot hang void dark hill vows toys loud very cusp visa tomb love quiz huts guru logo skew exam scar brew jolt work memo task puma ramp zest redo high body trip many body door zest soap idle fish kiln webs kiwi jowl redo roof play warm able gems figs miss back visa silk lava quiz aunt",
            "song deli flap blue urge high ruby vibe bias edge very ramp gray exam draw oboe redo loud lion item yurt lion taxi oval chef crux song quiz need pose rust void rust aunt kiln puff inch mint puff able liar omit kept holy exam navy fund door wave owls ruby work view memo frog road tomb ruin data paid curl king scar axis flew math logo kiln frog jury flap judo omit peck edge pose unit code void puma maze road item ramp unit poem lamb task pose wave dull",
            "play skew peck idle dice huts oval city flew slot gray saga acid drop wolf jury fern tomb hope keys down plus keno able twin claw oval jugs bulb horn taxi twin easy lamb play join main need fizz kiwi wave keys jugs junk song kick cyan task rock road toil ramp diet cusp buzz eyes gear flew plus rock gift logo veto play calm sets yawn taco maze sets tomb owls dark film game item tent game lung ruby tuna blue calm trip help game kite warm luck fish work",
            "visa grim luck poem next menu need gray holy keys unit dice luau eyes buzz yurt zone jazz tomb days purr when main vast work eyes diet kept onyx visa fact iron data iced idea idea knob need gift guru yoga cats help iron leaf puff dark wasp jump zone oval unit main ramp taxi also memo wall even meow open menu hawk into frog inky wand task data surf yank half door grim kiln huts quiz huts item gala scar loud yoga dice webs zero keno gala lung slot lazy",
            "lamb slot purr keno redo blue vibe zest bulb owls door silk fair high tuna race idle main scar gear vast numb urge wasp lamb memo poem into void idle ruin arch onyx safe flew vows warm veto trip city whiz atom purr quad omit frog gush dice apex wall logo hang film webs tent race safe huts flew what love memo omit inky yawn paid puff saga kick fish dull many peck free play nail yawn scar keep idle part into zest wolf calm help fern wolf lung keep kiwi",
            "foxy hill runs safe days glow tomb urge mild race song luck atom barn dark road work foxy meow crux flux back jugs also flew purr liar jugs knob drum monk race surf city iris redo rock zoom solo unit knob news game very curl obey jazz bald king kick arch fern guru kick edge eyes fern pose aqua zone flew jolt jury game monk huts drop vows gyro undo figs king crux luck unit nail zoom blue cats gush vibe yurt omit flew zoom item vibe fern iced diet edge",
            "cola poem yoga peck item down dull oval hang zest kiln also data tent logo beta body yurt mint code jugs scar task oval wolf belt stub hard edge memo cost fish dice apex jugs race puma iris peck even hang frog menu calm memo nail whiz drop unit toil hope crux liar yell what cusp noon aqua work exam trip miss skew easy what free scar rock data body help roof away item king swan keep chef legs purr half kite brag gray lion hope love iris love road list",
            "hawk frog race zinc easy view logo silk menu memo exam good fuel lung jury tiny able kick iced iced free visa down undo time ruin tent jump body kiwi cook saga back back code claw tent film aunt hawk jazz tied dull edge real code data wolf aqua owls work safe vast apex song aqua help eyes news kite drop body bulb when junk diet jolt limp memo onyx girl echo omit crux draw axis whiz door huts edge numb jade real loud ruin saga fish obey wolf race good",
            "frog news ruby song brag many drop limp trip apex vows claw film beta fact kiwi fern ruin luck hard city paid nail grim flux zaps ramp kiwi exam tent free even waxy figs pool cook jade yank cusp solo deli redo surf tied time high door city brew loud real surf warm ugly cats away lamb beta judo diet work monk down vial visa menu also city view help solo real taxi visa flap apex edge help iron cost warm fuel chef free surf fact legs vows judo wall cats",
        ]
        let expectedBytewordsIdentifiers = [
            "HELP ROOF SURF PLAY",
            "NEED COST LAMB VISA",
            "LOUD DELI DULL QUIZ",
            "EVEN FERN CURL SAGA",
            "LOVE MONK DICE PAID",
            "GOOD POOL WARM EXAM",
            "LIAR VETO ICED JUMP",
            "DATA SOAP LIMP BIAS",
            "NAVY URGE NEXT PECK",
            "CODE BALD JOWL HOLY",
        ]
        let expectedBytemojiIdentifiers = [
            "🌮 🏆 👔 💎",
            "🎢 🤯 🌐 🐵",
            "🚫 😹 🤝 🎁",
            "🦷 🦶 👹 🎾",
            "🔴 🚦 😻 📌",
            "🧄 ⏳ 🐴 👂",
            "💕 🦁 🍨 💧",
            "👽 👚 🏁 🫥",
            "🎡 🐻 🏠 🔒",
            "😬 🥱 🌸 🍜",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdhgasbdwzyarehpvehpfghsprgrkbnseebniyjpmdwmwmpeoyryvyhlyksgfgiomewkdshkpfhsytlplpmtkpeofeesuykitpmdmupkfnfzimctrhmdnlotdmmwsswkzceebazodwrokgmhrldeoxcshpisjnoenlstbnnsjyftmseslejolemozs",
            "ur:provenance/lfaohdhggolgrsswgujedtiskprkfltilptkjyjtfrpaluftlbdsesesotrnlaessphsftptmysnsthgvddkhlvstsldvycpvatbleqzhsguloswemsrbwjtwkmotkparpztrohhbytpmybydrztspiefhknwskijlrorfpywmaegsfsmsbkvasesawdie",
            "ur:provenance/lfaohdhgsgdifpbeuehhryvebseevyrpgyemdwoeroldlnimytlntiolcfcxsgqzndpertvdrtatknpfihmtpfaelrotkthyemnyfddrweosrywkvwmofgrdtbrndapdclkgsrasfwmhloknfgjyfpjootpkeepeutcevdpamerdimrputpmlbsbweqdgs",
            "ur:provenance/lfaohdhgpyswpkiedehsolcyfwstgysaaddpwfjyfntbheksdnpskoaetncwoljsbbhntitneylbpyjnmnndfzkiweksjsjksgkkcntkrkrdtlrpdtcpbzesgrfwpsrkgtlovopycmssyntomesstbosdkfmgeimttgelgrytabecmtphpgekewstohsms",
            "ur:provenance/lfaohdhgvagmlkpmntmundgyhyksutdeluesbzytzejztbdsprwnmnvtwkesdtktoxvaftindaidiaiakbndgtguyacshpinlfpfdkwpjpzeolutmnrptiaomowlenmwonmuhkiofgiywdtkdasfykhfdrgmknhsqzhsimgasrldyadewszokogttknlvo",
            "ur:provenance/lfaohdhglbstprkorobeveztbbosdrskfrhhtareiemnsrgrvtnbuewplbmopmiovdiernahoxsefwvswmvotpcywzamprqdotfgghdeaxwllohgfmwsttresehsfwwtlemootiyynpdpfsakkfhdlmypkfepynlynsrkpieptioztwfcmhpfnyltkdnck",
            "ur:provenance/lfaohdhgfyhlrssedsgwtbuemdresglkambndkrdwkfymwcxfxbkjsaofwprlrjskbdmmkresfcyisrorkzmsoutkbnsgevycloyjzbdkgkkahfngukkeeesfnpeaazefwjtjygemkhsdpvsgouofskgcxlkutnlzmbecsghveytotfwzmimveetcxkthg",
            "ur:provenance/lfaohdhgcapmyapkimdndlolhgztknaodattlobabyytmtcejssrtkolwfbtsbhdeemoctfhdeaxjsrepaispkenhgfgmucmmonlwzdputtlhecxlrylwtcpnnaawkemtpmssweywtfesrrkdabyhprfayimkgsnkpcflsprhfkebggylnhelejzspveve",
            "ur:provenance/lfaohdhghkfgrezceyvwloskmumoemgdfllgjytyaekkididfevadnuoternttjpbykicksabkbkcecwttfmathkjztddleerlcedawfaaoswksevtaxsgaahpesnskedpbybbwnjkdtjtlpmooxgleootcxdwaswzdrhseenbjerlldrnsafhonpawmeo",
            "ur:provenance/lfaohdhgfgnsrysgbgmydplptpaxvscwfmbaftkifnrnlkhdcypdnlgmfxzsrpkiemttfeenwyfsplckjeykcpsodirosftdtehhdrcybwldrlsfwmuycsaylbbajodtwkmkdnvlvamuaocyvwhpsorltivafpaxeehpinctwmflcffesfftlswpeyrlkg",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgasbdwzyarehpvehpfghsprgrkbnseebniyjpmdwmwmpeoyryvyhlyksgfgiomewkdshkpfhsytlplpmtkpeofeesuykitpmdmupkfnfzimctrhmdnlotdmmwsswkzceebazodwrokgmhrldeoxcshpisjnoenlstbnnsjyftmsesletpjkuykp",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhggolgrsswgujedtiskprkfltilptkjyjtfrpaluftlbdsesesotrnlaessphsftptmysnsthgvddkhlvstsldvycpvatbleqzhsguloswemsrbwjtwkmotkparpztrohhbytpmybydrztspiefhknwskijlrorfpywmaegsfsmsbkvainfrotwm",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgsgdifpbeuehhryvebseevyrpgyemdwoeroldlnimytlntiolcfcxsgqzndpertvdrtatknpfihmtpfaelrotkthyemnyfddrweosrywkvwmofgrdtbrndapdclkgsrasfwmhloknfgjyfpjootpkeepeutcevdpamerdimrputpmlbiabbzssr",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgpyswpkiedehsolcyfwstgysaaddpwfjyfntbheksdnpskoaetncwoljsbbhntitneylbpyjnmnndfzkiweksjsjksgkkcntkrkrdtlrpdtcpbzesgrfwpsrkgtlovopycmssyntomesstbosdkfmgeimttgelgrytabecmtphpgekeflemdecs",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgvagmlkpmntmundgyhyksutdeluesbzytzejztbdsprwnmnvtwkesdtktoxvaftindaidiaiakbndgtguyacshpinlfpfdkwpjpzeolutmnrptiaomowlenmwonmuhkiofgiywdtkdasfykhfdrgmknhsqzhsimgasrldyadewszokovwentijn",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhglbstprkorobeveztbbosdrskfrhhtareiemnsrgrvtnbuewplbmopmiovdiernahoxsefwvswmvotpcywzamprqdotfgghdeaxwllohgfmwsttresehsfwwtlemootiyynpdpfsakkfhdlmypkfepynlynsrkpieptioztwfcmhpfnheenidme",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgfyhlrssedsgwtbuemdresglkambndkrdwkfymwcxfxbkjsaofwprlrjskbdmmkresfcyisrorkzmsoutkbnsgevycloyjzbdkgkkahfngukkeeesfnpeaazefwjtjygemkhsdpvsgouofskgcxlkutnlzmbecsghveytotfwzmimvemhtafmtp",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgcapmyapkimdndlolhgztknaodattlobabyytmtcejssrtkolwfbtsbhdeemoctfhdeaxjsrepaispkenhgfgmucmmonlwzdputtlhecxlrylwtcpnnaawkemtpmssweywtfesrrkdabyhprfayimkgsnkpcflsprhfkebggylnhelessehpmje",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhghkfgrezceyvwloskmumoemgdfllgjytyaekkididfevadnuoternttjpbykicksabkbkcecwttfmathkjztddleerlcedawfaaoswksevtaxsgaahpesnskedpbybbwnjkdtjtlpmooxgleootcxdwaswzdrhseenbjerlldrnsafhbtfdoerf",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhgfgnsrysgbgmydplptpaxvscwfmbaftkifnrnlkhdcypdnlgmfxzsrpkiemttfeenwyfsplckjeykcpsodirosftdtehhdrcybwldrlsfwmuycsaylbbajodtwkmkdnvlvamuaocyvwhpsorltivafpaxeehpinctwmflcffesfftlsfysbzewk",
        ]
        try runTest(
            resolution: .quartile,
            includeInfo: true,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testHigh() throws {
        let expectedDescriptions = [
            "ProvenanceMark(8cd8e51f)",
            "ProvenanceMark(c5c043de)",
            "ProvenanceMark(211f5570)",
            "ProvenanceMark(fb67f81a)",
            "ProvenanceMark(33cf4029)",
            "ProvenanceMark(96fe484a)",
            "ProvenanceMark(99356fdd)",
            "ProvenanceMark(a91218f2)",
            "ProvenanceMark(a79faa3f)",
            "ProvenanceMark(71500811)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, hash: 8cd8e51f2885aeca2c644280b53ee75aa12b5a15f4d84068c8c918f8c0d85878, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 558dbfc6536b296875bb47d085cf746eca274110de5cbde40f34e1b651372ca2, hash: c5c043de88786aaed762e671a08f6805418fd9179179d325f7b2dc8ac115ca9a, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: abc6aa642861a61a42c751c2012df374e6528cad9d939b515e78dd288b3915f9, hash: 211f55707df73f0c8e7404a2b137d4417080a6bb523ba4e4baac409995be05ba, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc14a72ac53b5cd9b5445dbfc1264fd6de95b5ca8c060c24ba, hash: fb67f81adba64c5c0015b2608edc913a96fe94718f80fd721490cbafd55b3dcb, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: 1dadf8aa6a2b2fa657fc7a0225d1880e5946b5fd32e588c593923750478d74d4, hash: 33cf40295c4c06ac57eb89ef145779d6d65892741539441d93128f95ca194877, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 469cbdca128f2d85d803e81b3e0e3a7d64f15911e1854210ef5d1b22614a2006, hash: 96fe484af28c77c66b9d5d88dfc7e6b74950cbe9a01c959f2f1fa0e510a9b8c6, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 46b5294ba2787ed96dc10f79a3de28885d37a6dc0981dca240e7f1324e94a598, hash: 99356fddf4d51ce78887e24b59f86d3a150f0372e098dc8dc47cc57f09e90f7f, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 2e557fea3bc15ed4de848fc9929ab9b059fa7d30a1436b1fd9a6bc3dd4c08a06, hash: a91218f2e7addb84d58d6c20d869e4cd684b6e7809d2dc7a49b3b1f3c7c3c9a1, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: 53a5f76321139ef9f174b27b088a66c4803128e09eb4c3d97ca51f0c369dca63, hash: a79faa3fca4d8d01a0206aac4c706d21d74e373b277e75a2eafa83802047a1f0, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 3e095176523550db5ea446af664feab86dba35dbfd168b78e589999b09a702eb, hash: 7150081136c8ec9364c000661180ce566059bf7d2778ff6e6693aac43d800df7, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help frog huts purr gear knob news edge barn yurt frog gems hope wall high liar yank lava mild game peck ruin away holy kite open fizz dark data lava brew gyro curl glow eyes body ramp epic tiny high item join navy solo gala away view acid real ruin open keys body dice stub fair inch kick waxy waxy tent item code toil whiz wave kept good twin limp cyan lion easy chef kept axis roof work exit nail yank task very lazy gear oboe oboe junk obey hang bald menu draw curl noon jolt game legs void news echo inky surf",
            "gyro lung runs skew guru jade diet iris keep rock fuel taxi limp task jury jolt song deli flap blue urge high ruby vibe bias edge very ramp gray exam draw oboe huts free huts loud arch good saga news foxy whiz kiln jump foxy tiny belt guru vial zone wall gear lava puma liar veto luau puma pose holy oboe real part twin menu rich puff keep apex fuel toys flew tuna plus cola lazy idle tied help cash mild help acid numb real ramp noon pose ramp lava deli inky draw legs holy safe lava good kite task taxi meow hang next cook taco yoga gray help very",
            "play skew peck idle dice huts oval city flew slot gray saga acid drop wolf jury visa grim luck poem next menu need gray holy keys unit dice luau eyes buzz yurt runs liar news puma play yoga limp echo cusp fuel echo blue dark surf tuna glow jury epic zest easy ramp also half quiz play kiwi epic gyro vast fuel work mint away zoom pool chef knob dark eyes data love jolt webs back loud king wand race cash ramp cyan tent into miss calm sets next task puff acid very dull obey bias sets kick days quad puma waxy omit twin gems time aqua luck kite body",
            "lamb slot purr keno redo blue vibe zest bulb owls door silk fair high tuna race foxy hill runs safe days glow tomb urge mild race song luck atom barn dark road blue webs noon work flap keep holy days eyes exam axis cats part race iris sets nail quiz stub tied main back zest void inky drum race gray when roof taxi many redo scar numb code pool owls keno keep tent redo redo puma zero trip note flew huts iris loud into dice meow guru cook safe miss zaps jazz obey veto time yurt warm idea warm surf stub jazz quad kiwi help race inky acid whiz oboe",
            "cola poem yoga peck item down dull oval hang zest kiln also data tent logo beta hawk frog race zinc easy view logo silk menu memo exam good fuel lung jury tiny zaps gyro yawn game when foxy hang luck skew omit crux data duty very taco dull pose zoom keys keys zero monk cook part knob ramp omit lazy game nail song part cyan gyro work tomb high menu veto echo meow horn visa silk door poem gyro nail swan yurt list iron obey days jump able idea bald zaps draw onyx claw hard zaps memo taco stub jury tied trip vibe when loud many race chef tiny warm",
            "frog news ruby song brag many drop limp trip apex vows claw film beta fact kiwi idle when hawk body very limp flew blue webs hill claw cusp huts game crux atom gear vast lava bald taxi glow kept flew frog girl webs lamb webs what pool road stub trip away dull math visa jump race zinc next bias junk dice lion sets cyan work good toil junk dark inch stub city bulb flew veto girl brag jazz onyx help monk apex purr keys heat rust iron wall skew grim loud owls beta gems yank taco fern huts wall door scar deli kiwi dark body wall kick toil flux hang",
            "frog race diet gear oboe keys knob tuna join safe bias kick omit urge dice logo hill exam oval undo axis lazy undo oboe fizz void when easy girl meow open monk drop vibe game swan taco gear user slot memo item arch brag each junk kiln monk rock good news zero open flux dice song vial kite paid flew chef dark tent gift judo tent yoga user open blue zoom keep noon fish veto iris tent quad purr urge jowl main cats urge join easy lava body girl jazz huts safe gush road wand cola claw guru drum help loud yank taxi many race gift lion flew what slot",
            "drum gyro lamb wand fair safe holy tiny urge liar many solo memo navy rich puff hawk zaps kiwi duty obey flux jade cost tuna oval roof figs tiny rust love atom nail edge bias cola zoom yurt menu iron door gyro judo next memo easy cost kiln data vows zoom belt what jazz into jury fund ramp tent foxy kiln cash purr obey paid luck memo crux noon good obey kiwi inky blue good ramp knob hang urge inch atom next bald vows skew hang flux kick slot play gear obey apex foxy brag down gyro taxi mild grim jugs main holy numb zest holy inch claw kick rich",
            "guru open yell idea curl brew noon yurt when jury purr king away love inky sets lava each dice vast noon quiz scar tuna kite open cost barn even next song idea view mint gush wall hard kiwi help hard navy aqua swan toil draw play song drop miss road rock gush high vows part toys surf eyes ramp exam surf jury many zone dice unit jowl view fact join gush body warm jury aunt also surf time hawk next next oval even purr cash inch guru what lazy wasp brag peck owls arch kept kept help safe loud zone obey webs idea fact waxy peck claw memo jowl high",
            "film axis gray keno grim epic good ugly holy onyx frog pose inky glow wand redo join road epic ugly zinc calm luau keys view loud nail need axis owls also warm gems belt claw lion apex need very acid puma kick eyes menu jolt silk owls able ruby lazy epic dark cook glow oboe judo limp buzz brew deli yell able hard city poem buzz join wand fuel part hill ugly keep toil safe leaf yawn sets note play jazz cost zinc fund frog silk puff drum redo hang atom tent vibe bald rust iris oboe tent drum wave claw jazz dark quad peck body blue solo twin tomb",
        ]
        let expectedBytewordsIdentifiers = [
            "LUCK TRIP VIEW COST",
            "SILK RUST FLUX URGE",
            "CURL COST GYRO JUDO",
            "ZERO INTO YOGA CITY",
            "ECHO TASK FIZZ DIET",
            "MINT ZONE FUND GAME",
            "NAIL EPIC JOWL UNIT",
            "PART BRAG CATS WHIZ",
            "OWLS NOTE PECK FISH",
            "JUGS GOOD AWAY BODY",
        ]
        let expectedBytemojiIdentifiers = [
            "🟩 🐱 🐸 🤯",
            "🔥 🏀 🍓 🐻",
            "👹 🤯 🥚 💨",
            "🐚 🌱 🪼 🥳",
            "👆 🧶 🍌 😽",
            "🚁 🐬 🥝 🥑",
            "🏰 👄 🌸 🦊",
            "🧮 😳 🤠 🐢",
            "📚 🔑 🔒 🍋",
            "🌊 🧄 😘 🥶",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdimasbdwzyarehpvehpfghsprgrkbnseebnytfggshewlhhlryklamdgepkrnayhykeonfzdkdalabwgoclgwesbyrpectyhhimjnnysogaayvwadrlrnonksbydesbfrihkkwywyttimcetlwzwektgdtnlpcnlneycfktasrfwketnlyktkvylygroeoejkoyhgbdmudwclnnjtgelsvdlgcxdlso",
            "ur:provenance/lfaxhdimgolgrsswgujedtiskprkfltilptkjyjtsgdifpbeuehhryvebseevyrpgyemdwoehsfehsldahgdsansfywzknjpfytybtguvlzewlgrlapalrvolupapehyoerlpttnmurhpfkpaxfltsfwtapscalyietdhpchmdhpadnbrlrpnnperpladiiydwlshyselagdketktimwhgntcktowlfwbgve",
            "ur:provenance/lfaxhdimpyswpkiedehsolcyfwstgysaaddpwfjyvagmlkpmntmundgyhyksutdeluesbzytrslrnspapyyalpeocpfleobedksftagwjyeczteyrpaohfqzpykiecgovtflwkmtayzmplcfkbdkesdalejtwsbkldkgwdrechrpcnttiomscmssnttkpfadvydloybssskkdsqdpawyottngstebzneecbb",
            "ur:provenance/lfaxhdimlbstprkorobeveztbbosdrskfrhhtarefyhlrssedsgwtbuemdresglkambndkrdbewsnnwkfpkphydsesemascsptreisssnlqzsbtdmnbkztvdiydmregywnrftimyrosrnbceploskokpttroropazotpnefwhsisldiodemwgucksemszsjzoyvoteytwmiawmsfsbjzqdkihprektbgrkos",
            "ur:provenance/lfaxhdimcapmyapkimdndlolhgztknaodattlobahkfgrezceyvwloskmumoemgdfllgjytyzsgoyngewnfyhglkswotcxdadyvytodlpezmkskszomkckptkbrpotlygenlsgptcngowktbhhmuvoeomwhnvaskdrpmgonlsnytltinoydsjpaeiabdzsdwoxcwhdzsmotosbjytdtpvewnldmyoxbkntwy",
            "ur:provenance/lfaxhdimfgnsrysgbgmydplptpaxvscwfmbaftkiiewnhkbyvylpfwbewshlcwcphsgecxamgrvtlabdtigwktfwfgglwslbwswtplrdsbtpaydlmhvajprezcntbsjkdelnsscnwkgdtljkdkihsbcybbfwvoglbgjzoxhpmkaxprkshtrtinwlswgmldosbagsyktofnhswldrsrdikidkbywlisswbkgm",
            "ur:provenance/lfaxhdimfgredtgroekskbtajnsebskkotuedelohlemoluoaslyuooefzvdwneyglmwonmkdpvegesntogrurstmoimahbgehjkknmkrkgdnszoonfxdesgvlkepdfwcfdkttgtjottyauronbezmkpnnfhvoisttqdpruejlmncsuejneylabygljzhsseghrdwdcacwgudmhpldyktimyregtmsgyrhsa",
            "ur:provenance/lfaxhdimdmgolbwdfrsehytyuelrmysomonyrhpfhkzskidyoyfxjecttaolrffstyrtleamnleebscazmytmuindrgojontmoeyctkndavszmbtwtjziojyfdrpttfyknchproypdlkmocxnngdoykiiybegdrpkbhgueihamntbdvsswhgfxkkstpygroyaxfybgdngotimdgmjsmnhynbzthyjyaydyrf",
            "ur:provenance/lfaxhdimguonyliaclbwnnytwnjyprkgayleiysslaehdevtnnqzsrtakeonctbnenntsgiavwmtghwlhdkihphdnyaasntldwpysgdpmsrdrkghhhvspttssfesrpemsfjymyzedeutjlvwftjnghbywmjyataosftehkntntolenprchihguwtlywpbgpkosahktkthpseldzeoywsiaftwypkbklydshk",
            "ur:provenance/lfaxhdimfmasgykogmecgduyhyoxfgpeiygwwdrojnrdecuyzccmluksvwldnlndasosaowmgsbtcwlnaxndvyadpakkesmujtskosaerylyecdkckgwoejolpbzbwdiylaehdcypmbzjnwdflpthluykptlselfynssnepyjzctzcfdfgskpfdmrohgamttvebdrtisoettdmwecwjzdkqdpkbyadtnmute",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimasbdwzyarehpvehpfghsprgrkbnseebnytfggshewlhhlryklamdgepkrnayhykeonfzdkdalabwgoclgwesbyrpectyhhimjnnysogaayvwadrlrnonksbydesbfrihkkwywyttimcetlwzwektgdtnlpcnlneycfktasrfwketnlyktkvylygroeoejkoyhgbdmudwclnnjtgelsvdmelblyht",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimgolgrsswgujedtiskprkfltilptkjyjtsgdifpbeuehhryvebseevyrpgyemdwoehsfehsldahgdsansfywzknjpfytybtguvlzewlgrlapalrvolupapehyoerlpttnmurhpfkpaxfltsfwtapscalyietdhpchmdhpadnbrlrpnnperpladiiydwlshyselagdketktimwhgntcktoykcarfkt",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimpyswpkiedehsolcyfwstgysaaddpwfjyvagmlkpmntmundgyhyksutdeluesbzytrslrnspapyyalpeocpfleobedksftagwjyeczteyrpaohfqzpykiecgovtflwkmtayzmplcfkbdkesdalejtwsbkldkgwdrechrpcnttiomscmssnttkpfadvydloybssskkdsqdpawyottngsteasrtndlt",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimlbstprkorobeveztbbosdrskfrhhtarefyhlrssedsgwtbuemdresglkambndkrdbewsnnwkfpkphydsesemascsptreisssnlqzsbtdmnbkztvdiydmregywnrftimyrosrnbceploskokpttroropazotpnefwhsisldiodemwgucksemszsjzoyvoteytwmiawmsfsbjzqdkihprejegtbzee",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimcapmyapkimdndlolhgztknaodattlobahkfgrezceyvwloskmumoemgdfllgjytyzsgoyngewnfyhglkswotcxdadyvytodlpezmkskszomkckptkbrpotlygenlsgptcngowktbhhmuvoeomwhnvaskdrpmgonlsnytltinoydsjpaeiabdzsdwoxcwhdzsmotosbjytdtpvewnldmyrogoeoki",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimfgnsrysgbgmydplptpaxvscwfmbaftkiiewnhkbyvylpfwbewshlcwcphsgecxamgrvtlabdtigwktfwfgglwslbwswtplrdsbtpaydlmhvajprezcntbsjkdelnsscnwkgdtljkdkihsbcybbfwvoglbgjzoxhpmkaxprkshtrtinwlswgmldosbagsyktofnhswldrsrdikidkbywljynloxse",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimfgredtgroekskbtajnsebskkotuedelohlemoluoaslyuooefzvdwneyglmwonmkdpvegesntogrurstmoimahbgehjkknmkrkgdnszoonfxdesgvlkepdfwcfdkttgtjottyauronbezmkpnnfhvoisttqdpruejlmncsuejneylabygljzhsseghrdwdcacwgudmhpldyktimyregtlubachgy",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimdmgolbwdfrsehytyuelrmysomonyrhpfhkzskidyoyfxjecttaolrffstyrtleamnleebscazmytmuindrgojontmoeyctkndavszmbtwtjziojyfdrpttfyknchproypdlkmocxnngdoykiiybegdrpkbhgueihamntbdvsswhgfxkkstpygroyaxfybgdngotimdgmjsmnhynbzthyishgnndl",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimguonyliaclbwnnytwnjyprkgayleiysslaehdevtnnqzsrtakeonctbnenntsgiavwmtghwlhdkihphdnyaasntldwpysgdpmsrdrkghhhvspttssfesrpemsfjymyzedeutjlvwftjnghbywmjyataosftehkntntolenprchihguwtlywpbgpkosahktkthpseldzeoywsiaftwypkcmuelosg",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimfmasgykogmecgduyhyoxfgpeiygwwdrojnrdecuyzccmluksvwldnlndasosaowmgsbtcwlnaxndvyadpakkesmujtskosaerylyecdkckgwoejolpbzbwdiylaehdcypmbzjnwdflpthluykptlselfynssnepyjzctzcfdfgskpfdmrohgamttvebdrtisoettdmwecwjzdkqdpkbycalpfsfz",
        ]
        try runTest(
            resolution: .high,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
    
    @Test func testHighWithInfo() throws {
        let expectedDescriptions = [
            "ProvenanceMark(0c6b0c1b)",
            "ProvenanceMark(f172222a)",
            "ProvenanceMark(6da569b9)",
            "ProvenanceMark(10e6c12f)",
            "ProvenanceMark(6e4641df)",
            "ProvenanceMark(d99c321d)",
            "ProvenanceMark(1af31098)",
            "ProvenanceMark(111904ac)",
            "ProvenanceMark(4cfc564c)",
            "ProvenanceMark(1e5bd360)",
        ]
        let expectedDebugDescriptions = [
            #"ProvenanceMark(key: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, hash: 0c6b0c1b5456dc960c9030f60474b317eade25621cd2fe5c6e70d5dd235c9480, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 0, date: 2023-06-20T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 558dbfc6536b296875bb47d085cf746eca274110de5cbde40f34e1b651372ca2, hash: f172222a21b23fb87eb3a6f50eda0b7e2c2e1a3d9f7ce9ad37d69049742f53bb, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 1, date: 2023-06-21T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: abc6aa642861a61a42c751c2012df374e6528cad9d939b515e78dd288b3915f9, hash: 6da569b9f34ab28134d1417c4167293ec75bd825e773940208be0e378ab3591a, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 2, date: 2023-06-22T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 7fc7b276b810e4fc14a72ac53b5cd9b5445dbfc1264fd6de95b5ca8c060c24ba, hash: 10e6c12f1d64129ad8decf1e568a4ee974a4e8182673253ca8f657b5619cddee, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 3, date: 2023-06-23T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 1dadf8aa6a2b2fa657fc7a0225d1880e5946b5fd32e588c593923750478d74d4, hash: 6e4641df3c26057c5edff653bdfca67bfdc9a9fe74e6e6a5746af48e4fd78ee2, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 4, date: 2023-06-24T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 469cbdca128f2d85d803e81b3e0e3a7d64f15911e1854210ef5d1b22614a2006, hash: d99c321d11167179a24d4a57351c032c134f03df761b83fc74662b9805450367, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 5, date: 2023-06-25T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 46b5294ba2787ed96dc10f79a3de28885d37a6dc0981dca240e7f1324e94a598, hash: 1af31098e6b27a35c492d5fc0b6106108183627a3d8a97d8eeb1271bbcadbfb4, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 6, date: 2023-06-26T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 2e557fea3bc15ed4de848fc9929ab9b059fa7d30a1436b1fd9a6bc3dd4c08a06, hash: 111904ac8f50db2bd1e482b415562aec37fd7f022618a73593973046ae5007b0, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 7, date: 2023-06-27T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 53a5f76321139ef9f174b27b088a66c4803128e09eb4c3d97ca51f0c369dca63, hash: 4cfc564c0d863a843ddb014681a813e98cc7126985f6958bdc14bf01acc38997, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 8, date: 2023-06-28T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
            #"ProvenanceMark(key: 3e095176523550db5ea446af664feab86dba35dbfd168b78e589999b09a702eb, hash: 1e5bd360d448c43b08941028e5154aae2c29d6d3c3bc08869f298465ba77d77a, chainID: 090bf2f8b55be45b4661b24b7e9c340cf9464c5fe95c84f580954aaabe085e7c, seq: 9, date: 2023-06-29T12:00:00Z, info: "Lorem ipsum sit dolor amet.")"#,
        ]
        let expectedBytewords = [
            "axis bald whiz yoga race help vibe help frog huts purr gear knob news edge barn yurt frog gems hope wall high liar yank lava mild game peck ruin away holy kite open fizz dark data lava brew gyro curl glow eyes body ramp epic tiny high item join navy solo gala away view acid real ruin open keys body dice stub fair inch yurt hill aunt toil calm task owls pool swan legs cusp plus edge iron tied lamb grim leaf keno stub code easy deli safe iron hard gems jolt flap days runs hawk hang bald menu draw curl noon jolt game legs void solo lazy zone unit judo limp yoga luck kick numb undo oboe code edge zone yank time note surf king blue waxy exit item gear holy zest good good pool wasp tomb huts",
            "gyro lung runs skew guru jade diet iris keep rock fuel taxi limp task jury jolt song deli flap blue urge high ruby vibe bias edge very ramp gray exam draw oboe huts free huts loud arch good saga news foxy whiz kiln jump foxy tiny belt guru vial zone wall gear lava puma liar veto luau puma pose holy oboe real part twin owls bald tent lazy peck lung leaf gush judo kiwi hill arch song list exit jazz yoga zaps saga love rich quad onyx deli keno vibe jade open nail rich slot vast lava good kite task taxi meow hang next cook taco guru user unit cook lava quiz mild keys sets high keys drum also item city duty zaps purr navy game poem quiz soap webs race hawk bias holy monk hard city logo ugly",
            "play skew peck idle dice huts oval city flew slot gray saga acid drop wolf jury visa grim luck poem next menu need gray holy keys unit dice luau eyes buzz yurt runs liar news puma play yoga limp echo cusp fuel echo blue dark surf tuna glow jury epic zest easy ramp also half quiz play kiwi epic gyro vast fuel work mint foxy free memo taxi what nail quiz paid duty stub peck tiny kick down cash song numb join hill glow tied user days cusp dull unit zone pose zone cusp zinc pose sets kick days quad puma waxy omit twin gems time need stub real join mild luau cola toil eyes down zone stub view slot oboe fizz acid kite into open lamb ruby hard wall toys obey loud drum main paid gush view next",
            "lamb slot purr keno redo blue vibe zest bulb owls door silk fair high tuna race foxy hill runs safe days glow tomb urge mild race song luck atom barn dark road blue webs noon work flap keep holy days eyes exam axis cats part race iris sets nail quiz stub tied main back zest void inky drum race gray when roof taxi many guru flew nail diet iris inch dice quad axis junk silk task cyan main fizz maze legs easy yank beta lazy into luau good kiwi when inky keno buzz data echo undo warm idea warm surf stub jazz quad kiwi help race chef yurt back item lava acid stub judo surf figs door navy lion gush race deli gems zest very main beta owls cola tent poem into real grim cats gala road fizz inky",
            "cola poem yoga peck item down dull oval hang zest kiln also data tent logo beta hawk frog race zinc easy view logo silk menu memo exam good fuel lung jury tiny zaps gyro yawn game when foxy hang luck skew omit crux data duty very taco dull pose zoom keys keys zero monk cook part knob ramp omit lazy game nail song part knob undo yank crux fern yurt very vial next gush nail kick legs atom love edge visa iris roof vial rust yurt taxi redo liar junk lazy exam curl toil noon jowl memo taco stub jury tied trip vibe when loud many holy puma join peck dull brew barn very dull list curl road deli film fair obey heat toil game fair safe ugly fund vial math aqua kick toil twin cola gear high work",
            "frog news ruby song brag many drop limp trip apex vows claw film beta fact kiwi idle when hawk body very limp flew blue webs hill claw cusp huts game crux atom gear vast lava bald taxi glow kept flew frog girl webs lamb webs what pool road stub trip away dull math visa jump race zinc next bias junk dice lion sets cyan rock easy pose dark slot zoom swan open unit memo yank maze yoga real flap rust saga code kiln girl luck slot lamb love next down also twin claw numb girl jowl fern huts wall door scar deli kiwi dark body wall zinc kiwi hill fact fair dice edge grim cola oboe taxi edge lion flew tuna knob days zoom claw knob flap solo down free when ramp road miss zaps memo jazz diet twin",
            "frog race diet gear oboe keys knob tuna join safe bias kick omit urge dice logo hill exam oval undo axis lazy undo oboe fizz void when easy girl meow open monk drop vibe game swan taco gear user slot memo item arch brag each junk kiln monk rock good news zero open flux dice song vial kite paid flew chef dark tent gift wolf cash list navy real kept nail owls tied door toil user legs door tuna work zero also kick tomb puff crux stub foxy idle obey legs open very zone heat tomb claw guru drum help loud yank taxi many race gift puff hang girl whiz lung skew flap huts fact vial main each city ramp poem fuel grim rock twin calm able cats easy keno sets open aqua peck cost belt cola quad jazz",
            "drum gyro lamb wand fair safe holy tiny urge liar many solo memo navy rich puff hawk zaps kiwi duty obey flux jade cost tuna oval roof figs tiny rust love atom nail edge bias cola zoom yurt menu iron door gyro judo next memo easy cost kiln data vows zoom belt what jazz into jury fund ramp tent foxy kiln cash purr obey blue list main knob yawn poem obey tied iced kick ruin cusp quad iris blue foxy hawk down city memo wall next exit even cola many song bulb item toys undo fact gyro taxi mild grim jugs main holy numb zest holy pool film keys arch inky play zero foxy cyan main lazy diet data good gems huts monk kept kiln void into void buzz rich tiny cola jade exam luck soap jowl cash iris",
            "guru open yell idea curl brew noon yurt when jury purr king away love inky sets lava each dice vast noon quiz scar tuna kite open cost barn even next song idea view mint gush wall hard kiwi help hard navy aqua swan toil draw play song drop miss road rock gush high vows part toys surf eyes ramp exam surf jury many zone scar ruin menu mint zinc oval vial meow keno many jazz vows acid bald deli gyro skew dull brew vast race wave quad tuna real also drum down down lazy hope blue help safe loud zone obey webs idea fact waxy peck fizz yank main legs atom kept data time vast pool fish lung silk jazz vows scar edge obey good math oboe code user draw gear tomb flux main next kick silk main yank",
            "film axis gray keno grim epic good ugly holy onyx frog pose inky glow wand redo join road epic ugly zinc calm luau keys view loud nail need axis owls also warm gems belt claw lion apex need very acid puma kick eyes menu jolt silk owls able ruby lazy epic dark cook glow oboe judo limp buzz brew deli yell able hard city saga cook ramp need open diet keep junk chef lazy tent surf also gray claw guru crux jowl meow visa oboe acid fuel skew flap wave dice judo idea zest city view oboe tent drum wave claw jazz dark quad peck body silk back puff jugs exit down wall user duty gems luck unit pose cost wasp dice swan epic lamb half miss idea chef luck ugly ramp unit soap tent rust taco iced maze",
        ]
        let expectedBytewordsIdentifiers = [
            "BARN JADE BARN CLAW",
            "WHEN JUMP CUSP DOOR",
            "JOIN OPEN IRON RICH",
            "BLUE VISA SAFE DULL",
            "JOLT FROG FLAP USER",
            "TUNA NEWS EASY COLA",
            "CITY WOLF BLUE MONK",
            "BODY CHEF AQUA PLUS",
            "GEMS ZEST HALF GEMS",
            "COOK HELP TIME HORN",
        ]
        let expectedBytemojiIdentifiers = [
            "🤩 🌹 🤩 🥺",
            "🐞 💧 👺 🙀",
            "🌼 📫 🍁 🫖",
            "🥵 🐵 🏈 🤝",
            "🌻 🍑 🍉 🐼",
            "🐶 🎠 👈 🤑",
            "🥳 🐺 🥵 🚦",
            "🥶 🤡 🙄 📷",
            "🍅 🦭 🍗 🍅",
            "🙃 🌮 👟 🍚",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdltasbdwzyarehpvehpfghsprgrkbnseebnytfggshewlhhlryklamdgepkrnayhykeonfzdkdalabwgoclgwesbyrpectyhhimjnnysogaayvwadrlrnonksbydesbfrihythlattlcmtkosplsnlscppseeintdlbgmlfkosbceeydiseinhdgsjtfpdsrshkhgbdmudwclnnjtgelsvdsolyzeutjolpyalkkknbuooeceeezeyktenesfkgbewyetimgrhyztgdgdmsemvdah",
            "ur:provenance/lfaxhdltgolgrsswgujedtiskprkfltilptkjyjtsgdifpbeuehhryvebseevyrpgyemdwoehsfehsldahgdsansfywzknjpfytybtguvlzewlgrlapalrvolupapehyoerlpttnosbdttlypklglfghjokihlahsgltetjzyazssalerhqdoxdikovejeonnlrhstvtlagdketktimwhgntcktoguurutcklaqzmdkssshhksdmaoimcydyzsprnygepmqzspwsrehkbshymkhsserhrs",
            "ur:provenance/lfaxhdltpyswpkiedehsolcyfwstgysaaddpwfjyvagmlkpmntmundgyhyksutdeluesbzytrslrnspapyyalpeocpfleobedksftagwjyeczteyrpaohfqzpykiecgovtflwkmtfyfemotiwtnlqzpddysbpktykkdnchsgnbjnhlgwtdurdscpdlutzepezecpzcpesskkdsqdpawyottngstendsbrljnmdlucatlesdnzesbvwstoefzadkeioonlbryhdwltsoylddmmnmemytyyt",
            "ur:provenance/lfaxhdltlbstprkorobeveztbbosdrskfrhhtarefyhlrssedsgwtbuemdresglkambndkrdbewsnnwkfpkphydsesemascsptreisssnlqzsbtdmnbkztvdiydmregywnrftimygufwnldtisihdeqdasjksktkcnmnfzmelseyykbalyiolugdkiwniykobzdaeouowmiawmsfsbjzqdkihprecfytbkimlaadsbjosffsdrnylnghredigsztvymnbaoscattpmiorlgmcsjohsjsao",
            "ur:provenance/lfaxhdltcapmyapkimdndlolhgztknaodattlobahkfgrezceyvwloskmumoemgdfllgjytyzsgoyngewnfyhglkswotcxdadyvytodlpezmkskszomkckptkbrpotlygenlsgptkbuoykcxfnytvyvlntghnlkklsamleeevaisrfvlrtyttirolrjklyemcltlnnjlmotosbjytdtpvewnldmyhypajnpkdlbwbnvydlltclrddifmfroyhttlgefrseuyfdvlmhaakktltndkmhjnmh",
            "ur:provenance/lfaxhdltfgnsrysgbgmydplptpaxvscwfmbaftkiiewnhkbyvylpfwbewshlcwcphsgecxamgrvtlabdtigwktfwfgglwslbwswtplrdsbtpaydlmhvajprezcntbsjkdelnsscnrkeypedkstzmsnonutmoykmeyarlfprtsacekngllkstlblentdnaotncwnbgljlfnhswldrsrdikidkbywlzckihlftfrdeeegmcaoetieelnfwtakbdszmcwkbfpsodnfewnrprdmszspyrlcsrn",
            "ur:provenance/lfaxhdltfgredtgroekskbtajnsebskkotuedelohlemoluoaslyuooefzvdwneyglmwonmkdpvegesntogrurstmoimahbgehjkknmkrkgdnszoonfxdesgvlkepdfwcfdkttgtwfchltnyrlktnlostddrtlurlsdrtawkzoaokktbpfcxsbfyieoylsonvyzehttbcwgudmhpldyktimyregtpfhgglwzlgswfphsftvlmnehcyrppmflgmrktncmaecseykossonaapkcteeswlfay",
            "ur:provenance/lfaxhdltdmgolbwdfrsehytyuelrmysomonyrhpfhkzskidyoyfxjecttaolrffstyrtleamnleebscazmytmuindrgojontmoeyctkndavszmbtwtjziojyfdrpttfyknchproybeltmnkbynpmoytdidkkrncpqdisbefyhkdncymowlntetencamysgbbimtsuoftgotimdgmjsmnhynbzthyplfmksahiypyzofycnmnlydtdagdgshsmkktknvdiovdbzrhtycajeemlkwnqzdsbn",
            "ur:provenance/lfaxhdltguonyliaclbwnnytwnjyprkgayleiysslaehdevtnnqzsrtakeonctbnenntsgiavwmtghwlhdkihphdnyaasntldwpysgdpmsrdrkghhhvspttssfesrpemsfjymyzesrrnmumtzcolvlmwkomyjzvsadbddigoswdlbwvtreweqdtarlaodmdndnlyhebehpseldzeoywsiaftwypkfzykmnlsamktdatevtplfhlgskjzvssreeoygdmhoeceurdwgrtbfxmnntfzckrsme",
            "ur:provenance/lfaxhdltfmasgykogmecgduyhyoxfgpeiygwwdrojnrdecuyzccmluksvwldnlndasosaowmgsbtcwlnaxndvyadpakkesmujtskosaerylyecdkckgwoejolpbzbwdiylaehdcysackrpndondtkpjkcflyttsfaogycwgucxjlmwvaoeadflswfpwedejoiaztcyvwoettdmwecwjzdkqdpkbyskbkpfjsetdnwlurdygslkutpectwpdesneclbhfmsiacflkuyrputspttytbzguyk",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltasbdwzyarehpvehpfghsprgrkbnseebnytfggshewlhhlryklamdgepkrnayhykeonfzdkdalabwgoclgwesbyrpectyhhimjnnysogaayvwadrlrnonksbydesbfrihythlattlcmtkosplsnlscppseeintdlbgmlfkosbceeydiseinhdgsjtfpdsrshkhgbdmudwclnnjtgelsvdsolyzeutjolpyalkkknbuooeceeezeyktenesfkgbewyetimgrhyztgdgdlrpdstbg",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltgolgrsswgujedtiskprkfltilptkjyjtsgdifpbeuehhryvebseevyrpgyemdwoehsfehsldahgdsansfywzknjpfytybtguvlzewlgrlapalrvolupapehyoerlpttnosbdttlypklglfghjokihlahsgltetjzyazssalerhqdoxdikovejeonnlrhstvtlagdketktimwhgntcktoguurutcklaqzmdkssshhksdmaoimcydyzsprnygepmqzspwsrehkbshymkjphynlpd",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltpyswpkiedehsolcyfwstgysaaddpwfjyvagmlkpmntmundgyhyksutdeluesbzytrslrnspapyyalpeocpfleobedksftagwjyeczteyrpaohfqzpykiecgovtflwkmtfyfemotiwtnlqzpddysbpktykkdnchsgnbjnhlgwtdurdscpdlutzepezecpzcpesskkdsqdpawyottngstendsbrljnmdlucatlesdnzesbvwstoefzadkeioonlbryhdwltsoylddmmnlfbewkwy",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltlbstprkorobeveztbbosdrskfrhhtarefyhlrssedsgwtbuemdresglkambndkrdbewsnnwkfpkphydsesemascsptreisssnlqzsbtdmnbkztvdiydmregywnrftimygufwnldtisihdeqdasjksktkcnmnfzmelseyykbalyiolugdkiwniykobzdaeouowmiawmsfsbjzqdkihprecfytbkimlaadsbjosffsdrnylnghredigsztvymnbaoscattpmiorlgmcsiazegybz",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltcapmyapkimdndlolhgztknaodattlobahkfgrezceyvwloskmumoemgdfllgjytyzsgoyngewnfyhglkswotcxdadyvytodlpezmkskszomkckptkbrpotlygenlsgptkbuoykcxfnytvyvlntghnlkklsamleeevaisrfvlrtyttirolrjklyemcltlnnjlmotosbjytdtpvewnldmyhypajnpkdlbwbnvydlltclrddifmfroyhttlgefrseuyfdvlmhaakktltnembsgtlt",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltfgnsrysgbgmydplptpaxvscwfmbaftkiiewnhkbyvylpfwbewshlcwcphsgecxamgrvtlabdtigwktfwfgglwslbwswtplrdsbtpaydlmhvajprezcntbsjkdelnsscnrkeypedkstzmsnonutmoykmeyarlfprtsacekngllkstlblentdnaotncwnbgljlfnhswldrsrdikidkbywlzckihlftfrdeeegmcaoetieelnfwtakbdszmcwkbfpsodnfewnrprdmszsrodeetpt",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltfgredtgroekskbtajnsebskkotuedelohlemoluoaslyuooefzvdwneyglmwonmkdpvegesntogrurstmoimahbgehjkknmkrkgdnszoonfxdesgvlkepdfwcfdkttgtwfchltnyrlktnlostddrtlurlsdrtawkzoaokktbpfcxsbfyieoylsonvyzehttbcwgudmhpldyktimyregtpfhgglwzlgswfphsftvlmnehcyrppmflgmrktncmaecseykossonaapkctdihkoect",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltdmgolbwdfrsehytyuelrmysomonyrhpfhkzskidyoyfxjecttaolrffstyrtleamnleebscazmytmuindrgojontmoeyctkndavszmbtwtjziojyfdrpttfyknchproybeltmnkbynpmoytdidkkrncpqdisbefyhkdncymowlntetencamysgbbimtsuoftgotimdgmjsmnhynbzthyplfmksahiypyzofycnmnlydtdagdgshsmkktknvdiovdbzrhtycajeemlkvodnamcw",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltguonyliaclbwnnytwnjyprkgayleiysslaehdevtnnqzsrtakeonctbnenntsgiavwmtghwlhdkihphdnyaasntldwpysgdpmsrdrkghhhvspttssfesrpemsfjymyzesrrnmumtzcolvlmwkomyjzvsadbddigoswdlbwvtreweqdtarlaodmdndnlyhebehpseldzeoywsiaftwypkfzykmnlsamktdatevtplfhlgskjzvssreeoygdmhoeceurdwgrtbfxmnntgulyneln",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltfmasgykogmecgduyhyoxfgpeiygwwdrojnrdecuyzccmluksvwldnlndasosaowmgsbtcwlnaxndvyadpakkesmujtskosaerylyecdkckgwoejolpbzbwdiylaehdcysackrpndondtkpjkcflyttsfaogycwgucxjlmwvaoeadflswfpwedejoiaztcyvwoettdmwecwjzdkqdpkbyskbkpfjsetdnwlurdygslkutpectwpdesneclbhfmsiacflkuyrputspttwdlejkvo",
        ]
        try runTest(
            resolution: .high,
            includeInfo: true,
            expectedDescriptions: expectedDescriptions,
            expectedDebugDescriptions: expectedDebugDescriptions,
            expectedBytewords: expectedBytewords,
            expectedBytewordsIdentifiers: expectedBytewordsIdentifiers,
            expectedBytemojiIdentifiers: expectedBytemojiIdentifiers,
            expectedURs: expectedURs,
            expectedURLs: expectedURLs
        )
    }
}
