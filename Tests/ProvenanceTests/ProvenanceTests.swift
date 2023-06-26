import XCTest
@testable import Provenance
import BCCrypto
import WolfBase
import WolfLorem

final class ProvenanceTests: XCTestCase {
    func test2ByteDates() {
        let baseDate = try! Date(iso8601: "2023-06-20T00:00:00Z")
        let baseDateSerialized = baseDate.serialize2Bytes()!
        XCTAssertEqual(baseDateSerialized.hex, "00d4")
        let baseDate2 = Date.deserialize2Bytes(‡"00d4")!
        XCTAssertEqual(baseDate, baseDate2)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 00000000 00100001 == 0x0021
        let minDate = try! Date(iso8601: "2023-01-01T00:00:00Z")
        XCTAssertEqual(Date.deserialize2Bytes(‡"0021")!, minDate)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 11111111 10011111 == 0xff9f
        let maxDate = try! Date(iso8601: "2150-12-31T00:00:00Z")
        XCTAssertEqual(Date.deserialize2Bytes(‡"ff9f")!, maxDate)

        // fedcba98 76543210
        // yyyyyyym mmmddddd
        // 00000000 01011110 == 0x005e == 2023-02-30 (invalid)
        XCTAssertNil(Date.deserialize2Bytes(‡"005e"))
    }

    func test4ByteDates() {
        let baseDate = try! Date(iso8601: "2023-06-20T12:34:56Z")
        let baseDateSerialized = baseDate.serialize4Bytes()!
        XCTAssertEqual(baseDateSerialized.hex, "2a41d470")
        let baseDate2 = Date.deserialize4Bytes(‡"2a41d470")!
        XCTAssertEqual(baseDate, baseDate2)
        
        let minDate = Date.deserialize4Bytes(‡"00000000")!
        XCTAssertEqual(minDate, try! Date(iso8601: "2001-01-01T00:00:00Z"))
        //print(minDate.ISO8601Format())
        let maxDate = Date.deserialize4Bytes(‡"ffffffff")!
        XCTAssertEqual(maxDate, try! Date(iso8601: "2137-02-07T06:28:15Z"))
        //print(maxDate.ISO8601Format())
    }

    func test8ByteDates() {
        let format = Date
            .ISO8601FormatStyle()
            .year()
            .month()
            .day()
            .dateSeparator(.dash)
            .timeSeparator(.colon)
            .timeZone(separator: .omitted)
            .time(includingFractionalSeconds: true)
        let baseDate = try! format.parse("2023-06-20T12:34:56.789Z")
        let baseDateSerialized = baseDate.serialize6Bytes()!
        XCTAssertEqual(baseDateSerialized.hex, "00a51125d895")
        let baseDate2 = Date.deserialize6Bytes(‡"00a51125d895")!
        XCTAssertEqual(baseDate, baseDate2)
        
        let minDate = Date.deserialize6Bytes(‡"000000000000")!
        //print(minDate.formatted(format))
        XCTAssertEqual(minDate, try! format.parse("2001-01-01T00:00:00.000Z"))
        
        let maxDate = try! format.parse("9999-12-31T23:59:59.999Z")
        XCTAssertEqual(maxDate.serialize6Bytes()!, ‡"e5940a78a7ff")

        // Outside allowed range <-- Y10K bug right here!
        XCTAssertNil(Date.deserialize6Bytes(‡"e5940a78a800"))
    }

    func runTest(resolution: ProvenanceMarkResolution, includeInfo: Bool = false, expectedDescriptions: [String] = [], expectedBytewords: [String] = [], expectedURs: [String] = [], expectedURLs: [String] = [], onlyPrint: Bool = false) {
        var rng: RandomNumberGenerator = makeFakeRandomNumberGenerator()
        let provenanceGen = ProvenanceMarkGenerator(resolution: resolution, passphrase: "Wolf", using: &rng)
        let count = 10
        let baseDate = try! Date(iso8601: "2023-06-20T12:00:00Z")
        var calendar = Calendar.init(identifier: .gregorian)
        calendar.timeZone = .gmt
        let dates = (0..<count).map {
            calendar.date(byAdding: .day, value: $0, to: baseDate)!
        }
        let marks = dates.map {
            let title: String?
            if includeInfo {
                title = Lorem.title(using: &rng)
            } else {
                title = nil
            }
            return provenanceGen.next(date: $0, info: title)
        }
        
        XCTAssert(ProvenanceMark.isSequenceValid(marks: marks))

        XCTAssert(!marks[1].precedes(next: marks[0]))

        //marks.forEach { print($0.cborData.hex) }
        
        if onlyPrint {
            marks.forEach { print($0) }
        } else if !expectedDescriptions.isEmpty {
            XCTAssertEqual(marks.map { $0.description }, expectedDescriptions)
        }

        let bytewords = marks.map { $0.bytewords(style: .standard) }
        if onlyPrint {
            bytewords.forEach { print($0) }
        } else if !expectedBytewords.isEmpty {
            XCTAssert(zip(bytewords, expectedBytewords).allSatisfy { $0.0 == $0.1 })
        }
        let bytewordsMarks = bytewords.map {
            ProvenanceMark(resolution: resolution, bytewords: $0)!
        }
        XCTAssertEqual(marks, bytewordsMarks)

        let urs = marks.map { $0.urString }
        if onlyPrint {
            urs.forEach { print($0) }
        } else if !expectedURs.isEmpty {
            XCTAssert(zip(urs, expectedURs).allSatisfy { $0.0 == $0.1 })
        }
        let urMarks = urs.map {
            try! ProvenanceMark(urString: $0)
        }
        XCTAssertEqual(marks, urMarks)

        let baseURL = URL(string: "https://example.com/validate")!
        let urls = marks.map { $0.url(base: baseURL) }
        if onlyPrint {
            urls.forEach { print($0) }
        } else if !expectedURLs.isEmpty {
            XCTAssert(zip(urls, expectedURLs).allSatisfy { $0.0.description == $0.1 })
        }
        let urlMarks = urls.map {
            ProvenanceMark(url: $0)!
        }
        XCTAssertEqual(marks, urlMarks)
    }
    
    func testLow() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bb, hash: 742d2d21, id: 7eb559bb, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa1, hash: bcf27d5d, id: 7eb559bb, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: 38cfe538, hash: 2436be12, id: 7eb559bb, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: bedba2c8, hash: fe3fa4e2, id: 7eb559bb, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: a96ec2da, hash: 73eefdda, id: 7eb559bb, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: d0703671, hash: c881a6b1, id: 7eb559bb, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 19cd0a02, hash: fdb3ec47, id: 7eb559bb, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 55864d59, hash: 35b305bc, id: 7eb559bb, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: c695d857, hash: 7970c2da, id: 7eb559bb, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7df, hash: 58c4dff1, id: 7eb559bb, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock taxi iris frog taxi tomb veto skew paid foxy limp gush vows back grim time glow",
            "iron hill pose obey lung yank holy love even iced keys fund maze tomb hang cost twin film safe onyx",
            "exit task view exit kept rock work hang frog purr mint fizz code door task code yell kiwi zest lung",
            "ruin ugly oboe soap junk jazz fund limp kept jowl zinc grim pool love apex free idea deli veto cusp",
            "part jolt saga twin aqua figs news menu draw iris main solo mint bald road twin miss girl play item",
            "taxi judo even jugs pose math work note bald road cyan next very cola fish memo trip vows echo what",
            "chef swan back also half math visa holy math slot foxy solo heat bulb quiz holy jump taxi crux idle",
            "gyro lion gift hawk zinc judo exit pose grim keep deli huts body math zinc luck iron obey game blue",
            "skew mild trip hang puff solo redo guru toil bias cost veto wolf beta onyx king vibe exam kept race",
            "time gray yell user need wasp jade heat flap keno heat silk huts keep runs love flux brag knob away",
        ]
        let expectedURs = [
            "ur:provenance/lfaegdkbrehkrktiisfgtitbvoswpdfylpghvsmkgujkhl",
            "ur:provenance/lfaegdinhlpeoylgykhyleenidksfdmetbhgctfdfhhsrp",
            "ur:provenance/lfaegdettkvwetktrkwkhgfgprmtfzcedrtkceihkehhne",
            "ur:provenance/lfaegdrnuyoespjkjzfdlpktjlzcgmplleaxfewndsfwdy",
            "ur:provenance/lfaegdptjtsatnaafsnsmudwismnsomtbdrdtnahgwbdks",
            "ur:provenance/lfaegdtijoenjspemhwknebdrdcnntvycafhmogewlmuvo",
            "ur:provenance/lfaegdcfsnbkaohfmhvahymhstfysohtbbqzhyvtttlako",
            "ur:provenance/lfaegdgolngthkzcjoetpegmkpdihsbymhzclkzonbwdao",
            "ur:provenance/lfaegdswmdtphgpfsorogutlbsctvowfbaoxkgkoentsos",
            "ur:provenance/lfaegdtegyylurndwpjehtfpkohtskhskprslettbwuecy",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaegdkbrehkrktiisfgtitbvoswpdfylpghvshycyndao",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdinhlpeoylgykhyleenidksfdmetbhgctmnkoldwl",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdettkvwetktrkwkhgfgprmtfzcedrtkceotecqzrt",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdrnuyoespjkjzfdlpktjlzcgmplleaxfeemjlpkjl",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdptjtsatnaafsnsmudwismnsomtbdrdtnsramvldi",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdtijoenjspemhwknebdrdcnntvycafhmolknbkgry",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdcfsnbkaohfmhvahymhstfysohtbbqzhydsmkisdt",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdgolngthkzcjoetpegmkpdihsbymhzclkfswlaohl",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdswmdtphgpfsorogutlbsctvowfbaoxkgpflbfhya",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdtegyylurndwpjehtfpkohtskhskprslechhtenfe",
        ]
        runTest(resolution: .low, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testLowWithInfo() throws {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bb, hash: a267146d, id: 7eb559bb, seq: 0, date: 2023-06-20T12:00:00Z, info: "Consectetur Molestiae")"#,
            #"ProvenanceMark(key: 695dafa1, hash: 1c7e01be, id: 7eb559bb, seq: 1, date: 2023-06-21T12:00:00Z, info: "Earum Provident Debitis Dicta Numquam Quis Nisi")"#,
            #"ProvenanceMark(key: 38cfe538, hash: a532731b, id: 7eb559bb, seq: 2, date: 2023-06-22T12:00:00Z, info: "Et Modi Corporis Molestias Consequuntur Esse")"#,
            #"ProvenanceMark(key: bedba2c8, hash: 50bf2f7f, id: 7eb559bb, seq: 3, date: 2023-06-23T12:00:00Z, info: "Voluptatum Ut Est Quos")"#,
            #"ProvenanceMark(key: a96ec2da, hash: e72b361c, id: 7eb559bb, seq: 4, date: 2023-06-24T12:00:00Z, info: "Enim Repellendus Dolor Et Et")"#,
            #"ProvenanceMark(key: d0703671, hash: 8a3ee1f0, id: 7eb559bb, seq: 5, date: 2023-06-25T12:00:00Z, info: "Dignissimos Quia Reiciendis Delectus")"#,
            #"ProvenanceMark(key: 19cd0a02, hash: 4cbc6fb3, id: 7eb559bb, seq: 6, date: 2023-06-26T12:00:00Z, info: "Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: 55864d59, hash: 9c59d58f, id: 7eb559bb, seq: 7, date: 2023-06-27T12:00:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: c695d857, hash: e671a5a0, id: 7eb559bb, seq: 8, date: 2023-06-28T12:00:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: d351f7df, hash: 5b64c547, id: 7eb559bb, seq: 9, date: 2023-06-29T12:00:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock taxi iris frog taxi able paid zoom vibe foxy limp gush vows gems obey aqua user lung race list cats silk purr whiz away gear down what fuel buzz loud exit wave puma slot blue legs zero ramp",
            "iron hill pose obey lung yank holy love mint waxy aqua play maze tomb hang cost item nail tomb holy yell hill high list crux silk zinc solo runs exam owls toys curl flap ramp quad skew warm brag puma diet saga plus vial webs away drop keno gyro hope barn glow hill race gift miss yoga very judo open webs oboe epic monk yell redo taco news into",
            "exit task view exit kept rock work hang slot ramp help gala code door task code holy very arch flew puff undo high gems onyx brag cats whiz what fact vial warm wave cyan roof ramp code work task beta yurt taxi figs item obey loud main yawn join half jump memo taxi luau yoga vial cost horn jazz vibe kick able zero rust keno oboe",
            "ruin ugly oboe soap junk jazz fund limp tuna webs keno task pool love apex free zinc mild into item zoom king part wand acid quiz jolt fair gift wolf race cyan part oboe horn taco edge atom trip tied gear able film",
            "part jolt saga twin aqua figs news menu redo poem free bias mint bald road twin barn chef acid help hard holy brag peck tomb note leaf song next user what nail data legs zoom zoom cash foxy wave oval zaps idle redo mint mint visa flap legs calm lion",
            "taxi judo even jugs pose math work note gala arch idle undo very cola fish memo wasp hope horn many axis roof horn brag ruin soap dull iron luck curl void undo oboe taco belt fair flew wand barn even time epic work gush tent wand wall free lazy tent blue cook guru rock aqua cola aqua idea",
            "chef swan back also half math visa holy curl soap slot figs heat bulb quiz holy tent yell toil tiny rust gems film road axis jump luck inch cats maze yawn knob epic hope need slot inky swan paid body redo luck what",
            "gyro lion gift hawk zinc judo exit pose zero note yell grim body math zinc luck whiz zero fair main hard waxy yawn cusp tiny edge kick roof safe item arch task fizz guru wolf owls game part part lazy monk luck whiz back user when gush epic zone main duty high figs stub cats holy help jugs king song tuna draw rock",
            "skew mild trip hang puff solo redo guru game beta keys monk wolf beta onyx king need meow chef away cats duty city dice mild idea days down edge yawn oboe good real fund brew urge stub also heat view what jugs draw tuna inch stub very tiny figs pool acid peck bias axis jump note grim legs",
            "time gray yell user need wasp jade heat flew tomb fizz junk huts keep runs love cusp whiz purr half rock navy sets swan liar taxi vast fish paid very vibe stub lamb dark also quad ruby vows hang keys warm gems note puma safe jade silk buzz swan fund skew frog plus poem loud next work blue kept",
        ]
        let expectedURs = [
            "ur:provenance/lfaehddskbrehkrktiisfgtiaepdzmvefylpghvsgsoyaaurlgreltcsskprwzaygrdnwtflbzldetwepastnsiewpwf",
            "ur:provenance/lfaehdfpinhlpeoylgykhylemtwyaapymetbhgctimnltbhyylhlhhltcxskzcsorsemostsclfprpqdswwmbgpadtsapsvlwsaydpkogohebngwhlregtmsyavyjoonwsoeecmkylnlwpwzwk",
            "ur:provenance/lfaehdfmettkvwetktrkwkhgstrphpgacedrtkcehyvyahfwpfuohhgsoxbgcswzwtftvlwmwecnrfrpcewktkbayttifsimoyldmnynjnhfjpmotiluyavlcthnjzvekkaesfrttlgs",
            "ur:provenance/lfaehddirnuyoespjkjzfdlptawskotkplleaxfezcmdioimzmkgptwdadqzjtfrgtwfrecnptoehntoeeamtpkgecrtjs",
            "ur:provenance/lfaehddmptjtsatnaafsnsmuropmfebsmtbdrdtnbncfadhphdhybgpktbnelfsgnturwtnldalszmzmchfyweolzsieromtmtvaaezshkgs",
            "ur:provenance/lfaehdentijoenjspemhwknegaahieuovycafhmowphehnmyasrfhnbgrnspdlinlkclvduooetobtfrfwwdbnenteecwkghttwdwlfelyttbeckgurkmofwtdze",
            "ur:provenance/lfaehddicfsnbkaohfmhvahyclspstfshtbbqzhyttyltltyrtgsfmrdasjplkihcsmeynkbechendstiysnpdroswgsrs",
            "ur:provenance/lfaehdfrgolngthkzcjoetpezoneylgmbymhzclkwzzofrmnhdwyyncptyeekkrfseimahtkfzguwfosgeptptlymklkwzbkurwngheczemndyhhfssbcshyhpjskgchutrnfw",
            "ur:provenance/lfaehdenswmdtphgpfsorogugebaksmkwfbaoxkgndmwcfaycsdycydemdiadsdneeynoegdrlfdbwuesbaohtvwwtjsdwtaihsbvytyfspladpkbsasvertlrck",
            "ur:provenance/lfaehdemtegyylurndwpjehtfwtbfzjkhskprslecpwzprhfrknysssnlrtivtfhpdvyvesblbdkaoqdryvshgkswmgsnepasejeskbzsnfdswfgpspmldbagaqdmy",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaehddskbrehkrktiisfgtiaepdzmvefylpghvsgsoyaaurlgreltcsskprwzaygrdnwtflbzldetwepasttofzssft",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfpinhlpeoylgykhylemtwyaapymetbhgctimnltbhyylhlhhltcxskzcsorsemostsclfprpqdswwmbgpadtsapsvlwsaydpkogohebngwhlregtmsyavyjoonwsoeecmkylcsmwbbwp",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfmettkvwetktrkwkhgstrphpgacedrtkcehyvyahfwpfuohhgsoxbgcswzwtftvlwmwecnrfrpcewktkbayttifsimoyldmnynjnhfjpmotiluyavlcthnjzvekkaekkdmmuch",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddirnuyoespjkjzfdlptawskotkplleaxfezcmdioimzmkgptwdadqzjtfrgtwfrecnptoehntoeeamtpnlurnngt",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddmptjtsatnaafsnsmuropmfebsmtbdrdtnbncfadhphdhybgpktbnelfsgnturwtnldalszmzmchfyweolzsieromtmtvaflpeptcx",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdentijoenjspemhwknegaahieuovycafhmowphehnmyasrfhnbgrnspdlinlkclvduooetobtfrfwwdbnenteecwkghttwdwlfelyttbeckgurkstvsfzto",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddicfsnbkaohfmhvahyclspstfshtbbqzhyttyltltyrtgsfmrdasjplkihcsmeynkbechendstiysnpdhtdwbgls",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfrgolngthkzcjoetpezoneylgmbymhzclkwzzofrmnhdwyyncptyeekkrfseimahtkfzguwfosgeptptlymklkwzbkurwngheczemndyhhfssbcshyhpjskgprmthygs",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdenswmdtphgpfsorogugebaksmkwfbaoxkgndmwcfaycsdycydemdiadsdneeynoegdrlfdbwuesbaohtvwwtjsdwtaihsbvytyfspladpkbsaspaimcmdm",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdemtegyylurndwpjehtfwtbfzjkhskprslecpwzprhfrknysssnlrtivtfhpdvyvesblbdkaoqdryvshgkswmgsnepasejeskbzsnfdswfgpspmlddeskdtpa",
        ]
        runTest(resolution: .low, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testMedium() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce26, hash: f8ad58b45e1e452b, id: 7eb559bbbf6cce26, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa138cfe538, hash: 6e7eae04b288a329, id: 7eb559bbbf6cce26, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: bedba2c8a96ec2da, hash: 764a09e9bd6e04f5, id: 7eb559bbbf6cce26, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: d070367119cd0a02, hash: 924669fdee920eec, id: 7eb559bbbf6cce26, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: 55864d59c695d857, hash: 9fc0ed6d11997f97, id: 7eb559bbbf6cce26, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7dff419008f, hash: 99e26347f8a3d05b, id: 7eb559bbbf6cce26, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 691d0bebe4e71f69, hash: a0561f7ea037a4d8, id: 7eb559bbbf6cce26, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4df, hash: bdd8c207193d3e2e, id: 7eb559bbbf6cce26, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: f86f78ab260ce12c, hash: 82bd6e3321e8e754, id: 7eb559bbbf6cce26, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 650a700450011d2f, hash: b42bd8fd1bc54ecd, id: 7eb559bbbf6cce26, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days keep data axis jury mint hard wolf body zero yell cost door epic aunt jolt hang ruin memo easy pool pose fund wave menu lazy holy slot iced",
            "iron hill pose obey exit task view exit paid tuna flew code waxy chef brew wave horn wand edge yell echo yawn ruby zinc draw next song math kite unit solo gear need veto play time",
            "ruin ugly oboe soap part jolt saga twin brag fizz fish draw zoom owls girl able idea hard trip dull diet fund kiwi math what zaps twin apex acid miss days tiny flap draw part rust",
            "taxi judo even jugs chef swan back also yoga mild draw dull echo dull draw slot dice luau paid lung high roof zero owls calm race monk gala gift days gray taxi solo wand mild ruin",
            "gyro lion gift hawk skew mild trip hang easy aunt ramp gear zaps brew miss yell deli mint flew swan gush work gift open safe kiwi news taxi news able hill yank jump cash rock ruby",
            "time gray yell user work chef able many puma news girl webs ramp exit barn puma aunt huts gush zero liar drop hope quad deli huts task bulb lazy maze fund epic aqua plus days waxy",
            "iron cola bald warm vibe void cost iron back help vast menu cost meow ruby exam very brag zero brag king wall glow yoga list puff view oval solo zaps body wand very vibe guru knob",
            "runs tied maze zinc knob jolt quiz user wand keep junk monk task tied hawk keys taco iced monk loud fern monk luau duty waxy oboe unit soap curl atom wasp waxy zaps cyan tomb noon",
            "yoga jowl keys play days barn very draw inky keep math epic when fair menu keep love kick city visa huts bulb able heat next curl need jade love knob junk scar swan rich onyx junk",
            "inch back judo aqua good acid cola dull bald meow tiny yurt into diet love menu owls king vast able gush edge stub legs edge film flux race frog jade holy warm inky puff ramp ramp",
        ]
        let expectedURs = [
            "ur:provenance/lfadhdcxkbrehkrkrsjztodskpdaasjymthdwfbyzoylctdrecatjthgrnmoeyplpefdwemumysoidol",
            "ur:provenance/lfadhdcxinhlpeoyettkvwetpdtafwcewycfbwwehnwdeeyleoynryzcdwntsgmhkeutsogrmdkpbach",
            "ur:provenance/lfadhdcxrnuyoespptjtsatnbgfzfhdwzmosglaeiahdtpdldtfdkimhwtzstnaxadmsdstygwrkbnaa",
            "ur:provenance/lfadhdcxtijoenjscfsnbkaoyamddwdleodldwstdelupdlghhrfzooscmremkgagtdsgytistkidykn",
            "ur:provenance/lfadhdcxgolngthkswmdtphgeyatrpgrzsbwmsyldimtfwsnghwkgtonsekinstinsaehlykkelackkk",
            "ur:provenance/lfadhdcxtegyylurwkcfaemypansglwsrpetbnpaathsghzolrdpheqddihstkbblymefdecbkfrlsdr",
            "ur:provenance/lfadhdcxincabdwmvevdctinbkhpvtmuctmwryemvybgzobgkgwlgwyaltpfvwolsozsbywdwsjkynrd",
            "ur:provenance/lfadhdcxrstdmezckbjtqzurwdkpjkmktktdhkkstoidmkldfnmkludywyoeutspclamwpwywkqzjkht",
            "ur:provenance/lfadhdcxyajlkspydsbnvydwiykpmhecwnfrmukplekkcyvahsbbaehtntclndjelekbjksrsrdmadrl",
            "ur:provenance/lfadhdcxihbkjoaagdadcadlbdmwtyytiodtlemuoskgvtaegheesblseefmfxrefgjehywmisdibwjp",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxkbrehkrkrsjztodskpdaasjymthdwfbyzoylctdrecatjthgrnmoeyplpefdwemumujpjnjs",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxinhlpeoyettkvwetpdtafwcewycfbwwehnwdeeyleoynryzcdwntsgmhkeutsogrldtoadrt",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxrnuyoespptjtsatnbgfzfhdwzmosglaeiahdtpdldtfdkimhwtzstnaxadmsdstyguaeaxte",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxtijoenjscfsnbkaoyamddwdleodldwstdelupdlghhrfzooscmremkgagtdsgytiuyswfhpm",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxgolngthkswmdtphgeyatrpgrzsbwmsyldimtfwsnghwkgtonsekinstinsaehlykhnfrbypl",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxtegyylurwkcfaemypansglwsrpetbnpaathsghzolrdpheqddihstkbblymefdeccmlalkzc",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxincabdwmvevdctinbkhpvtmuctmwryemvybgzobgkgwlgwyaltpfvwolsozsbywdwfspytjn",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxrstdmezckbjtqzurwdkpjkmktktdhkkstoidmkldfnmkludywyoeutspclamwpwyvsbskelg",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxyajlkspydsbnvydwiykpmhecwnfrmukplekkcyvahsbbaehtntclndjelekbjksrurmdbahn",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdcxihbkjoaagdadcadlbdmwtyytiodtlemuoskgvtaegheesblseefmfxrefgjehywmjynsceon",
        ]
        runTest(resolution: .medium, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testMediumWithInfo() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce26, hash: 1ab92fae335319df, id: 7eb559bbbf6cce26, seq: 0, date: 2023-06-20T12:00:00Z, info: "Enim Aperiam Odio Eaque")"#,
            #"ProvenanceMark(key: 695dafa138cfe538, hash: 10d09d5ffd240e25, id: 7eb559bbbf6cce26, seq: 1, date: 2023-06-21T12:00:00Z, info: "Numquam Quis")"#,
            #"ProvenanceMark(key: bedba2c8a96ec2da, hash: 3d06cc13043b6ab4, id: 7eb559bbbf6cce26, seq: 2, date: 2023-06-22T12:00:00Z, info: "Cum Et Modi Corporis Molestias")"#,
            #"ProvenanceMark(key: d070367119cd0a02, hash: 8dc939bdd28fd1d6, id: 7eb559bbbf6cce26, seq: 3, date: 2023-06-23T12:00:00Z, info: "Nobis Blanditiis Voluptatum Ut Est Quos Explicabo")"#,
            #"ProvenanceMark(key: 55864d59c695d857, hash: 9fac98819984613f, id: 7eb559bbbf6cce26, seq: 4, date: 2023-06-24T12:00:00Z, info: "Repellendus Dolor Et")"#,
            #"ProvenanceMark(key: d351f7dff419008f, hash: 3679f69780dba9a3, id: 7eb559bbbf6cce26, seq: 5, date: 2023-06-25T12:00:00Z, info: "Consequatur Dignissimos")"#,
            #"ProvenanceMark(key: 691d0bebe4e71f69, hash: a8c1b7744c6ec86c, id: 7eb559bbbf6cce26, seq: 6, date: 2023-06-26T12:00:00Z, info: "Quia Ut Praesentium Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4df, hash: 2846048866853d50, id: 7eb559bbbf6cce26, seq: 7, date: 2023-06-27T12:00:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: f86f78ab260ce12c, hash: 26f1c3c5a9f4037b, id: 7eb559bbbf6cce26, seq: 8, date: 2023-06-28T12:00:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: 650a700450011d2f, hash: 606d8d7fd60eba36, id: 7eb559bbbf6cce26, seq: 9, date: 2023-06-29T12:00:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days keep data axis jury mint hard wolf body chef vial iris duty hard game easy omit ruin memo easy pool pose fund wave menu back undo brag open numb oboe barn jade echo aunt logo chef plus vibe mint owls claw stub free limp bulb redo rock edge bias door dark navy",
            "iron hill pose obey exit task view exit paid tuna flew code waxy chef brew wave cook foxy aunt plus kite heat blue when draw next song math kite unit solo gear apex gyro main flew drum wave drum door axis lazy memo curl toil atom jade play also",
            "ruin ugly oboe soap part jolt saga twin brag fizz fish draw zoom owls girl able dice bulb cola toil math cola brew tent what zaps twin apex acid miss days tiny luau jowl jowl fizz flew city logo yoga task calm miss nail gala solo lamb menu gyro need luck logo redo dull epic claw ruin lazy peck road deli onyx calm tuna diet bulb liar tied",
            "taxi judo even jugs chef swan back also yoga mild draw dull echo dull draw slot exam aqua yoga swan horn obey dark next calm race monk gala gift days gray taxi jury toys gear gift hawk dice cook bias ugly apex next dull ruin cats ugly lava pose cost jowl trip help good brag free purr ramp menu redo wasp gyro eyes swan cash purr foxy purr purr ruin flew veto able kept cusp veto zero judo yell keno math loud yawn zone vial wall ruin",
            "gyro lion gift hawk skew mild trip hang easy aunt ramp gear zaps brew miss yell deli zaps exam curl undo wall guru belt safe kiwi news taxi news able hill yank atom kiwi what gyro visa free road paid maze luck join brag road curl whiz back jowl play also yell horn urge task redo deli",
            "time gray yell user work chef able many puma news girl webs ramp exit barn puma paid zaps safe down zest gyro days gear deli huts task bulb lazy maze fund epic paid kept beta frog code kick hawk yoga blue lung loud bald hang fund wolf rich glow quiz gush next days eyes jazz keys chef note slot omit",
            "iron cola bald warm vibe void cost iron back help vast menu cost meow ruby exam wall limp guru cats miss puff cyan gems list puff view oval solo zaps body wand swan loud trip undo vows arch inch pose nail unit lung jolt numb numb note cusp belt acid flap math pose quad barn apex cusp puma drop data real cusp king when math slot ruin jazz data down pose view saga toys iron drop fish data play kick",
            "runs tied maze zinc knob jolt quiz user wand keep junk monk task tied hawk keys help zest holy atom flux crux logo girl waxy oboe unit soap curl atom wasp waxy vibe vows luck next each hill slot zone frog dull mint wave wolf code judo join girl lung flux redo yawn lava surf void barn trip warm fuel safe wolf foxy waxy cash high play soap cats pose runs purr body need vibe skew omit oboe horn",
            "yoga jowl keys play days barn very draw inky keep math epic when fair menu keep drum epic real blue wall away vibe keep next curl need jade love knob junk scar part fizz epic need jury user door leaf cost wasp purr vial hang horn tiny yoga poem rock rock claw jowl cusp real horn aqua acid figs miss even bias free lamb luau puff body calm arch rock puff miss fuel wolf",
            "inch back judo aqua good acid cola dull bald meow tiny yurt into diet love menu junk figs race leaf nail zoom fish keys edge film flux race frog jade holy warm paid brag zoom yurt flew toil idea mild owls kiwi flew beta soap heat gray film waxy each mild kick iced liar king kiwi when yurt scar drop fair navy fund yoga yank dull silk inch warm judo surf atom apex lazy good",
        ]
        let expectedURs = [
            "ur:provenance/lfadhdetkbrehkrkrsjztodskpdaasjymthdwfbycfvlisdyhdgeeyotrnmoeyplpefdwemubkuobgonnboebnjeeoatlocfpsvemtoscwsbfelpbbrorkeehpmegezs",
            "ur:provenance/lfadhddpinhlpeoyettkvwetpdtafwcewycfbwweckfyatpskehtbewndwntsgmhkeutsograxgomnfwdmwedmdraslymocltlswrefprt",
            "ur:provenance/lfadhdfzrnuyoespptjtsatnbgfzfhdwzmosglaedebbcatlmhcabwttwtzstnaxadmsdstylujljlfzfwcyloyatkcmmsnlgasolbmugondlklorodleccwrnlypkrddioxcmtaprdabbhd",
            "ur:provenance/lfadhdgutijoenjscfsnbkaoyamddwdleodldwstemaayasnhnoydkntcmremkgagtdsgytijytsgrgthkdeckbsuyaxntdlrncsuylapectjltphpgdbgfeprrpmurowpgoessnchprfyprprrnfwvoaektcpvozojoylkomhldynldbwynko",
            "ur:provenance/lfadhdecgolngthkswmdtphgeyatrpgrzsbwmsyldizsemcluowlgubtsekinstinsaehlykamkiwtgovaferdpdmelkjnbgrdclwzbkjlpyaoylhnmssgfwhn",
            "ur:provenance/lfadhdettegyylurwkcfaemypansglwsrpetbnpapdzssednztgodsgrdihstkbblymefdecpdktbafgcekkhkyabelgldbdhgfdwfrhgwqzghntdsesjzksgtdkptsr",
            "ur:provenance/lfadhdgsincabdwmvevdctinbkhpvtmuctmwryemwllpgucsmspfcngsltpfvwolsozsbywdsnldtpuovsahihpenlutlgjtnbnbnecpbtadfpmhpeqdbnaxcppadpdarlcpkgwnmhstrnjzdadnpevwsatsindppyotlben",
            "ur:provenance/lfadhdgrrstdmezckbjtqzurwdkpjkmktktdhkkshpzthyamfxcxloglwyoeutspclamwpwyvevslkntehhlstzefgdlmtwewfcejojngllgfxroynlasfvdbntpwmflsewffywychhhpyspcspersprbyndveesiajptt",
            "ur:provenance/lfadhdfgyajlkspydsbnvydwiykpmhecwnfrmukpdmecrlbewlayvekpntclndjelekbjksrptfzecndjyurdrlfctwpprvlhghntyyapmrkrkcwjlcprlhnaaadfsmsenbsfelblupfbycmahrktbjzgufr",
            "ur:provenance/lfadhdflihbkjoaagdadcadlbdmwtyytiodtlemujkfsrelfnlzmfhkseefmfxrefgjehywmpdbgzmytfwtliamdoskifwbasphtgyfmwyehmdkkidlrkgkiwnytsrdpfrnyfdyaykdlskihwmjosffsttiagm",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfadhdetkbrehkrkrsjztodskpdaasjymthdwfbycfvlisdyhdgeeyotrnmoeyplpefdwemubkuobgonnboebnjeeoatlocfpsvemtoscwsbfelpbbrorkeenytbuysb",
            "https://example.com/validate?provenance=tngdgmgwhflfadhddpinhlpeoyettkvwetpdtafwcewycfbwweckfyatpskehtbewndwntsgmhkeutsograxgomnfwdmwedmdraslymocltlcllegmdm",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfzrnuyoespptjtsatnbgfzfhdwzmosglaedebbcatlmhcabwttwtzstnaxadmsdstylujljlfzfwcyloyatkcmmsnlgasolbmugondlklorodleccwrnlypkrddioxcmtajytlselk",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdgutijoenjscfsnbkaoyamddwdleodldwstemaayasnhnoydkntcmremkgagtdsgytijytsgrgthkdeckbsuyaxntdlrncsuylapectjltphpgdbgfeprrpmurowpgoessnchprfyprprrnfwvoaektcpvozojoylkomhldynlpredeld",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdecgolngthkswmdtphgeyatrpgrzsbwmsyldizsemcluowlgubtsekinstinsaehlykamkiwtgovaferdpdmelkjnbgrdclwzbkjlpyaoylhnetkbhlts",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdettegyylurwkcfaemypansglwsrpetbnpapdzssednztgodsgrdihstkbblymefdecpdktbafgcekkhkyabelgldbdhgfdwfrhgwqzghntdsesjzkslkiaetwz",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdgsincabdwmvevdctinbkhpvtmuctmwryemwllpgucsmspfcngsltpfvwolsozsbywdsnldtpuovsahihpenlutlgjtnbnbnecpbtadfpmhpeqdbnaxcppadpdarlcpkgwnmhstrnjzdadnpevwsatsindpgylasrat",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdgrrstdmezckbjtqzurwdkpjkmktktdhkkshpzthyamfxcxloglwyoeutspclamwpwyvevslkntehhlstzefgdlmtwewfcejojngllgfxroynlasfvdbntpwmflsewffywychhhpyspcspersprbyndvebzvocxtk",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdfgyajlkspydsbnvydwiykpmhecwnfrmukpdmecrlbewlayvekpntclndjelekbjksrptfzecndjyurdrlfctwpprvlhghntyyapmrkrkcwjlcprlhnaaadfsmsenbsfelblupfbycmahrkbtmoadkb",
            "https://example.com/validate?provenance=tngdgmgwhflfadhdflihbkjoaagdadcadlbdmwtyytiodtlemujkfsrelfnlzmfhkseefmfxrefgjehywmpdbgzmytfwtliamdoskifwbasphtgyfmwyehmdkkidlrkgkiwnytsrdpfrnyfdyaykdlskihwmjosffrrfdect",
        ]
        runTest(resolution: .medium, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testQuartile() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb5094, hash: 848382e45acc9106b43e343de1a6fc9d, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2da, hash: eddc651b9432368f86764605968a4a3f, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: d070367119cd0a0255864d59c695d857, hash: e1435cb90cb731a75e64db8748027953, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69, hash: 4b82a4b49dea925f347feef96cbbfbdb, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4dff86f78ab260ce12c, hash: 019298021c81c073770723c3c5f6280e, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c2, hash: 37f45cf43b6f10fc4b1ba0ab29b84a94, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 24539e315edbdc34b0dd5361956328ca, hash: a4462e43024a4d10fe89d69dc390318a, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0e, hash: df8311b0a5337f44988d60d703bfb29a, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: e1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 6035e55452c41bc2917117750d1f9813, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2, hash: 839ef5b93df3c48c23c7d6df3c0cbe87, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow zest ruby main zest gyro jazz hard sets even kiln also visa road rich brag leaf poem taco cusp cook junk item solo user cusp maze list dark junk pose brew code flew mild navy jolt kiln help yoga calm idea flux redo rust buzz zaps",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi yurt silk hill horn cost foxy cats vows silk bulb omit arch part rust ugly zest surf gyro quiz exit knob even free duty wand able solo peck navy crux zest crux lamb huts liar zoom skew heat kite runs what inky navy nail idea",
            "taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang swan atom view play zero king surf gray lamb road song acid yawn hope kick diet zest guru help gala lazy keys hill fern even gems gift wand veto what glow kept jolt claw drop foxy lazy obey very help item gala jury horn idle judo",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron vial jazz keno twin draw jury limp into cola cats lung navy days easy fair open swan door kick purr dice able numb eyes kept toil belt junk kiln film keys item judo door yoga poem navy calm lung nail drum apex apex flew cats judo",
            "runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw legs redo tomb love hang gray data keno hang numb flux jury hope king girl help aunt visa drop aunt guru need jazz math task brag list gems glow stub wand iron skew idea inch gray main into heat fact keno drum vibe cost zoom atom",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga ruin soap aunt also unit bald keys flew twin zest half echo jade math loud void huts undo leaf mild keep inky horn gush omit lava rock join logo easy draw toys time lazy toil nail logo rock kiwi toys news yoga hawk main horn silk",
            "dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song limp zinc memo game axis love note nail list zest horn eyes item keys apex glow dice king navy fern logo maze owls duty eyes days echo noon eyes gift void meow drop loud jazz onyx jugs inky slot join twin inch urge apex limp hill",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta warm dice deli tent visa dull lava door join brew view claw tent tiny urge inky even wasp tied main exam wasp puff also many purr bias gray also miss dice vast toys iris buzz idea webs beta zoom open note mint hawk taco loud cats",
            "very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic trip curl aunt epic note tiny zero yawn buzz sets judo wasp blue iced free cook exam soap hang jolt many brew diet note buzz apex hope omit work drop even nail taxi twin what redo days hill jugs claw beta idle kiwi visa unit rock",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr door saga kept dark scar kite oval lion navy jump view oval down hope iced paid brew arch menu gems tent silk ruin wall yell huts hang taco zone peck noon yawn bias rich miss idle jury vibe oboe wand good yell edge arch duty keep",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdftkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfpmtocpckjkimsourcpmeltdkjkpebwcefwmdnyjtknhpyacmiafxcnyardcy",
            "ur:provenance/lfaohdftinhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuyztsfgoqzetkbenfedywdaesopknycxztcxlbhslrzmswhtkerswtzcoeenls",
            "ur:provenance/lfaohdfttijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtztguhpgalykshlfnengsgtwdvowtgwktjtcwdpfylyoyvyhpimgawshdsbmh",
            "ur:provenance/lfaohdfttegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronsndrkkprdeaenbeskttlbtjkknfmksimjodryapmnycmlgnldmaxmkknrlmh",
            "ur:provenance/lfaohdftrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpatvadpatgundjzmhtkbgltgsgwsbwdinswiaihgymniohtftkodmlbdigdva",
            "ur:provenance/lfaohdftihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdhsuolfmdkpiyhnghotlarkjnloeydwtstelytlnllorkkitsnsyasarptkda",
            "ur:provenance/lfaohdftdkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwdekgnyfnlomeosdyesdseonnesgtvdmwdpldjzoxjsiystjntnihfefrdrry",
            "ur:provenance/lfaohdftlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyenwptdmnemwppfaomyprbsgyaomsdevttsisbziawsbazmonnemtsayndsya",
            "ur:provenance/lfaohdftvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckemsphgjtmybwdtnebzaxheotwkdpennltitnwtrodshljscwbaievauejphp",
            "ur:provenance/lfaohdftntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdbwahmugsttskrnwlylhshgtozepknnynbsrhmsiejyveoewdgdylpefsnemd",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfpmtocpckjkimsourcpmeltdkjkpebwcefwmdnyjtknhpyacmiafxidpmurfs",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftinhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuyztsfgoqzetkbenfedywdaesopknycxztcxlbhslrzmswhtkerswtrfylguox",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfttijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtztguhpgalykshlfnengsgtwdvowtgwktjtcwdpfylyoyvyhpimgaplbtplrl",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfttegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronsndrkkprdeaenbeskttlbtjkknfmksimjodryapmnycmlgnldmaxtadltdrl",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpatvadpatgundjzmhtkbgltgsgwsbwdinswiaihgymniohtftkodmfmjpecse",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdhsuolfmdkpiyhnghotlarkjnloeydwtstelytlnllorkkitsnsyalsvlpkao",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftdkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwdekgnyfnlomeosdyesdseonnesgtvdmwdpldjzoxjsiystjntnihaajtgwny",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyenwptdmnemwppfaomyprbsgyaomsdevttsisbziawsbazmonnemtlsotfxur",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckemsphgjtmybwdtnebzaxheotwkdpennltitnwtrodshljscwbaieosluchke",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdftntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdbwahmugsttskrnwlylhshgtozepknnynbsrhmsiejyveoewdgdylwyiszspr",
        ]
//        runTest(resolution: .quartile, includeInfo: false, onlyPrint: true)
        runTest(resolution: .quartile, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testQuartileWithInfo() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb5094, hash: 871e091932cb71a8061b5af0914d19cd, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 0, date: 2023-06-20T12:00:00Z, info: "Explicabo Occaecati")"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2da, hash: 1ae98d0745290ea2948f1c68fe342165, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 1, date: 2023-06-21T12:00:00Z, info: "Nisi Quis Odio")"#,
            #"ProvenanceMark(key: d070367119cd0a0255864d59c695d857, hash: a019e990a8175a5004caff9966a95d5b, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 2, date: 2023-06-22T12:00:00Z, info: "Corporis Molestias Consequuntur")"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69, hash: 3798e2d3335da34b1f153934e9bb068e, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 3, date: 2023-06-23T12:00:00Z, info: "Blanditiis Voluptatum Ut Est Quos Explicabo")"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4dff86f78ab260ce12c, hash: d848998497c23766eb21a6819a73e8c1, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 4, date: 2023-06-24T12:00:00Z, info: "Repellendus Dolor Et")"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c2, hash: e99523659d3517f207ff77fd2681eb58, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 5, date: 2023-06-25T12:00:00Z, info: "Consequatur Dignissimos")"#,
            #"ProvenanceMark(key: 24539e315edbdc34b0dd5361956328ca, hash: 5f9d893f0a7ba524f4e79ea76bef0b0c, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 6, date: 2023-06-26T12:00:00Z, info: "Quia Ut Praesentium Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0e, hash: 49d5c08d990b77f437f5de6e3fd9fc58, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 7, date: 2023-06-27T12:00:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: e1929c31e0f8c8c5e0b74cbbb4fdba35, hash: fb889323ebaae601c249cf8122d79dec, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 8, date: 2023-06-28T12:00:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2, hash: 818b1f564aa2554c84d0148ca0572e69, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 9, date: 2023-06-29T12:00:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow zest ruby main zest gyro jazz hard sets even kiln also visa road rich brag leaf pool guru part vial claw join diet jugs math quiz wall wall apex foxy yawn gems flew mild navy jolt kiln help yoga calm idea flux fern wasp noon lamb toys kept waxy swan knob omit wolf tiny cyan what kick mint vast cola puma even task calm king toil",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi yurt silk hill horn cost foxy cats vows silk bulb omit arch part rust ugly bald yurt ruby paid wall inch beta iris cusp brew heat onyx saga dark gear oval crux lamb huts liar zoom skew heat kite runs what hard fizz body tied barn slot axis many vows rich junk list fish roof chef hill jade bias dull",
            "taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang swan atom view play zero king surf gray lamb road song acid yawn hope kick diet ruby axis waxy horn data trip even stub jazz veto iron work surf help jade lamb jolt claw drop foxy lazy obey very help item gala claw wall owls leaf hard purr list miss acid waxy holy poem calm solo chef maze veto mild ugly keno wolf glow trip need time rich arch open flew note tomb next next echo logo stub monk",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron vial jazz keno twin draw jury limp into cola cats lung navy days easy fair open puma duty fish toil lion real maze drop high runs twin ruin zoom film limp fish judo door yoga poem navy calm lung nail drum apex draw meow poem leaf down luau zaps holy exam memo lamb play jury skew ruby epic what ramp flew love guru holy flux keep king urge tuna keep exit note hawk hard cola when help able luau glow each jazz body girl meow swan tied cook beta bulb yell",
            "runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw legs redo tomb love hang gray data keno hang numb flux jury hope king girl help urge fern draw lazy trip trip need limp guru edge also beta blue girl door oval skew idea inch gray main into heat fact keno drum fish good wolf time ugly jade road beta wasp iced diet luau vows tiny exit yurt part hawk atom able cash exit sets keno calm",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga ruin soap aunt also unit bald keys flew twin zest half echo jade math loud void runs ruby zinc aqua time fern into heat webs idle jazz fair list bald lung claw time lazy toil nail logo rock kiwi toys news yoga back join wall silk iced view exit kept gush kite rust blue curl peck fact saga puff time horn scar gear cook limp echo soap draw kept menu",
            "dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song limp zinc memo game axis love note nail list zest horn eyes item keys apex glow time numb figs fizz lava numb glow aqua echo fund king onyx maze easy unit brag drop loud jazz onyx jugs inky slot join twin inch drum draw keep lava tied jowl each jolt jowl iron bulb what zest part jump gift flux dice calm jugs hawk silk ruin waxy epic into help hill edge noon tomb unit iced even skew lung kept chef pose kick judo king draw ruby gush keys hill flew",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta warm dice deli tent visa dull lava door join brew view claw tent tiny urge inky numb road apex quad bald tiny redo purr crux song puma vows film when inky cusp toys iris buzz idea webs beta zoom open note mint free half urge limp good help swan jade jugs jade plus twin diet cats luau jowl idea data tied next data tomb twin curl what edge barn zoom each leaf also heat buzz surf oboe love plus race buzz zone belt gems gift iced calm roof urge",
            "very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic trip curl aunt epic note tiny zero yawn buzz sets judo wasp blue iced free cook plus keep curl chef even kiwi tiny high frog fair list hang ugly view echo inky taxi twin what redo days hill jugs claw beta idle limp zest lazy gray barn figs fizz unit when mild miss note join half bald view gyro leaf sets jade easy part whiz noon logo onyx saga scar fair horn mint work aqua heat undo redo view fair cyan wave idle luau",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr door saga kept dark scar kite oval lion navy jump view oval down hope iced paid body blue kick omit oval meow dull diet good keno mild next iced when beta cats bias rich miss idle jury vibe oboe wand good yell jolt tuna what cusp logo veto door vial surf claw help unit very high tuna waxy wolf monk lion jugs iced aunt puma rock oval diet kick belt acid fair luck lava task wolf figs yawn navy king wave work kiwi high mild",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdglkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfplguptvlcwjndtjsmhqzwlwlaxfyyngsfwmdnyjtknhpyacmiafxfnwpnnlbtsktwysnkbotwftycnwtkkmtvtcapaencsytadia",
            "ur:provenance/lfaohdgainhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuybdytrypdwlihbaiscpbwhtoxsadkgrolcxlbhslrzmswhtkerswthdfzbytdbnstasmyvsrhjkltfhrfcfadiohywe",
            "ur:provenance/lfaohdhptijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtryaswyhndatpensbjzvoinwksfhpjelbjtcwdpfylyoyvyhpimgacwwloslfhdprltmsadwyhypmcmsocfmevomduykowfgwtpndterhahonfwnetbntntkkoewpca",
            "ur:provenance/lfaohdiotegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronpadyfhtllnrlmedphhrstnrnzmfmlpfhjodryapmnycmlgnldmaxdwmwpmlfdnluzshyemmolbpyjyswryecwtrpfwleguhyfxkpkguetakpetnehkhdcawnhpaelugwehjzbyglmwsntdlefgntfm",
            "ur:provenance/lfaohdgwrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpuefndwlytptpndlpgueeaobabegldrolswiaihgymniohtftkodmfhgdwfteuyjerdbawpiddtluvstyetytpthkamaechamenchrt",
            "ur:provenance/lfaohdgmihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdrsryzcaatefniohtwsiejzfrltbdlgcwtelytlnllorkkitsnsyabkjnwlskidvwetktghkertbeclpkftsapftehnsrgrcklpeodazemkws",
            "ur:provenance/lfaohdiydkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwtenbfsfzlanbgwaaeofdkgoxmeeyutbgdpldjzoxjsiystjntnihdmdwkplatdjlehjtjlinbbwtztptjpgtfxdecmjshkskrnwyeciohphleenntbutidenswlgktcfpekkjokgdwryjobyskae",
            "ur:provenance/lfaohdihlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiynbrdaxqdbdtyroprcxsgpavsfmwniycptsisbziawsbazmonnemtfehfuelpgdhpsnjejsjepstndtcslujliadatdntdatbtnclwteebnzmehlfaohtbzsfoelepsrebzzebtgsgtrsihjyrk",
            "ur:provenance/lfaohdhnvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckpskpclcfenkityhhfgfrlthguyvweoiytitnwtrodshljscwbaielpztlygybnfsfzutwnmdmsnejnhfbdvwgolfssjeeyptwznnlooxsasrfrhnmtwkaahtuorovwfrlnjsrkgm",
            "ur:provenance/lfaohdhsntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdbybekkotolmwdldtgdkomdntidwnbacsbsrhmsiejyveoewdgdyljttawtcplovodrvlsfcwhputvyhhtawywfmklnjsidatparkoldtkkbtadfrlklatkwffsynnykgwehsbgfhjn",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdglkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfplguptvlcwjndtjsmhqzwlwlaxfyyngsfwmdnyjtknhpyacmiafxfnwpnnlbtsktwysnkbotwftycnwtkkmtvtcapaencejkaxgo",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgainhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuybdytrypdwlihbaiscpbwhtoxsadkgrolcxlbhslrzmswhtkerswthdfzbytdbnstasmyvsrhjkltfhrfcfonrnwnti",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhptijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtryaswyhndatpensbjzvoinwksfhpjelbjtcwdpfylyoyvyhpimgacwwloslfhdprltmsadwyhypmcmsocfmevomduykowfgwtpndterhahonfwnetbntntplnblgby",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdiotegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronpadyfhtllnrlmedphhrstnrnzmfmlpfhjodryapmnycmlgnldmaxdwmwpmlfdnluzshyemmolbpyjyswryecwtrpfwleguhyfxkpkguetakpetnehkhdcawnhpaelugwehjzbyglmwsntdimlpihle",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgwrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpuefndwlytptpndlpgueeaobabegldrolswiaihgymniohtftkodmfhgdwfteuyjerdbawpiddtluvstyetytpthkamaechsoloayhp",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgmihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdrsryzcaatefniohtwsiejzfrltbdlgcwtelytlnllorkkitsnsyabkjnwlskidvwetktghkertbeclpkftsapftehnsrgrcklpeoecfrhedk",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdiydkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwtenbfsfzlanbgwaaeofdkgoxmeeyutbgdpldjzoxjsiystjntnihdmdwkplatdjlehjtjlinbbwtztptjpgtfxdecmjshkskrnwyeciohphleenntbutidenswlgktcfpekkjokgdwryiyaejlbk",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdihlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiynbrdaxqdbdtyroprcxsgpavsfmwniycptsisbziawsbazmonnemtfehfuelpgdhpsnjejsjepstndtcslujliadatdntdatbtnclwteebnzmehlfaohtbzsfoelepsrebzzebtgsgtsaaefrie",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhnvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckpskpclcfenkityhhfgfrlthguyvweoiytitnwtrodshljscwbaielpztlygybnfsfzutwnmdmsnejnhfbdvwgolfssjeeyptwznnlooxsasrfrhnmtwkaahtuorovwfrbtvafpls",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhsntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdbybekkotolmwdldtgdkomdntidwnbacsbsrhmsiejyveoewdgdyljttawtcplovodrvlsfcwhputvyhhtawywfmklnjsidatparkoldtkkbtadfrlklatkwffsynnykgwemhgtgetl",
        ]
//        runTest(resolution: .quartile, includeInfo: true, onlyPrint: true)
        runTest(resolution: .quartile, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testHigh() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, hash: cd6e66cd0e370db5b3b38cc57724de30dde9f45bb71455c98868eb17c20dfb1b, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2dad070367119cd0a0255864d59c695d857, hash: 6466ecbe6bd6a89ce17d7462050bcf9a82fbe53c28eec375210a779744a29259, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69bfd291fd7e6eb4dff86f78ab260ce12c, hash: d90c63d850043627b2849958fee544ce1cd4e9be40a117cf744f9cfb0cb3c5b5, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c224539e315edbdc34b0dd5361956328ca, hash: 1c17eeadd1c9f46b5b434a9333c7ade0111f4ddb39621f6249d0374aad46ef1a, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0ee1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 351250af36e7621252a151b2a080c15a5ad235f71b4f3c36a28ed06594ac1f99, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2cc519d3df4f241dc98a285963646294d, hash: 4624022ad4b809b43c61d7ab1b4c9a7e9afca8b134a27de74604862ab7647c60, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 1f1df300ca1ba7e6e192dfdc4debe4d643026c948ef84fc50fd81ef55a3fe95a, hash: ab45446cd432453efd2bbc33de97b4d4f56adc4a7a0dadac0564f765d215aa46, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 10cf8fb2ae8719ead09a153aa193e05d7abf97501bac041942a1a502e7f5eeba, hash: ddecb70a8abcd1bcd89c4af1f86575c3fd206675a6661c744b711882bd703f0a, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: 186d0597dfd56a71abf4e86004c822600e4c72f6e3cf9d2a0f0c03aff38bd48d, hash: c7424807a7f65673731307fd7c63c44b43089fb4d846e80ab516c42d366c11d6, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: e079e69f4ad9ae5fd8ce003998741df6598920846424db654b41f341d50fc56b, hash: 7fe4563dd214e7370613ac3e8af65ede53296cee4596f5fa4330bb8042c788a7, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow figs void very stub poem gush undo zaps purr kiln flew keep note holy dull wave free holy keep jury need logo echo iron barn beta foxy fair vibe gems need flux crux jowl real idea also purr huts calm zaps next work gush limp note real owls song idea paid puff waxy buzz love frog cyan jade dark cats miss iron next tomb swan noon gems fair wall purr zest cola curl onyx tomb away cash pool veto data main webs jugs peck skew idle gear main onyx glow cats lamb lung kiwi",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang love road gush poem curl peck even math lazy yawn nail kiln task noon soap drum ramp jolt buzz warm axis exit ruin ruin plus math pose many saga roof mild good road hope silk dull curl time gala figs body kick song exit item dice bias echo kite soap curl cost swan meow purr hill epic task flew cash kiwi many when ruby yawn beta jazz loud meow inch ramp edge swan iced unit fizz fund wand",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw undo help bias hawk blue noon tied able arch undo iced hope help undo idle skew wall gyro echo deli huts barn exit omit noon task twin cola need silk acid axis inky cola noon void keep city zinc gray void next dull hope fair horn omit cats maze lung safe exam menu when zone luck play warm echo cyan redo gear acid loud loud junk trip mint surf wolf oboe blue item calm kept fuel tiny film",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song view toys axis king cats judo legs fund zero void keep aunt visa yoga puma flew fizz inch solo holy fern silk king zone surf draw fair exit rich puff yell vows judo gear calm hope frog heat item silk flap vibe gift trip bald diet door saga vast void lion vows redo gyro warm zero void meow scar fern play very easy dice miss diet eyes judo huts away wall cash draw scar note work cost jump",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic frog omit vial real love wolf toil toys when wave monk cats taco kiwi aunt saga time jump jump dull road lion echo noon roof eyes toys arch when zaps owls grim redo oboe nail need taco cats vows help back away numb beta lava even very wasp door rust wand mint yoga easy lava away pool vial luau toil tomb cola legs nail mild surf cats join note gala even limp lion obey kick brag ugly sets",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr surf gray next figs work whiz flap undo monk oboe limp mint even frog diet gift help kick wolf saga door navy gush door zone zest brew fizz gush code hard menu dice jump huts legs when girl logo free zero rich vial user code cyan meow need jade ramp ruby wave flux undo join view apex zaps view exam exit blue wall even drop gala sets whiz bias wolf miss blue join waxy city king calm unit webs fish runs kiln deli atom quad song puff iris tuna skew oval belt math taco",
            "cost cola wolf able song claw owls visa very memo user undo gift warm vibe tomb flux also jazz meow main yoga glow silk bias trip cook yank heat fish wall heat soap jolt void legs toil bias gala saga bald very leaf crux jazz fish heat horn list yoga pool iced barn kite cyan inky idle vibe work race eyes note toys deli legs keep even keno into echo zero whiz foxy paid vial duty gear pool hang heat list rich flux rust sets inch keys back duty plus skew logo fuel kick open fair idea taco yell grim jump code gush down wave free beta grim luau gala",
            "blue task many purr pool list chef wand taxi navy buzz fact obey menu vast hill kiln runs miss good claw plus aqua chef flew obey open also void yank waxy road plus undo cook city roof glow silk tomb hope vows luck flux kick zone edge guru numb redo claw aunt lava rich apex soap scar jowl real help hard gift belt jowl iris menu code race waxy legs barn gear flux list keys inky drum tuna bias atom solo claw gala brew calm math main dark echo keys tomb urge diet soap jolt void flew apex brew what hawk dice wasp deli judo draw figs runs roof view",
            "cats join arch miss user toil item jugs play work vows horn aqua soap cusp horn beta gems jump yawn vial task next door bias barn apex pose wolf luau tiny lung rich wolf peck free poem king jade lazy flap cola days zaps monk surf junk tiny open inky twin holy kick film omit item lazy dull owls help into body fair dice chef keno beta bias view scar tied jolt zero menu judo king hill kept skew atom real fund kite huts zest holy omit crux data love lava hard gala knob body solo hard hang ramp flap wasp mint tomb view hawk away omit axis tent zaps",
            "vast kick visa note game tuna pool hope trip taco able eyes monk jury cola yawn hawk loud crux liar idle dark ugly inch gear flap wolf flap toil bias silk jade vibe quiz ramp calm idle wand gala loud zero omit iced figs task silk waxy gyro yurt skew vast list kite kite jury cyan data toil luau obey gyro unit redo tied back zero memo jump inky whiz zaps hang mint girl body rich liar slot mint lava webs diet horn quiz jowl puff numb fish dice also brag urge half epic redo beta belt lion limp memo jazz idea claw epic days jazz claw data back saga",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdimkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerlossgiapdpfwybzlefgcnjedkcsmsinnttbsnnngsfrwlprztcacloxtbaychplvodamnwsjspkswiegrmnoxgwasjzssks",
            "ur:provenance/lfaxhdiminhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdrdheskdlcltegafsbykksgetimdebseokespclctsnmwprhlectkfwchkimywnryynbajzldmwihrpeesnidsfguadws",
            "ur:provenance/lfaxhdimtegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadasiycannvdkpcyzcgyvdntdlhefrhnotcsmelgseemmuwnzelkpywmeocnrogradldldjktpmtsfwfoebeimcmiyghntfr",
            "ur:provenance/lfaxhdimihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvsjogrcmhefghtimskfpvegttpbddtdrsavtvdlnvsrogowmzovdmwsrfnpyvyeydemsdtesjohsaywlchdwsrmnvdhfkt",
            "ur:provenance/lfaxhdimlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmrooenlndtocsvshpbkaynbbalaenvywpdrrtwdmtyaeylaayplvllutltbcalsnlmdsfcsjnnegaenlplnoyisadmose",
            "ur:provenance/lfaxhdimntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndjerprywefxuojnvwaxzsvwemetbewlendpgasswzbswfmsbejnwycykgcmutwsfhrskndiamqdsgpfistaswrlcktasb",
            "ur:provenance/lfaxhdimctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdilskpenkoioeozowzfypdvldygrplhghtltrhfxrtssihksbkdypsswloflkkonfriatoylgmjpceghdnwefectfpsags",
            "ur:provenance/lfaxhdimbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlismucerewylsbngrfxltksiydmtabsamsocwgabwcmmhmndkeokstbuedtspjtvdfwaxbwwthkdewpdijodwdwpsykvt",
            "ur:provenance/lfaxhdimcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdecfkobabsvwsrtdjtzomujokghlktswamrlfdkehszthyotcxdalelahdgakbbysohdhgrpfpwpmttbvwhkayprcymkzm",
            "ur:provenance/lfaxhdimvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdbkzomojpiywzzshgmtglbyrhlrstmtlawsdthnqzjlpfnbfhdeaobguehfecrobabtlnlpmojziacwecdsjzbkenfxst",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerlossgiapdpfwybzlefgcnjedkcsmsinnttbsnnngsfrwlprztcacloxtbaychplvodamnwsjspkswiegrmnoxgwbzeoimwm",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdiminhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdrdheskdlcltegafsbykksgetimdebseokespclctsnmwprhlectkfwchkimywnryynbajzldmwihrpeesnidtibnpeke",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimtegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadasiycannvdkpcyzcgyvdntdlhefrhnotcsmelgseemmuwnzelkpywmeocnrogradldldjktpmtsfwfoebeimcmknbdeopd",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvsjogrcmhefghtimskfpvegttpbddtdrsavtvdlnvsrogowmzovdmwsrfnpyvyeydemsdtesjohsaywlchdwsrmoroyave",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmrooenlndtocsvshpbkaynbbalaenvywpdrrtwdmtyaeylaayplvllutltbcalsnlmdsfcsjnnegaenlplnoyjyhyfngm",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndjerprywefxuojnvwaxzsvwemetbewlendpgasswzbswfmsbejnwycykgcmutwsfhrskndiamqdsgpfistaswpyfpkthd",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdilskpenkoioeozowzfypdvldygrplhghtltrhfxrtssihksbkdypsswloflkkonfriatoylgmjpceghdnwefeaxckjzur",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlismucerewylsbngrfxltksiydmtabsamsocwgabwcmmhmndkeokstbuedtspjtvdfwaxbwwthkdewpdijodwdywfhpjk",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdecfkobabsvwsrtdjtzomujokghlktswamrlfdkehszthyotcxdalelahdgakbbysohdhgrpfpwpmttbvwhkayplfeenjz",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdimvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdbkzomojpiywzzshgmtglbyrhlrstmtlawsdthnqzjlpfnbfhdeaobguehfecrobabtlnlpmojziacwecdsjzcminwegh",
        ]
//        runTest(resolution: .high, includeInfo: false, onlyPrint: true)
        runTest(resolution: .high, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testHighWithInfo() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, hash: 7e0460bc89e92f0cfd54650d4671b9d3ac5615dd5a9362eebb5fc2d9c15607a0, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 0, date: 2023-06-20T12:00:00Z, info: "Consequuntur Esse Rem Et Aliquam")"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2dad070367119cd0a0255864d59c695d857, hash: 0ccc1855b245d9371b21680044cc5bb2c107e055b514ed086147a07e7b50fcb3, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 1, date: 2023-06-21T12:00:00Z, info: "Quos Explicabo Ullam Corrupti Odit Ab")"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69bfd291fd7e6eb4dff86f78ab260ce12c, hash: 8b41710d9881abdcddbbb8e847f70b890faefbba29959332f9de2af3b1129246, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 2, date: 2023-06-22T12:00:00Z, info: "Qui Debitis Quia Ut")"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c224539e315edbdc34b0dd5361956328ca, hash: 54669292abbe58a8723396dcaf83f42c8ca29e918d250ba91907597f8a8865b1, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 3, date: 2023-06-23T12:00:00Z, info: "Animi Et Nesciunt Expedita Aut Doloremque Omnis")"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0ee1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 7b7aedf9907084909155f95694d5c47a80e5811abbbe396141dbb8fc457035a6, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 4, date: 2023-06-24T12:00:00Z, info: "Voluptatem Cumque Totam Sed")"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2cc519d3df4f241dc98a285963646294d, hash: e854d810b7a6568fefd567d2ac72683d8df2ab2c20773dafea79ad3a3f64c4e3, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 5, date: 2023-06-25T12:00:00Z, info: "Dolor Qui Voluptatem Officiis Cupiditate")"#,
            #"ProvenanceMark(key: 1f1df300ca1ba7e6e192dfdc4debe4d643026c948ef84fc50fd81ef55a3fe95a, hash: 4887a4e23391fbc1a3c1170ad72610e4ed4e15cfe6bf770570f8638ea1f9644c, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 6, date: 2023-06-26T12:00:00Z, info: "Atque Quo Dolorem Aliquid Accusamus Qui In")"#,
            #"ProvenanceMark(key: 10cf8fb2ae8719ead09a153aa193e05d7abf97501bac041942a1a502e7f5eeba, hash: d01b925d5a545bcab4d9e6fe5234e762d25033b7aae1166c40f90a61662c1d7b, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 7, date: 2023-06-27T12:00:00Z, info: "Praesentium Sint Voluptatibus")"#,
            #"ProvenanceMark(key: 186d0597dfd56a71abf4e86004c822600e4c72f6e3cf9d2a0f0c03aff38bd48d, hash: 0f6216983c0e0b127603b1c774b6c808823a76fc5c7627f96addcd3d11f823ae, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 8, date: 2023-06-28T12:00:00Z, info: "Ut Assumenda Aperiam Sequi Ut Saepe Impedit")"#,
            #"ProvenanceMark(key: e079e69f4ad9ae5fd8ce003998741df6598920846424db654b41f341d50fc56b, hash: 6f56932d1f645f62000e116dbd63664f207e35a6791fd6728186651a4bb723ae, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 9, date: 2023-06-29T12:00:00Z, info: "Voluptatum Dolorem Odio Sed Ab")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow figs void very stub poem gush undo zaps purr kiln flew keep note holy dull wave free holy keep jury need logo echo iron barn beta foxy fair vibe gems need flux crux jowl real idea also purr huts calm zaps next work gush limp note real owls kick axis pool safe iron stub paid zoom join luck swan taxi oval fern zaps epic roof curl poem ruby aqua epic stub fact brag menu zoom skew bulb yank cook noon main webs jugs peck skew idle gear main onyx glow body back leaf hard good whiz flap holy crux axis tuna gush join also cyan kick task slot oboe each able rich dull obey tomb poem soap play lung very ramp undo plus lion zinc toys lion zone",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang love road gush poem curl peck even math lazy yawn nail kiln task noon soap drum ramp jolt buzz warm axis exit ruin ruin plus math pose many saga roof mild good tied yank each sets yoga fizz exit mint warm data tomb heat down webs need claw fish edge dark keno good jolt news crux keep leaf mild zone flew kiwi note hang yawn beta jazz loud meow inch ramp edge swan iced aunt pool skew next puff exit dice dull frog kite skew cola city into wand zinc atom paid plus many kick runs roof bald wolf work flap zero math news back paid frog axis diet mild cusp fizz item wasp chef saga into",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw undo help bias hawk blue noon tied able arch undo iced hope help undo idle skew wall gyro echo deli huts barn exit omit noon task twin cola need silk acid axis edge good luck easy ruby note horn peck logo oboe beta webs leaf jump wasp hope leaf yell time echo zaps silk kiln jugs days kiln limp down arch wand half kiln loud junk trip mint surf wolf oboe blue item calm paid holy exam note urge body inch very song mild rust jugs ruin stub keno open redo wand plus cats zero stub keys poem",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song view toys axis king cats judo legs fund zero void keep aunt visa yoga puma flew fizz inch solo holy fern silk king zone surf draw fair exit rich puff yell vows exit fact item horn fern drop skew atom iris meow maze miss miss join junk beta kiwi heat gyro oboe barn brag zoom duty real flux poem axis luck dull redo legs miss diet eyes judo huts away wall cash draw scar jump acid yurt jugs onyx oboe rich ugly user hope eyes drop open math glow flew flap fuel taco dull inky memo oval leaf bulb free curl fact edge beta lamb saga into chef duty gyro frog girl zest lung dull zoom zero runs fact bias flap need love veto legs cost able",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic frog omit vial real love wolf toil toys when wave monk cats taco kiwi aunt saga time jump jump dull road lion echo noon roof eyes toys arch when zaps owls grim yawn song dark swan iris many beta tuna solo zest away wand quiz idea vibe surf what yell holy king hard scar limp hope gift ramp vial gems aunt safe part oval mild surf cats join note gala even limp lion obey surf wall cats vows yurt kiln chef liar gush vast cook high navy bald kiln puff oboe kick city scar back iris vial numb away bias onyx roof wand game vast knob wasp",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr surf gray next figs work whiz flap undo monk oboe limp mint even frog diet gift help kick wolf saga door navy gush door zone zest brew fizz gush code hard menu dice jump huts legs when girl logo free zero rich vial user code cyan meow need silk skew into toys crux saga easy urge taxi girl gyro girl many drum claw keep fact fuel slot jowl claw days toys hard safe menu each jade noon unit hang roof runs kiln deli atom quad song puff iris tuna skew jump exam road next work flew tomb work kiln real rock fuel duty undo hill kite bald idle even back miss quad fuel able join kite drum slot buzz game brew road lamb cash toil runs part quiz axis zest solo jazz drum whiz brew miss",
            "cost cola wolf able song claw owls visa very memo user undo gift warm vibe tomb flux also jazz meow main yoga glow silk bias trip cook yank heat fish wall heat soap jolt void legs toil bias gala saga bald very leaf crux jazz fish heat horn list yoga pool iced barn kite cyan inky idle vibe work race eyes note toys deli horn real tomb yoga lava math free belt city flew fund axis flew cost wolf item note next love free hard toys oboe omit free duty grim idea edge mild jade each idea taco yell grim jump code gush down wave free frog task road flux jump kite jury wolf lamb high jade need horn diet void tomb gush mild brew play jowl view jugs chef dice love exit acid glow holy logo jury diet silk taxi cats obey drum what join yell code keep peck axis ruby song even",
            "blue task many purr pool list chef wand taxi navy buzz fact obey menu vast hill kiln runs miss good claw plus aqua chef flew obey open also void yank waxy road plus undo cook city roof glow silk tomb hope vows luck flux kick zone edge guru numb redo claw aunt lava rich apex soap scar jowl real help hard gift belt jowl inch idle eyes veto film jade lion figs dull saga tiny iron liar logo next owls visa jade code tent city cash liar fern exit what sets figs whiz meow gems mint flew apex brew what hawk dice wasp deli judo draw fair hope kite help road safe miss brag time nail skew stub quiz calm legs runs mint yurt toys dark kiwi monk wave brew city taxi user jowl fuel veto high even calm free love",
            "cats join arch miss user toil item jugs play work vows horn aqua soap cusp horn beta gems jump yawn vial task next door bias barn apex pose wolf luau tiny lung rich wolf peck free poem king jade lazy flap cola days zaps monk surf junk tiny open inky twin holy kick film omit item lazy dull owls help into body fair dice tent half good math knob fair many bias zone legs skew flap gyro oboe song free keno kiln mild diet keys jolt jazz time zaps flap loud fund jolt wand cyan puma hard hang ramp flap wasp mint tomb view hawk away claw bias ramp yawn solo cook good visa blue half echo zero dark mint lung zinc note good zero jury half arch yoga numb taxi news away able acid zest twin exam taxi noon junk also sets gala visa oval foxy iron exit idea swan drop monk epic arch",
            "vast kick visa note game tuna pool hope trip taco able eyes monk jury cola yawn hawk loud crux liar idle dark ugly inch gear flap wolf flap toil bias silk jade vibe quiz ramp calm idle wand gala loud zero omit iced figs task silk waxy gyro yurt skew vast list kite kite jury cyan data toil luau obey gyro unit redo tied city gala hang iced play leaf flew also math guru plus wand quad grim pool body news knob eyes zest guru eyes legs real wand quiz surf foxy hope free brew aunt belt lion limp memo jazz idea claw epic days jazz luau inch pose cook jugs bald meow liar warm plus ruby taco hope gala city race race toil days yank rust zero view jolt drop taco paid bias hawk zinc stub wall idea toil news blue",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdlkkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerloskkasplseinsbpdzmjnlksntiolfnzsecrfclpmryaaecsbftbgmuzmswbbykcknnmnwsjspkswiegrmnoxgwbybklfhdgdwzfphycxastaghjnaocnkktkstoeehaerhdloytbpmsppylgvyrpuopslncypmskon",
            "ur:provenance/lfaxhdmeinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdtdykehssyafzetmtwmdatbhtdnwsndcwfheedkkogdjtnscxkplfmdzefwkinehgynbajzldmwihrpeesnidatplswntpfetdedlfgkeswcacyiowdzcampdpsmykkrsrfbdwfwkfpzomhnsbkpdfgasdtmdcpfzimksehtkur",
            "ur:provenance/lfaxhdkbtegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadaseegdlkeyrynehnpklooebawslfjpwphelfylteeozsskknjsdsknlpdnahwdhfknldjktpmtsfwfoebeimcmpdhyemneuebyihvysgmdrtjsrnsbkoonrowdpscsnswebtps",
            "ur:provenance/lfaxhdndihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvsetftimhnfndpswamismwmemsmsjnjkbakihtgooebnbgzmdyrlfxpmaslkdlrolsmsdtesjohsaywlchdwsrjpadytjsoxoerhuyurheesdponmhgwfwfpfltodliymoollfbbfeclfteebalbsaiocfdygofgglztlgdlzmzorsftbsfpndlejlpsynze",
            "ur:provenance/lfaxhdltlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmynsgdksnismybatasoztaywdqziavesfwtylhykghdsrlphegtrpvlgsatseptolmdsfcsjnnegaenlplnoysfwlcsvsytkncflrghvtckhhnybdknpfoekkcysrbkisvlnbaybsoxrfwdjkfrgwlo",
            "ur:provenance/lfaxhdmwntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndskswiotscxsaeyuetiglgoglmydmcwkpftflstjlcwdstshdsemuehjennuthgrfrskndiamqdsgpfistaswjpemrdntwkfwtbwkknrlrkfldyuohlkebdieenbkmsqdflaejnkedmstbzgebwrdlbchtlrsptqzasztsojzemplidtn",
            "ur:provenance/lfaxhdmtctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdihnrltbyalamhfebtcyfwfdasfwctwfimnentlefehdtsoeotfedygmiaeemdjeehiatoylgmjpceghdnwefefgtkrdfxjpkejywflbhhjendhndtvdtbghmdbwpyjlvwjscfdeleetadgwhylojydtskticsoydmwtjnylcekppklsldvwts",
            "ur:provenance/lfaxhdldbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlihieesvofmjelnfsdlsatyinlrlontosvajecettcychlrfnetwtssfswzmwgsmtfwaxbwwthkdewpdijodwfrhekehprdsemsbgtenlswsbqzcmlsrsmtyttsdkkimkwebwcytiurjlflvohhdkksvyon",
            "ur:provenance/lfaxhdmscsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdetthfgdmhkbfrmybszelsswfpgooesgfekoknmddtksjtjztezsfpldfdjtwdcnpahdhgrpfpwpmttbvwhkaycwbsrpynsockgdvabehfeozodkmtlgzcnegdzojyhfahyanbtinsayaeadzttnemtinnjkaossgavaolfyinetiasnimesamkp",
            "ur:provenance/lfaxhdlevtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdcygahgidpylffwaomhgupswdqdgmplbynskbesztgueslsrlwdqzsffyhefebwatbtlnlpmojziacwecdsjzluihpeckjsbdmwlrwmpsrytohegacyreretldsykrtzovwjtdptopdbshkzcsbwlswennltd",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdlkkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerloskkasplseinsbpdzmjnlksntiolfnzsecrfclpmryaaecsbftbgmuzmswbbykcknnmnwsjspkswiegrmnoxgwbybklfhdgdwzfphycxastaghjnaocnkktkstoeehaerhdloytbpmsppylgvyrpuopslnzmzmnehf",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmeinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdtdykehssyafzetmtwmdatbhtdnwsndcwfheedkkogdjtnscxkplfmdzefwkinehgynbajzldmwihrpeesnidatplswntpfetdedlfgkeswcacyiowdzcampdpsmykkrsrfbdwfwkfpzomhnsbkpdfgasdtmdcpfzimnedkylvl",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdkbtegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadaseegdlkeyrynehnpklooebawslfjpwphelfylteeozsskknjsdsknlpdnahwdhfknldjktpmtsfwfoebeimcmpdhyemneuebyihvysgmdrtjsrnsbkoonrowdpscsjolsimly",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdndihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvsetftimhnfndpswamismwmemsmsjnjkbakihtgooebnbgzmdyrlfxpmaslkdlrolsmsdtesjohsaywlchdwsrjpadytjsoxoerhuyurheesdponmhgwfwfpfltodliymoollfbbfeclfteebalbsaiocfdygofgglztlgdlzmzorsftbsfpndlekntbgygh",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdltlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmynsgdksnismybatasoztaywdqziavesfwtylhykghdsrlphegtrpvlgsatseptolmdsfcsjnnegaenlplnoysfwlcsvsytkncflrghvtckhhnybdknpfoekkcysrbkisvlnbaybsoxrfwdhnoxjlne",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmwntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndskswiotscxsaeyuetiglgoglmydmcwkpftflstjlcwdstshdsemuehjennuthgrfrskndiamqdsgpfistaswjpemrdntwkfwtbwkknrlrkfldyuohlkebdieenbkmsqdflaejnkedmstbzgebwrdlbchtlrsptqzasztsojzhnntdsta",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmtctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdihnrltbyalamhfebtcyfwfdasfwctwfimnentlefehdtsoeotfedygmiaeemdjeehiatoylgmjpceghdnwefefgtkrdfxjpkejywflbhhjendhndtvdtbghmdbwpyjlvwjscfdeleetadgwhylojydtskticsoydmwtjnylcekppktabziepl",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdldbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlihieesvofmjelnfsdlsatyinlrlontosvajecettcychlrfnetwtssfswzmwgsmtfwaxbwwthkdewpdijodwfrhekehprdsemsbgtenlswsbqzcmlsrsmtyttsdkkimkwebwcytiurjlflvohhcymdhfie",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmscsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdetthfgdmhkbfrmybszelsswfpgooesgfekoknmddtksjtjztezsfpldfdjtwdcnpahdhgrpfpwpmttbvwhkaycwbsrpynsockgdvabehfeozodkmtlgzcnegdzojyhfahyanbtinsayaeadzttnemtinnjkaossgavaolfyinetiasnfxrdgujz",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdlevtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdcygahgidpylffwaomhgupswdqdgmplbynskbesztgueslsrlwdqzsffyhefebwatbtlnlpmojziacwecdsjzluihpeckjsbdmwlrwmpsrytohegacyreretldsykrtzovwjtdptopdbshkzcsbwldrjelnfx",
        ]
//        runTest(resolution: .high, includeInfo: true, onlyPrint: true)
        runTest(resolution: .high, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
}
