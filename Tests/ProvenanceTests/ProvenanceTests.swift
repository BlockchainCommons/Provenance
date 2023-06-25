import XCTest
@testable import Provenance
import BCCrypto
import WolfBase
import WolfLorem

final class ProvenanceTests: XCTestCase {
    func test2ByteDates() {
        let baseDate = try! Date(iso8601: "2023-06-20T00:00:00Z")
        let baseDateSerialized = baseDate.serialize2Bytes()!
        XCTAssertEqual(baseDateSerialized.hex, "2ed4")
        let baseDate2 = Date.deserialize2Bytes(‡"2ed4")!
        XCTAssertEqual(baseDate, baseDate2)
    }

    func test4ByteDates() {
        let baseDate = try! Date(iso8601: "2023-06-20T12:34:56Z")
        let baseDateSerialized = baseDate.serialize4Bytes()!
        XCTAssertEqual(baseDateSerialized.hex, "2a41d470")
        let baseDate2 = Date.deserialize4Bytes(‡"2a41d470")!
        XCTAssertEqual(baseDate, baseDate2)
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
            #"ProvenanceMark(key: 7eb559bb, hash: d3e9c8a7, id: 7eb559bb, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa1, hash: 2149b301, id: 7eb559bb, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: 38cfe538, hash: aadd597b, id: 7eb559bb, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: bedba2c8, hash: 84e36f0b, id: 7eb559bb, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: a96ec2da, hash: 62eccb88, id: 7eb559bb, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: d0703671, hash: 2f2856d4, id: 7eb559bb, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 19cd0a02, hash: ff5893ed, id: 7eb559bb, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 55864d59, hash: 5e0541bb, id: 7eb559bb, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: c695d857, hash: 78579199, id: 7eb559bb, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7df, hash: ac530661, id: 7eb559bb, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock taxi iris frog taxi jugs days cyan drum foxy limp kiln vows very numb fizz join",
            "iron hill pose obey lung yank holy love play tuna ramp bulb maze tomb kick cost maze task dull zest",
            "exit task view exit kept rock work hang soap hawk jugs diet code door very code dark bias pool oboe",
            "ruin ugly oboe soap junk jazz fund limp belt quad even rock pool love drop free into exit foxy ruin",
            "part jolt saga twin aqua figs news menu figs item redo need mint bald meow twin down exam zaps safe",
            "taxi judo even jugs pose math work note wasp brew time yoga very cola body memo surf loud huts figs",
            "chef swan back also half math visa holy memo draw fair idea heat bulb navy holy zaps ramp vibe zero",
            "gyro lion gift hawk zinc judo exit pose eyes scar idea inky body math time luck love jade body curl",
            "skew mild trip hang puff solo redo guru tiny dice gems obey wolf beta love king roof solo curl toil",
            "time gray yell user need wasp jade heat race very legs gyro huts keep maze love zinc jazz glow tent",
        ]
        let expectedURs = [
            "ur:provenance/lfaegdkbrehkrktiisfgtijsdscndmfylpknvsjkoyvtlb",
            "ur:provenance/lfaegdinhlpeoylgykhylepytarpbbmetbkkctaxtomywy",
            "ur:provenance/lfaegdettkvwetktrkwkhgsphkjsdtcedrvycerpbabapf",
            "ur:provenance/lfaegdrnuyoespjkjzfdlpbtqdenrkplledpfeykesveps",
            "ur:provenance/lfaegdptjtsatnaafsnsmufsimrondmtbdmwtnrhenhtte",
            "ur:provenance/lfaegdtijoenjspemhwknewpbwteyavycabymohylosedl",
            "ur:provenance/lfaegdcfsnbkaohfmhvahymodwfriahtbbnyhyisrlfywl",
            "ur:provenance/lfaegdgolngthkzcjoetpeessriaiybymhtelkcsimpaeo",
            "ur:provenance/lfaegdswmdtphgpfsorogutydegsoywfbalekgdmsplyst",
            "ur:provenance/lfaegdtegyylurndwpjehtrevylsgohskpmelejljnwssr",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaegdkbrehkrktiisfgtijsdscndmfylpknvsrevsaycx",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdinhlpeoylgykhylepytarpbbmetbkkctskltiopa",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdettkvwetktrkwkhgsphkjsdtcedrvycejoflvaws",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdrnuyoespjkjzfdlpbtqdenrkplledpfeeojobnwf",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdptjtsatnaafsnsmufsimrondmtbdmwtnlblbprlk",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdtijoenjspemhwknewpbwteyavycabymomksedtjo",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdcfsnbkaohfmhvahymodwfriahtbbnyhyplzepsrp",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdgolngthkzcjoetpeessriaiybymhtelkuecnhkjz",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdswmdtphgpfsorogutydegsoywfbalekgvslyinmk",
            "https://example.com/validate?provenance=tngdgmgwhflfaegdtegyylurndwpjehtrevylsgohskpmeleptdkatns",
        ]
        runTest(resolution: .low, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testLowWithInfo() throws {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bb, hash: 6c3d3883, id: 7eb559bb, seq: 0, date: 2023-06-20T12:00:00Z, info: "Consectetur Molestiae")"#,
            #"ProvenanceMark(key: 695dafa1, hash: 4eb0b69b, id: 7eb559bb, seq: 1, date: 2023-06-21T12:00:00Z, info: "Earum Provident Debitis Dicta Numquam Quis Nisi")"#,
            #"ProvenanceMark(key: 38cfe538, hash: 6dfaa4e3, id: 7eb559bb, seq: 2, date: 2023-06-22T12:00:00Z, info: "Et Modi Corporis Molestias Consequuntur Esse")"#,
            #"ProvenanceMark(key: bedba2c8, hash: 430239f2, id: 7eb559bb, seq: 3, date: 2023-06-23T12:00:00Z, info: "Voluptatum Ut Est Quos")"#,
            #"ProvenanceMark(key: a96ec2da, hash: c2212ae0, id: 7eb559bb, seq: 4, date: 2023-06-24T12:00:00Z, info: "Enim Repellendus Dolor Et Et")"#,
            #"ProvenanceMark(key: d0703671, hash: f83eb447, id: 7eb559bb, seq: 5, date: 2023-06-25T12:00:00Z, info: "Dignissimos Quia Reiciendis Delectus")"#,
            #"ProvenanceMark(key: 19cd0a02, hash: 2af2c275, id: 7eb559bb, seq: 6, date: 2023-06-26T12:00:00Z, info: "Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: 55864d59, hash: d5a6a0df, id: 7eb559bb, seq: 7, date: 2023-06-27T12:00:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: c695d857, hash: 22bd2deb, id: 7eb559bb, seq: 8, date: 2023-06-28T12:00:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: d351f7df, hash: df537d72, id: 7eb559bb, seq: 9, date: 2023-06-29T12:00:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock taxi iris frog taxi taco whiz time back foxy limp kiln vows gems obey aqua user lung race list cats silk purr whiz away gear down what fuel buzz loud exit wave puma slot glow tuna keys gyro",
            "iron hill pose obey lung yank holy love sets crux quad main maze tomb kick cost item nail tomb holy yell hill high list crux silk zinc solo runs exam owls toys curl flap ramp quad skew warm brag puma diet saga plus vial webs away drop keno gyro hope barn glow hill race gift miss yoga very judo open webs oboe epic monk yell wand away frog dull",
            "exit task view exit kept rock work hang bias knob luck puma code door very code holy very arch flew puff undo high gems onyx brag cats whiz what fact vial warm wave cyan roof ramp code work task beta yurt taxi figs item obey loud main yawn join half jump memo taxi luau yoga vial cost horn jazz vibe kick able edge diet dice waxy",
            "ruin ugly oboe soap junk jazz fund limp song grim horn flew pool love drop free zinc mild into item zoom king part wand acid quiz jolt fair gift wolf race cyan part oboe horn taco edge atom trip game help waxy puff",
            "part jolt saga twin aqua figs news menu next owls hawk wolf mint bald meow twin barn chef acid help hard holy brag peck tomb note leaf song next user what nail data legs zoom zoom cash foxy wave oval zaps idle redo mint mint visa kite soap aunt inch",
            "taxi judo even jugs pose math work note fair arch each jade very cola body memo wasp hope horn many axis roof horn brag ruin soap dull iron luck curl void undo oboe taco belt fair flew wand barn even time epic work gush tent wand wall free lazy tent blue cook guru rock city ruby hard tied",
            "chef swan back also half math visa holy fuel lion item zero heat bulb navy holy tent yell toil tiny rust gems film road axis jump luck inch cats maze yawn knob epic hope need slot inky swan paid jump kiwi body fern",
            "gyro lion gift hawk zinc judo exit pose purr horn leaf also body math time luck whiz zero fair main hard waxy yawn cusp tiny edge kick roof safe item arch task fizz guru wolf owls game part part lazy monk luck whiz back user when gush epic zone main duty high figs stub cats holy help jugs king quad news vial bias",
            "skew mild trip hang puff solo redo guru main saga what time wolf beta love king need meow chef away cats duty city dice mild idea days down edge yawn oboe good real fund brew urge stub also heat view what jugs draw tuna inch stub very tiny figs pool acid peck bias axis cusp miss toys race",
            "time gray yell user need wasp jade heat skew very yoga frog huts keep maze love cusp whiz purr half rock navy sets swan liar taxi vast fish paid very vibe stub lamb dark also quad ruby vows hang keys warm gems note puma safe jade silk buzz swan fund skew frog plus poem loud echo puff duty cola",
        ]
        let expectedURs = [
            "ur:provenance/lfaehddskbrehkrktiisfgtitowztebkfylpknvsgsoyaaurlgreltcsskprwzaygrdnwtflbzldetwepastsrfmjlbe",
            "ur:provenance/lfaehdfpinhlpeoylgykhylesscxqdmnmetbkkctimnltbhyylhlhhltcxskzcsorsemostsclfprpqdswwmbgpadtsapsvlwsaydpkogohebngwhlregtmsyavyjoonwsoeecmkylsbdrderf",
            "ur:provenance/lfaehdfmettkvwetktrkwkhgbskblkpacedrvycehyvyahfwpfuohhgsoxbgcswzwtftvlwmwecnrfrpcewktkbayttifsimoyldmnynjnhfjpmotiluyavlcthnjzvekkaeaxdtluae",
            "ur:provenance/lfaehddirnuyoespjkjzfdlpsggmhnfwplledpfezcmdioimzmkgptwdadqzjtfrgtwfrecnptoehntoeeamtpvldadmzm",
            "ur:provenance/lfaehddmptjtsatnaafsnsmuntoshkwfmtbdmwtnbncfadhphdhybgpktbnelfsgnturwtnldalszmzmchfyweolzsieromtmtvafspafdpe",
            "ur:provenance/lfaehdentijoenjspemhwknefrahehjevycabymowphehnmyasrfhnbgrnspdlinlkclvduooetobtfrfwwdbnenteecwkghttwdwlfelyttbeckgurklkvomngw",
            "ur:provenance/lfaehddicfsnbkaohfmhvahyfllnimzohtbbnyhyttyltltyrtgsfmrdasjplkihcsmeynkbechendstiysnpduyaxttjk",
            "ur:provenance/lfaehdfrgolngthkzcjoetpeprhnlfaobymhtelkwzzofrmnhdwyyncptyeekkrfseimahtkfzguwfosgeptptlymklkwzbkurwngheczemndyhhfssbcshyhpjskgjtmkjsyn",
            "ur:provenance/lfaehdenswmdtphgpfsorogumnsawttewfbalekgndmwcfaycsdycydemdiadsdneeynoegdrlfdbwuesbaohtvwwtjsdwtaihsbvytyfspladpkbsasqzspadde",
            "ur:provenance/lfaehdemtegyylurndwpjehtswvyyafghskpmelecpwzprhfrknysssnlrtivtfhpdvyvesblbdkaoqdryvshgkswmgsnepasejeskbzsnfdswfgpspmldnbbtmuvw",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaehddskbrehkrktiisfgtitowztebkfylpknvsgsoyaaurlgreltcsskprwzaygrdnwtflbzldetwepastmecyflta",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfpinhlpeoylgykhylesscxqdmnmetbkkctimnltbhyylhlhhltcxskzcsorsemostsclfprpqdswwmbgpadtsapsvlwsaydpkogohebngwhlregtmsyavyjoonwsoeecmkylgegmtoox",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfmettkvwetktrkwkhgbskblkpacedrvycehyvyahfwpfuohhgsoxbgcswzwtftvlwmwecnrfrpcewktkbayttifsimoyldmnynjnhfjpmotiluyavlcthnjzvekkaerpstsnhp",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddirnuyoespjkjzfdlpsggmhnfwplledpfezcmdioimzmkgptwdadqzjtfrgtwfrecnptoehntoeeamtpadtkjosr",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddmptjtsatnaafsnsmuntoshkwfmtbdmwtnbncfadhphdhybgpktbnelfsgnturwtnldalszmzmchfyweolzsieromtmtvaknverosr",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdentijoenjspemhwknefrahehjevycabymowphehnmyasrfhnbgrnspdlinlkclvduooetobtfrfwwdbnenteecwkghttwdwlfelyttbeckgurktafdcelb",
            "https://example.com/validate?provenance=tngdgmgwhflfaehddicfsnbkaohfmhvahyfllnimzohtbbnyhyttyltltyrtgsfmrdasjplkihcsmeynkbechendstiysnpdeswlmygw",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdfrgolngthkzcjoetpeprhnlfaobymhtelkwzzofrmnhdwyyncptyeekkrfseimahtkfzguwfosgeptptlymklkwzbkurwngheczemndyhhfssbcshyhpjskgsbtemeya",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdenswmdtphgpfsorogumnsawttewfbalekgndmwcfaycsdycydemdiadsdneeynoegdrlfdbwuesbaohtvwwtjsdwtaihsbvytyfspladpkbsasvyidmucs",
            "https://example.com/validate?provenance=tngdgmgwhflfaehdemtegyylurndwpjehtswvyyafghskpmelecpwzprhfrknysssnlrtivtfhpdvyvesblbdkaoqdryvshgkswmgsnepasejeskbzsnfdswfgpspmldlnlyasuy",
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
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb5094, hash: abdd11c3aaa053163abbc8a30a57682d, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2da, hash: 9e430da9cae4285526db0caceb989a25, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: d070367119cd0a0255864d59c695d857, hash: aecd00d73c4a8bb2c8e0810d225d1441, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69, hash: fd37601b5ef044e0ed87312808367cf3, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4dff86f78ab260ce12c, hash: 06c319afbd179f1e4631ad4d3a9066fe, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c2, hash: 5259c082b096bff135e5e5e55972d8e0, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 24539e315edbdc34b0dd5361956328ca, hash: 7d9fffced0faf0945fc715d6438bd44d, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0e, hash: 74962baa91c8d1add14ae84383e962a4, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: e1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 64128a4c9043cea3081ca9e7096da2ba, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2, hash: fb9659d45754993745e8190f6cf2c80a, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow zest ruby main zest gyro jazz hard sets even kiln also visa road rich brag leaf leaf math puma eyes legs atom bald task plus bulb king road monk holy list plus flew mild navy jolt kiln zone wall ramp paid frog mild part king tiny toil liar",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi yurt silk hill horn cost foxy cats vows silk bulb omit arch part rust ugly many guru figs atom inky paid dice note math fuel game horn toys logo what visa crux lamb huts liar zoom idea gems yank note undo able beta mild liar hill purr",
            "taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang swan atom view play zero king surf gray lamb road song acid yawn hope kick diet quad unit aunt deli puma limp void diet numb soap cash horn logo pose cusp inch jolt claw drop foxy lazy aqua zaps plus vial claw when yawn lamb deli zoom yell",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron vial jazz keno twin draw jury limp into cola cats lung navy days easy fair open king note ruby cola warm city keno lion pool drop tied oboe cook quad zoom flew judo door yoga poem navy quad poem foxy vast king road runs duty kiwi toil waxy",
            "runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw legs redo tomb love hang gray data keno hang numb flux jury hope king girl help able real plus peck whiz belt echo zinc zone dark axis saga puff poem onyx nail skew idea inch gray main saga lamb able chef puma acid also navy guru omit judo",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga ruin soap aunt also unit bald keys flew twin zest half echo jade math loud void aqua jugs cook vial zone note task hawk unit knob zone cyan yoga yoga ruin omit time lazy toil nail logo cook hang real blue figs ugly drum good roof loud tiny",
            "dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song limp zinc memo game axis love note nail list zest horn eyes item keys apex glow when oboe gear puma heat curl city quiz monk iris what toil rich half also guru drop loud jazz onyx jugs scar vows dark yell loud gush atom free noon inky high",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta warm dice deli tent visa dull lava door join brew view claw tent tiny urge inky next yurt vows meow apex cash cook warm skew keep list silk leaf safe yoga urge toys iris buzz idea webs play song brag work liar idea lamb blue edge rust jugs",
            "very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic trip curl aunt epic note tiny zero yawn buzz sets judo wasp blue iced free cook echo webs exit keno gift meow zest zone luck jolt very each what hope barn duty taxi twin what redo days yoga gear lion main high fuel trip high toil legs drop",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr door saga kept dark scar kite oval lion navy jump view oval down hope iced paid jade belt fish curl rock iced vial grim maze girl monk cook pool gush vows king bias rich miss idle jury flap next blue kick paid able zest foxy guru zinc gift",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdfnkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglflfmhpaeslsambdtkpsbbkgrdmkhyltpsfwmdnyjtknzewlrppdfgmdptqzcapywd",
            "ur:provenance/lfaohdfninhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuymygufsamiypddenemhflgehntslowtvacxlbhslrzmiagsykneuoaebahtgtcnuo",
            "ur:provenance/lfaohdfntijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtqdutatdipalpvddtnbspchhnlopecpihjtcwdpfylyaazspsvlcwwnynpfwylynl",
            "ur:provenance/lfaohdfntegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronkgnerycawmcykolnpldptdoeckqdzmfwjodryapmnyqdpmfyvtkgrdrszmqzpyla",
            "ur:provenance/lfaohdfnrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpaerlpspkwzbteozczedkassapfpmoxnlswiaihgymnsalbaecfpaadaogonyutck",
            "ur:provenance/lfaohdfnihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdaajsckvlzenetkhkutkbzecnyayarnottelytlnllockhgrlbefsuydmnekpylrd",
            "ur:provenance/lfaohdfndkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwwnoegrpahtclcyqzmkiswttlrhhfaogudpldjzoxjssrvsdkylldghamlehgcsey",
            "ur:provenance/lfaohdfnlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyntytvsmwaxchckwmswkpltsklfseyauetsisbziawspysgbgwklrialburzcrnct",
            "ur:provenance/lfaohdfnvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckeowsetkogtmwztzelkjtvyehwthebndytitnwtrodsyagrlnmnhhfltpmucezcfx",
            "ur:provenance/lfaohdfnntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdjebtfhclrkidvlgmmeglmkckplghvskgbsrhmsiejyfpntbekkpdaeztlunylscn",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglflfmhpaeslsambdtkpsbbkgrdmkhyltpsfwmdnyjtknzewlrppdfgmdptguaesnbt",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfninhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuymygufsamiypddenemhflgehntslowtvacxlbhslrzmiagsykneuoaebarygdfefr",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfntijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtqdutatdipalpvddtnbspchhnlopecpihjtcwdpfylyaazspsvlcwwnynhgwfvdkb",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfntegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronkgnerycawmcykolnpldptdoeckqdzmfwjodryapmnyqdpmfyvtkgrdrscsptsnio",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpaerlpspkwzbteozczedkassapfpmoxnlswiaihgymnsalbaecfpaadaoprltrkyt",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdaajsckvlzenetkhkutkbzecnyayarnottelytlnllockhgrlbefsuydmksismehl",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfndkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwwnoegrpahtclcyqzmkiswttlrhhfaogudpldjzoxjssrvsdkylldghamjngekbtl",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnlnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyntytvsmwaxchckwmswkpltsklfseyauetsisbziawspysgbgwklrialbetvttpya",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckeowsetkogtmwztzelkjtvyehwthebndytitnwtrodsyagrlnmnhhfltpjyadndox",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdfnntnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdjebtfhclrkidvlgmmeglmkckplghvskgbsrhmsiejyfpntbekkpdaeztjzltvwss",
        ]
        runTest(resolution: .quartile, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
//        runTest(resolution: .quartile, includeInfo: false, onlyPrint: true)
    }
    
    func testQuartileWithInfo() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb5094, hash: d89843c80116a01afa377c4511f30fee, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 0, date: 2023-06-20T12:00:00Z, info: "Explicabo Occaecati")"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2da, hash: 05c0c97695501bf90d5aa221660ba421, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 1, date: 2023-06-21T12:00:00Z, info: "Nisi Quis Odio")"#,
            #"ProvenanceMark(key: d070367119cd0a0255864d59c695d857, hash: 35ea13ca2fd1836a9aeda3801def5624, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 2, date: 2023-06-22T12:00:00Z, info: "Corporis Molestias Consequuntur")"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69, hash: 2da6de01990d5bcc2ca440ecad44990d, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 3, date: 2023-06-23T12:00:00Z, info: "Blanditiis Voluptatum Ut Est Quos Explicabo")"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4dff86f78ab260ce12c, hash: c12008869bef6358b9d276425874bb99, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 4, date: 2023-06-24T12:00:00Z, info: "Repellendus Dolor Et")"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c2, hash: b5fe760ecb8451c9759fafbbd640a2c5, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 5, date: 2023-06-25T12:00:00Z, info: "Consequatur Dignissimos")"#,
            #"ProvenanceMark(key: 24539e315edbdc34b0dd5361956328ca, hash: 1742c81be71d370c0f7c656679e4c48a, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 6, date: 2023-06-26T12:00:00Z, info: "Quia Ut Praesentium Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0e, hash: 0182bb75e98cd50bf7ccf5f013070890, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 7, date: 2023-06-27T12:00:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: e1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 7ff06100edfa988f62bfacea87d05029, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 8, date: 2023-06-28T12:00:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2, hash: 8c5e93fd73d7cbfbb065918cba337b60, id: 7eb559bbbf6cce2632cf9f194aeb5094, seq: 9, date: 2023-06-29T12:00:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow zest ruby main zest gyro jazz hard sets even kiln also visa road rich brag leaf when toil vial easy dice puff yoga scar jazz monk task high legs zaps vast jowl flew mild navy jolt kiln zone wall ramp paid frog mild part mild game scar jolt very silk lamb poem puma work horn undo king math veto chef oval film gyro yawn kite user luck calm",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi yurt silk hill horn cost foxy cats vows silk bulb omit arch part rust ugly bulb taxi yurt tuna eyes code claw echo rock skew vibe wave heat claw taco veto crux lamb huts liar zoom idea gems yank note undo able beta calm webs barn meow each twin taxi runs fact rock king navy brag flew curl paid hang code heat",
            "taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang swan atom view play zero king surf gray lamb road song acid yawn hope kick diet dice zaps bulb fact oboe cook webs when whiz silk epic wave real cola horn able jolt claw drop foxy lazy aqua zaps plus vial claw when yawn news whiz iron poem navy mild aunt webs cash menu hawk vows brew main wolf many taco jazz purr lamb miss ramp task purr aunt race frog liar toys lion need main gala oboe horn cash work",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron vial jazz keno twin draw jury limp into cola cats lung navy days easy fair open play beta apex aunt draw void iron peck jowl beta omit inky rock safe city roof judo door yoga poem navy quad poem foxy vast king road runs miss silk away loud zoom hawk deli memo iced puma figs vial whiz bias wand peck flux need guru game heat crux flux love plus foxy jade pool back kiwi fund task hill glow ruby cash aqua keys away flap news surf undo cusp gems puma meow edge idea",
            "runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw legs redo tomb love hang gray data keno hang numb flux jury hope king girl help slot gush ruby legs tiny yank task rock acid slot tied swan tied gala kick zone skew idea inch gray main saga lamb able chef puma acid also veto when ugly kept quad aunt waxy idea easy news ruby vial kept tent part fuel gala exam flux play fair fish real jazz toys",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga ruin soap aunt also unit bald keys flew twin zest half echo jade math loud void vial tomb paid jowl limp lung curl huts next aqua quiz kiwi kept song sets lion time lazy toil nail logo cook hang real blue figs ugly drum when vows knob waxy fact into foxy kiwi tiny calm jury news junk very real unit kiwi tuna gray able legs drop visa main waxy jowl swan quiz",
            "dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song limp zinc memo game axis love note nail list zest horn eyes item keys apex glow need lamb kite idle join skew unit draw soap time lava inch legs eyes brag meow drop loud jazz onyx jugs scar vows dark yell loud gush atom high user wand king keys heat fair code duty oboe swan ruin horn gift holy eyes body judo hill math lava rock away inky buzz jazz huts ramp legs vibe drop calm soap meow even exam vast hang jump kick data rock game numb zoom girl away lava",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta warm dice deli tent visa dull lava door join brew view claw tent tiny urge inky vows wave keys gear king guru city gift vast wolf navy keno brag dull memo wand toys iris buzz idea webs play song brag work liar idea lamb veto scar keys help time huts jolt lamb quiz taco kite easy skew girl into exit need oboe idle webs user epic zaps curl bald zone epic toys crux back drum toil rich scar lion visa cyan vows holy jazz chef easy surf drum belt girl code",
            "very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic trip curl aunt epic note tiny zero yawn buzz sets judo wasp blue iced free cook dice belt time fact duty drop peck tied visa swan vibe fern knob veto zone omit taxi twin what redo days yoga gear lion main high fuel trip ruby city dark figs holy toys what taxi numb taxi free half buzz webs gush slot yurt dark cook pose vial toys peck when zaps silk cyan inky lion wasp free iced math lazy vows fact undo body flux paid tied puma",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr door saga kept dark scar kite oval lion navy jump view oval down hope iced paid code silk yank away note very puma noon idle scar blue next keys mild help body bias rich miss idle jury flap next blue kick paid able zest tuna jump puff real also owls vibe bias help urge warm frog navy tent ramp roof love kept item aunt rich roof webs barn fern exam belt cyan silk owls navy time down wasp loud king wall surf rich visa logo what away",
        ]
        let expectedURs = [
            "ur:provenance/lfaohdgdkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfwntlvleydepfyasrjzmktkhhlszsvtjlfwmdnyjtknzewlrppdfgmdptmdgesrjtvysklbpmpawkhnuokgmhvocfolfmgoynkgcxksvy",
            "ur:provenance/lfaohdgrinhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuybbtiyttaescecweorkswvewehtcwtovocxlbhslrzmiagsykneuoaebacmwsbnmwehtntirsftrkkgnybgfwclleaxwtsk",
            "ur:provenance/lfaohdhltijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtdezsbbftoeckwswnwzskecwerlcahnaejtcwdpfylyaazspsvlcwwnynnswzinpmnymdatwschmuhkvsbwmnwfmytojzprlbmsrptkpratrefglrtslnndmngasajptyds",
            "ur:provenance/lfaohdintegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronpybaaxatdwvdinpkjlbaotiyrksecyrfjodryapmnyqdpmfyvtkgrdrsmsskayldzmhkdimoidpafsvlwzbswdpkfxndgugehtcxfxlepsfyjeplbkkifdtkhlgwrychaaksayfpnssfuocpgswkfzinwn",
            "ur:provenance/lfaohdgyrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpstghrylstyyktkrkadsttdsntdgakkzeswiaihgymnsalbaecfpaadaovownuyktqdatwyiaeynsryvlktttptflgaemfxpyfrtlaybzta",
            "ur:provenance/lfaohdghihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdvltbpdjllplgclhsntaaqzkiktsgsslntelytlnllockhgrlbefsuydmwnvskbwyftiofykitycmjynsjkvyrlutkitagyaelsdpvamnieghcpjk",
            "ur:provenance/lfaohdisdkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwndlbkeiejnswutdwsptelaihlsesbgmwdpldjzoxjssrvsdkylldghamhhurwdkgkshtfrcedyoesnrnhngthyesbyjohlmhlarkayiybzjzhsrplsvedpcmspmwenemvthgjpkkdarkgenbdryatkpd",
            "ur:provenance/lfaohdiolnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyvsweksgrkggucygtvtwfnykobgdlmowdtsisbziawspysgbgwklrialbvosrkshptehsjtlbqztokeeyswglioetndoeiewsureczsclbdzeectscxbkdmtlrhsrlnvacnvshyjzcfeysfrdfesttl",
            "ur:provenance/lfaohdidvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckdebtteftdydppktdvasnvefnkbvozeottitnwtrodsyagrlnmnhhfltprycydkfshytswttinbtifehfbzwsghstytdkckpevltspkwnzsskcniylnwpfeidmhlyvsftuobyeelpsrzo",
            "ur:provenance/lfaohdiantnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdceskykaynevypanniesrbentksmdhpbybsrhmsiejyfpntbekkpdaezttajppfrlaoosvebshpuewmfgnyttrprflektimatrhrfwsbnfnembtcnskosnytednwpldkgwlsfrhahinqdbk",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgdkbrehkrkrsjztodseytknecfgewmgdmwztrymnztgojzhdssenknaovardrhbglfwntlvleydepfyasrjzmktkhhlszsvtjlfwmdnyjtknzewlrppdfgmdptmdgesrjtvysklbpmpawkhnuokgmhvocfolfmgoynceeylkey",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgrinhlpeoyettkvwetrnuyoespptjtsatntiytskhlhnctfycsvsskbbotahptrtuybbtiyttaescecweorkswvewehtcwtovocxlbhslrzmiagsykneuoaebacmwsbnmwehtntirsftrkkgnybgfwclollfoeuy",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdhltijoenjscfsnbkaogolngthkswmdtphgsnamvwpyzokgsfgylbrdsgadynhekkdtdezsbbftoeckwswnwzskecwerlcahnaejtcwdpfylyaazspsvlcwwnynnswzinpmnymdatwschmuhkvsbwmnwfmytojzprlbmsrptkpratrefglrtslnndmngaghjpcava",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdintegyylurwkcfaemyincabdwmvevdctinvljzkotndwjylpiocacslgnydseyfronpybaaxatdwvdinpkjlbaotiyrksecyrfjodryapmnyqdpmfyvtkgrdrsmsskayldzmhkdimoidpafsvlwzbswdpkfxndgugehtcxfxlepsfyjeplbkkifdtkhlgwrychaaksayfpnssfuocpgsstmymknb",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdgyrstdmezckbjtqzuryajlkspydsbnvydwlsrotblehggydakohgnbfxjyhekgglhpstghrylstyyktkrkadsttdsntdgakkzeswiaihgymnsalbaecfpaadaovownuyktqdatwyiaeynsryvlktttptflgaemfxpyfrsgrelrfx",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdghihbkjoaagdadcadlwdlendsadknyynsarnspataoutbdksfwtnzthfeojemhldvdvltbpdjllplgclhsntaaqzkiktsgsslntelytlnllockhgrlbefsuydmwnvskbwyftiofykitycmjynsjkvyrlutkitagyaelsdpvamngahtjecx",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdisdkgunnehhyuyuoeepfutguhsmdiadesglpzcmogeaslenenlltzthnesimksaxgwndlbkeiejnswutdwsptelaihlsesbgmwdpldjzoxjssrvsdkylldghamhhurwdkgkshtfrcedyoesnrnhngthyesbyjohlmhlarkayiybzjzhsrplsvedpcmspmwenemvthgjpkkdarkgenbvabbkgsk",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdiolnnsesbseepaylvttbcsrdjefhnlnybawmdedittvadlladrjnbwvwcwtttyueiyvsweksgrkggucygtvtwfnykobgdlmowdtsisbziawspysgbgwklrialbvosrkshptehsjtlbqztokeeyswglioetndoeiewsureczsclbdzeectscxbkdmtlrhsrlnvacnvshyjzcfeysfhtlnfhhs",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdidvymonsehvtyaspskvtrlgsrkqzzcrdectpclatecnetyzoynbzssjowpbeidfeckdebtteftdydppktdvasnvefnkbvozeottitnwtrodsyagrlnmnhhfltprycydkfshytswttinbtifehfbzwsghstytdkckpevltspkwnzsskcniylnwpfeidmhlyvsftuobywntoosdy",
            "https://example.com/validate?provenance=tngdgmgwhflfaohdiantnlhkiacedpldmecmcylehpwpchweprdrsaktdksrkeollnnyjpvwoldnheidpdceskykaynevypanniesrbentksmdhpbybsrhmsiejyfpntbekkpdaezttajppfrlaoosvebshpuewmfgnyttrprflektimatrhrfwsbnfnembtcnskosnytednwpldkgwlsfrhascyvlhf",
        ]
        runTest(resolution: .quartile, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testHigh() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, hash: 5db030b5f0e9f892498e27d9c5a67e70560f50ca53c815d942dade41a139f3f5, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 0, date: 2023-06-20T12:00:00Z)"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2dad070367119cd0a0255864d59c695d857, hash: 2f71096381202bc581027c089ad71077e223eac969272e7f5e568fc7c7f47d03, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 1, date: 2023-06-21T12:00:00Z)"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69bfd291fd7e6eb4dff86f78ab260ce12c, hash: 24b29fd8e54a7a14055b356735372dacd755725f0ffc86bf0f7ff41886953d4e, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 2, date: 2023-06-22T12:00:00Z)"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c224539e315edbdc34b0dd5361956328ca, hash: 9c19212ee73d394696b351c52f2cd43811454a65008978024af52c9ad9b92ec4, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 3, date: 2023-06-23T12:00:00Z)"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0ee1929c31e0f8c8c5e0b74cbbb4fdba35, hash: 57c608beaf29fc3546a31d2f56ccaaa58179c74c26c0bd505b72063e7cd7f6c9, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 4, date: 2023-06-24T12:00:00Z)"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2cc519d3df4f241dc98a285963646294d, hash: 805fb808bb88f397296653d1930322a2ec3f450a1b5e7af129f7e6712aa5e006, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 5, date: 2023-06-25T12:00:00Z)"#,
            #"ProvenanceMark(key: 1f1df300ca1ba7e6e192dfdc4debe4d643026c948ef84fc50fd81ef55a3fe95a, hash: ea6085ca4dff79fc0568982a6a03bd11fa95e11907aa43cce651a0effa3195c1, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 6, date: 2023-06-26T12:00:00Z)"#,
            #"ProvenanceMark(key: 10cf8fb2ae8719ead09a153aa193e05d7abf97501bac041942a1a502e7f5eeba, hash: 17721e945aebbb9a06354ba85613cb92eef1484c0eb745afe37488b265bea07d, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 7, date: 2023-06-27T12:00:00Z)"#,
            #"ProvenanceMark(key: 186d0597dfd56a71abf4e86004c822600e4c72f6e3cf9d2a0f0c03aff38bd48d, hash: d420586738d4b66f52b4ec0f805719fa63fd7bab6e3b689318b7e3e6552c8b5d, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 8, date: 2023-06-28T12:00:00Z)"#,
            #"ProvenanceMark(key: e079e69f4ad9ae5fd8ce003998741df6598920846424db654b41f341d50fc56b, hash: 67a421d191e6794434d74a878e18c9246e5bd7ecc1211fd1cbad76b52424e3a0, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 9, date: 2023-06-29T12:00:00Z)"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow figs void very stub poem gush undo zaps purr kiln flew keep note holy dull wave free holy keep jury need logo echo iron barn beta foxy fair vibe gems need flux crux jowl real idea also purr huts calm zaps next work gush limp note real owls heat ruby zone soap blue stub lamb huts tuna half many aqua data warm figs mint frog keys vows peck belt jolt roof belt warm calm vial holy jury navy wand stub main webs jugs peck skew safe heat drum jowl game quad door fizz saga able numb",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang love road gush poem curl peck even math lazy yawn nail kiln task noon soap drum ramp jolt buzz warm axis exit ruin ruin plus math pose many saga roof mild good when fund crux whiz stub data song idle jugs atom saga grim yank work taxi urge code blue drum wand luck hill hope hang game menu road fuel zone tuna cook void yawn beta jazz loud meow rust numb ruby wave girl gala luau gush fund task when",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw undo help bias hawk blue noon tied able arch undo iced hope help undo idle skew wall gyro echo deli huts barn exit omit noon task twin cola need silk acid axis need omit iced void rust gush puma iced good flew legs horn what purr song kiln heat barn heat tomb undo plus jowl zest taxi ugly help rust easy join yurt jump loud junk trip mint surf half rich void vial foxy gala bias yell many claw skew",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song view toys axis king cats judo legs fund zero void keep aunt visa yoga puma flew fizz inch solo holy fern silk king zone surf draw fair exit rich puff yell vows what free tuna undo judo pool owls vows luck bulb half main cash saga guru city vast ruby lazy half lazy ruin luck need vibe puma trip wasp user cook wolf yawn miss diet eyes judo huts poem solo song veto rock vibe drum beta edge junk cats",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic frog omit vial real love wolf toil toys when wave monk cats taco kiwi aunt saga time jump jump dull road lion echo noon roof eyes toys arch when zaps owls grim twin keno safe love hang tomb keno kite cook back wasp menu keno kiln love brew when jade cats drop silk ruby acid jolt hang cost hill main film inky item solo mild surf cats join note wasp brew runs wall film zone whiz gear aqua tent yawn",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr surf gray next figs work whiz flap undo monk oboe limp mint even frog diet gift help kick wolf saga door navy gush door zone zest brew fizz gush code hard menu dice jump huts legs when girl logo free zero rich vial user code cyan meow need poem swan aunt task draw wasp miss skew calm zinc huts gift puff hope gray wand help love diet gala crux bias math atom also cola kiln crux luau code junk hawk runs kiln deli atom quad jowl navy away gyro apex plus cost claw data axis vibe",
            "cost cola wolf able song claw owls visa very memo user undo gift warm vibe tomb flux also jazz meow main yoga glow silk bias trip cook yank heat fish wall heat soap jolt void legs toil bias gala saga bald very leaf crux jazz fish heat horn list yoga pool iced barn kite cyan inky idle vibe work race eyes note toys deli saga good yell taxi zone zone slot duty roof warm slot diet zoom fact holy note logo frog knob menu rich saga mint item time nail maze also jowl hill navy roof idea taco yell grim jump rich king iced rust part fern view omit arch dull eyes",
            "blue task many purr pool list chef wand taxi navy buzz fact obey menu vast hill kiln runs miss good claw plus aqua chef flew obey open also void yank waxy road plus undo cook city roof glow silk tomb hope vows luck flux kick zone edge guru numb redo claw aunt lava rich apex soap scar jowl real help hard gift belt jowl oboe belt race down film tiny inky join next drum kick fish lava pose puma hang twin song into door ruin flap toys zoom need kiwi frog waxy when atom when math flew apex brew what hawk lung tuna math claw film cola flew toil zone zoom yell",
            "cats join arch miss user toil item jugs play work vows horn aqua soap cusp horn beta gems jump yawn vial task next door bias barn apex pose wolf luau tiny lung rich wolf peck free poem king jade lazy flap cola days zaps monk surf junk tiny open inky twin holy kick film omit item lazy dull owls help into body fair dice back bulb cook jowl kiln very easy jump twin edge need loud obey flux claw real miss ruby monk knob game cyan cyan rich logo down owls menu door film luau flew hard hang ramp flap wasp echo wasp keys tuna duty tuna dark memo lamb cook warm",
            "vast kick visa note game tuna pool hope trip taco able eyes monk jury cola yawn hawk loud crux liar idle dark ugly inch gear flap wolf flap toil bias silk jade vibe quiz ramp calm idle wand gala loud zero omit iced figs task silk waxy gyro yurt skew vast list kite kite jury cyan data toil luau obey gyro unit redo tied brag rock view noon data able idle dark onyx love yell able lava diet acid kiln tied help ugly ramp warm aunt game bulb numb note user warm duty tomb time axis belt lion limp memo jazz skew dark task bias echo view king what jade judo wall",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdjzkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerloshtryzespbesblbhstahfmyaadawmfsmtfgksvspkbtjtrfbtwmcmvlhyjynywdsbmnwsjspkswsehtdmjlgeqddrrtdlehah",
            "ur:provenance/lfaxhdjzinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdwnfdcxwzsbdasgiejsamsagmykwktiuecebedmwdlkhlhehggemurdflzetackvdynbajzldmwrtnbryweglgalutyonzegh",
            "ur:provenance/lfaxhdjztegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadasndotidvdrtghpaidgdfwlshnwtprsgknhtbnhttbuopsjlzttiuyhprteyjnytjpldjktpmtsfhfrhvdvlfygabsktiddria",
            "ur:provenance/lfaxhdjzihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvswtfetauojoplosvslkbbhfmnchsagucyvtrylyhflyrnlkndvepatpwpurckwfynmsdtesjohspmsosgvorkvedmmntafwry",
            "ur:provenance/lfaxhdjzlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmtnkoselehgtbkokeckbkwpmukoknlebwwnjecsdpskryadjthgcthlmnfmiyimsomdsfcsjnnewpbwrswlfmzewzsbwlvtgu",
            "ur:provenance/lfaxhdjzntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndpmsnattkdwwpmsswcmzchsgtpfhegywdhpledtgacxbsmhamaocakncxlucejkhkrskndiamqdjlnyaygoaxpsctndspetfp",
            "ur:provenance/lfaxhdjzctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdisagdyltizezestdyrfwmstdtzmfthynelofgkbmurhsamtimtenlmeaojlhlnyrfiatoylgmjprhkgidrtptfnvwcnvsckns",
            "ur:provenance/lfaxhdjzbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjloebtrednfmtyiyjnntdmkkfhlapepahgtnsgiodrrnfptszmndkifgwywnamwnmhfwaxbwwthklgtamhcwfmcafwgobwtogm",
            "ur:provenance/lfaxhdjzcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdebkbbckjlknvyeyjptneendldoyfxcwrlmsrymkkbgecncnrhlodnosmudrfmlufwhdhgrpfpwpeowpkstadytadkbgmodlgl",
            "ur:provenance/lfaxhdjzvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdbgrkvwnndaaeiedkoxleylaeladtadkntdhpuyrpwmatgebbnbneurwmdytbteasbtlnlpmojzswdktkbseovwkgjolnfpgs",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerloshtryzespbesblbhstahfmyaadawmfsmtfgksvspkbtjtrfbtwmcmvlhyjynywdsbmnwsjspkswsehtdmjlgeqddrpydpknjz",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdwnfdcxwzsbdasgiejsamsagmykwktiuecebedmwdlkhlhehggemurdflzetackvdynbajzldmwrtnbryweglgalursosrefs",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjztegyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadasndotidvdrtghpaidgdfwlshnwtprsgknhtbnhttbuopsjlzttiuyhprteyjnytjpldjktpmtsfhfrhvdvlfygabscehnhsbk",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvswtfetauojoplosvslkbbhfmnchsagucyvtrylyhflyrnlkndvepatpwpurckwfynmsdtesjohspmsosgvorkvedmvwuyasty",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmtnkoselehgtbkokeckbkwpmukoknlebwwnjecsdpskryadjthgcthlmnfmiyimsomdsfcsjnnewpbwrswlfmzewznbwmpyft",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndpmsnattkdwwpmsswcmzchsgtpfhegywdhpledtgacxbsmhamaocakncxlucejkhkrskndiamqdjlnyaygoaxpsctwtsgjkde",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdisagdyltizezestdyrfwmstdtzmfthynelofgkbmurhsamtimtenlmeaojlhlnyrfiatoylgmjprhkgidrtptfnvwfdwdgoyk",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzbetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjloebtrednfmtyiyjnntdmkkfhlapepahgtnsgiodrrnfptszmndkifgwywnamwnmhfwaxbwwthklgtamhcwfmcafwfmbylpfr",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdebkbbckjlknvyeyjptneendldoyfxcwrlmsrymkkbgecncnrhlodnosmudrfmlufwhdhgrpfpwpeowpkstadytadkkkmhiedi",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdjzvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdbgrkvwnndaaeiedkoxleylaeladtadkntdhpuyrpwmatgebbnbneurwmdytbteasbtlnlpmojzswdktkbseovwkgcwlrbkda",
        ]
        runTest(resolution: .high, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
    
    func testHighWithInfo() {
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, hash: 235640558b7a15366946844f7b60a9d63e0878b9f6f2d24c63e0c1772049b17b, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 0, date: 2023-06-20T12:00:00Z, info: "Consequuntur Esse Rem Et Aliquam")"#,
            #"ProvenanceMark(key: 695dafa138cfe538bedba2c8a96ec2dad070367119cd0a0255864d59c695d857, hash: c41a74d93e16474397f4bed7c9df8f037742f24cfbcee71a67d8397d4539839d, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 1, date: 2023-06-21T12:00:00Z, info: "Quos Explicabo Ullam Corrupti Odit Ab")"#,
            #"ProvenanceMark(key: d351f7dff419008f691d0bebe4e71f69bfd291fd7e6eb4dff86f78ab260ce12c, hash: 6afcb70e009a40ac985c2296ca872fb70d783fda5198ed6de3618c87d6b1f189, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 2, date: 2023-06-22T12:00:00Z, info: "Qui Debitis Quia Ut")"#,
            #"ProvenanceMark(key: 650a700450011d2fea8a9bc2249af6c224539e315edbdc34b0dd5361956328ca, hash: b5b373a0081a9e79edd607500d00c4a5f89515625cda47b92bb94e6d137e7386, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 3, date: 2023-06-23T12:00:00Z, info: "Animi Et Nesciunt Expedita Aut Doloremque Omnis")"#,
            #"ProvenanceMark(key: 869c390f34b1f7e0d618ba6b3f999a0ee1929c31e0f8c8c5e0b74cbbb4fdba35, hash: b719951898cfeef3e68bb87ec37fd1b9ca3d654f0083b0a4a3a8f4ae8b8488ca, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 4, date: 2023-06-24T12:00:00Z, info: "Voluptatem Cumque Totam Sed")"#,
            #"ProvenanceMark(key: 9d9959631c2d8991161a8a5bec17edb2cc519d3df4f241dc98a285963646294d, hash: 77b2e2fb0aa6a897745a96d05363154a3e1e260124474b8bfab44def612bd893, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 5, date: 2023-06-25T12:00:00Z, info: "Dolor Qui Voluptatem Officiis Cupiditate")"#,
            #"ProvenanceMark(key: 1f1df300ca1ba7e6e192dfdc4debe4d643026c948ef84fc50fd81ef55a3fe95a, hash: 63243d94e7a1ab9fc97035146aacac8fe09d03c21e63070d288cb5afbd724513, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 6, date: 2023-06-26T12:00:00Z, info: "Atque Quo Dolorem Aliquid Accusamus Qui In")"#,
            #"ProvenanceMark(key: 10cf8fb2ae8719ead09a153aa193e05d7abf97501bac041942a1a502e7f5eeba, hash: 255b92adcee6c10dc71a0d58640432b6e87b5cf452e44d097b5cec189c83510f, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 7, date: 2023-06-27T12:00:00Z, info: "Praesentium Sint Voluptatibus")"#,
            #"ProvenanceMark(key: 186d0597dfd56a71abf4e86004c822600e4c72f6e3cf9d2a0f0c03aff38bd48d, hash: 317a304944a27fbc7fd0336f2e6ba3e5b927c6c99099436c9e1f64f61240685c, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 8, date: 2023-06-28T12:00:00Z, info: "Ut Assumenda Aperiam Sequi Ut Saepe Impedit")"#,
            #"ProvenanceMark(key: e079e69f4ad9ae5fd8ce003998741df6598920846424db654b41f341d50fc56b, hash: f4bb032b3240eb0d9dccac9893f4d580e9f5cd9e4022a567245d5ad18d300c83, id: 7eb559bbbf6cce2632cf9f194aeb50943de7e1cbad54dcfab27a42759f5e2fed, seq: 9, date: 2023-06-29T12:00:00Z, info: "Voluptatum Dolorem Odio Sed Ab")"#,
        ]
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days easy task note chef game warm good meow figs void very stub poem gush undo zaps purr kiln flew keep note holy dull wave free holy keep jury need logo echo iron barn beta foxy fair vibe gems need flux crux jowl real idea also purr huts calm zaps next work gush limp note real owls dark help main dice jade hard memo silk yurt noon draw memo need drop wand duty drum lamb rust tuna paid gush king monk song draw zest iris yank wand paid free main webs jugs peck skew safe heat drum jowl game quad door rich cash kiwi waxy game high duty belt saga gyro keno aqua keno girl news when quiz iced exam zest blue vibe zone yurt poem noon safe solo play rust roof noon fact bald chef luau glow monk",
            "iron hill pose obey exit task view exit ruin ugly oboe soap part jolt saga twin taxi judo even jugs chef swan back also gyro lion gift hawk skew mild trip hang love road gush poem curl peck even math lazy yawn nail kiln task noon soap drum ramp jolt buzz warm axis exit ruin ruin plus math pose many saga roof mild good city cyan hill fund jury brew oval veto into what able lung oval zest glow peck loud jugs even jowl cook quiz mint easy junk cola barn zinc kite bulb vast kick yawn beta jazz loud meow rust numb ruby wave girl gala luau webs swan main film into chef cook gala tied aqua buzz jowl warm wolf foxy memo vast ramp jury ruin zinc data roof silk high zest memo next brew zest horn gift bias limp jade keep dice zaps math liar what glow jazz",
            "time gray yell user work chef able many iron cola bald warm vibe void cost iron runs tied maze zinc knob jolt quiz user yoga jowl keys play days barn very draw undo help bias hawk blue noon tied able arch undo iced hope help undo idle skew wall gyro echo deli huts barn exit omit noon task twin cola need silk acid axis toil wave game each data liar luau twin swan free meow maze bias also soap huts lava curl cash guru leaf soap aqua drum fern silk cyan hope iced gala epic race loud junk trip mint surf half rich void vial foxy gala bias each owls luau fern crux slot skew legs rust keno yell wall cyan next plus omit monk gems bulb body love cash next tuna",
            "inch back judo aqua good acid cola dull wand love need saga dark navy yawn saga dark guru noon each holy ugly undo edge puff unit guru huts mild idea dice song view toys axis king cats judo legs fund zero void keep aunt visa yoga puma flew fizz inch solo holy fern silk king zone surf draw fair exit rich puff yell vows tuna webs luau grim note loud able toys yell jugs able claw epic waxy flux list axis join urge gray unit wave quad crux limp zinc road claw buzz tuna pool quiz miss diet eyes judo huts poem solo song veto rock vibe drum rust duty luck obey rich mint wolf bald high cash vast poem gala hard hang fizz task huts hang song menu note able gala each easy horn drum door yell easy diet lamb kiwi frog good yawn memo fair void webs wand blue flew horn note miss fish cyan gala lazy gush knob",
            "lion news eyes bias edge puma yell vast tomb cats road jade fish nail navy beta very memo news each vast yoga soap silk vast real gems rock quiz zinc road epic frog omit vial real love wolf toil toys when wave monk cats taco kiwi aunt saga time jump jump dull road lion echo noon roof eyes toys arch when zaps owls grim fact part high draw horn duty idle road ruin cusp gala saga vial solo when bias road dull road drum vial zone barn navy pose silk pose cook solo epic bulb song mild surf cats join note wasp brew runs wall film zone whiz even news scar horn arch limp free vast city free user data dull noon oval huts beta mint fair deli scar pool body girl navy yurt unit grim lion list fish fuel each",
            "next nail hawk idea code drop loud maze calm city love help wasp cash wave purr surf gray next figs work whiz flap undo monk oboe limp mint even frog diet gift help kick wolf saga door navy gush door zone zest brew fizz gush code hard menu dice jump huts legs when girl logo free zero rich vial user code cyan meow need heat crux hill fern next saga surf skew gear safe onyx gems judo fish inky also loud play game flew cost calm obey kite tent holy tent ruin rust memo gear surf runs kiln deli atom quad jowl navy away gyro apex plus cost lion twin undo flew soap rock hawk veto legs brag bias menu into inky cash inch deli back menu peck also cusp down gyro curl saga buzz fizz axis wolf glow flew visa omit ruby quiz chef work solo iris kick aqua beta barn ruby jury",
            "cost cola wolf able song claw owls visa very memo user undo gift warm vibe tomb flux also jazz meow main yoga glow silk bias trip cook yank heat fish wall heat soap jolt void legs toil bias gala saga bald very leaf crux jazz fish heat horn list yoga pool iced barn kite cyan inky idle vibe work race eyes note toys deli gear bulb glow main gush numb buzz guru judo wolf item cash zoom mild glow acid memo girl news fund numb bald tied play cola foxy liar flew dice cook game jolt idea taco yell grim jump rich king iced rust part fern view legs cola flew kiwi horn oval gear axis gyro taco gear inky task tomb game note barn waxy flux part hawk aqua edge memo diet fund item cola peck iced eyes tent taco barn runs king tied exit task gala gyro vibe pose eyes belt play aqua silk",
            "blue task many purr pool list chef wand taxi navy buzz fact obey menu vast hill kiln runs miss good claw plus aqua chef flew obey open also void yank waxy road plus undo cook city roof glow silk tomb hope vows luck flux kick zone edge guru numb redo claw aunt lava rich apex soap scar jowl real help hard gift belt jowl math dark eyes brag peck tuna code zaps high acid fish task purr redo fund junk undo fizz junk memo veto brag user hawk apex gyro cusp foxy away fair able veto flew apex brew what hawk lung tuna math claw film cola flew gush edge luau tomb limp brag taco logo safe song puff flux ruby yawn play vibe nail atom easy oboe yell bias claw safe user into gray zone gift vial brew belt fair limp inky",
            "cats join arch miss user toil item jugs play work vows horn aqua soap cusp horn beta gems jump yawn vial task next door bias barn apex pose wolf luau tiny lung rich wolf peck free poem king jade lazy flap cola days zaps monk surf junk tiny open inky twin holy kick film omit item lazy dull owls help into body fair dice webs girl keno flap atom miss zero obey yell good foxy wall bias lamb obey paid gift into data code quiz lazy away frog beta legs crux legs join grim iris flux hard hang ramp flap wasp echo wasp keys tuna duty tuna dark need part roof down apex tiny calm fund cyan yoga data nail solo unit task jury yurt keys free acid rich noon mild ruin cats cats gush rust main flew yell user free brew sets chef song warm kiwi huts draw jowl unit jugs iron item gyro kept maze",
            "vast kick visa note game tuna pool hope trip taco able eyes monk jury cola yawn hawk loud crux liar idle dark ugly inch gear flap wolf flap toil bias silk jade vibe quiz ramp calm idle wand gala loud zero omit iced figs task silk waxy gyro yurt skew vast list kite kite jury cyan data toil luau obey gyro unit redo tied lazy onyx slot idle lion oval yawn join belt maze body cost next silk cola urge gyro yank safe sets item aqua what oboe glow jowl wolf many nail saga fern door belt lion limp memo jazz skew dark task bias echo view king lazy jowl gear body logo limp zaps plus part toys back horn gyro next race stub draw wand limp tuna obey fund days list meow game jolt redo waxy play data song iced obey flux vows",
        ]
        let expectedURs = [
            "ur:provenance/lfaxhdmnkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerlosdkhpmndejehdmoskytnndwmonddpwddydmlbrttapdghkgmksgdwztisykwdpdfemnwsjspkswsehtdmjlgeqddrrhchkiwygehhdybtsagokoaakoglnswnqzidemztbevezeytpmnnsesopyrtrfnnftbdjkisckem",
            "ur:provenance/lfaxhdmuinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdcycnhlfdjybwolvoiowtaelgolztgwpkldjsenjlckqzmteyjkcabnzckebbvtkkynbajzldmwrtnbryweglgaluwssnmnfmiocfckgatdaabzjlwmwffymovtrpjyrnzcdarfskhhztmontbwzthngtbslpjekpdezsmheoytgeki",
            "ur:provenance/lfaxhdlategyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadastlwegeehdalrlutnsnfemwmebsaosphslaclchgulfspaadmfnskcnheidgaecreldjktpmtsfhfrhvdvlfygabsehoslufncxstswlsrtkoylwlcnntpsotmkgsbbbyktjyynhy",
            "ur:provenance/lfaxhdntihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvstawslugmneldaetsyljsaecwecwyfxltasjnuegyutweqdcxlpzcrdcwbztaplqzmsdtesjohspmsosgvorkvedmrtdylkoyrhmtwfbdhhchvtpmgahdhgfztkhshgsgmuneaegaeheyhndmdryleydtlbkifggdynmofrvdwswdbefwhnnemsfhcnahgshgat",
            "ur:provenance/lfaxhdldlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmftpthhdwhndyierdrncpgasavlsownbsrddlrddmvlzebnnypeskpecksoecbbsgmdsfcsjnnewpbwrswlfmzewzennssrhnahlpfevtcyfeurdadlnnolhsbamtfrdisrplbyglnyytutgmlnmdgyvlck",
            "ur:provenance/lfaxhdmtntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndhtcxhlfnntsasfswgrseoxgsjofhiyaoldpygefwctcmoyketthyttrnrtmogrsfrskndiamqdjlnyaygoaxpsctlntnuofwsprkhkvolsbgbsmuioiychihdibkmupkaocpdngoclsabzfzaswfgwfwvaotryqzcfwksoiskkaalretmomd",
            "ur:provenance/lfaxhdmkctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdigrbbgwmnghnbbzgujowfimchzmmdgwadmoglnsfdnbbdtdpycafylrfwdeckgejtiatoylgmjprhkgidrtptfnvwlscafwkihnolgrasgotogriytktbgenebnwyfxpthkaaeemodtfdimcapkidestttobnrskgtdettkgagovepeesftdensny",
            "ur:provenance/lfaxhdlubetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlmhdkesbgpktacezshhadfhtkprrofdjkuofzjkmovobgurhkaxgocpfyayfraevofwaxbwwthklgtamhcwfmcafwgheelutblpbgtolosesgpffxryynpyvenlameyoeylbscwseuriogyzegtvlbwbzdwseds",
            "ur:provenance/lfaxhdnlcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdewsglkofpammszooyylgdfywlbslboypdgtiodaceqzlyayfgbalscxlsjngmisfxhdhgrpfpwpeowpkstadytadkndptrfdnaxtycmfdcnyadanlsouttkjyytksfeadrhnnmdrncscsghrtmnfwylurfebwsscfsgwmkihsdwjlutjsinnyttmevs",
            "ur:provenance/lfaxhdlkvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdlyoxstielnolynjnbtmebyctntskcauegoyksessimaawtoegwjlwfmynlsafndrbtlnlpmojzswdktkbseovwkglyjlgrbylolpzspspttsbkhngontresbdwwdlptaoyfddsltmwgejtrowypydasglpuyaeqd",
        ]
        let expectedURLs = [
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmnkbrehkrkrsjztodseytknecfgewmgdmwfsvdvysbpmghuozsprknfwkpnehydlwefehykpjyndloeoinbnbafyfrvegsndfxcxjlrliaaoprhscmzsntwkghlpnerlosdkhpmndejehdmoskytnndwmonddpwddydmlbrttapdghkgmksgdwztisykwdpdfemnwsjspkswsehtdmjlgeqddrrhchkiwygehhdybtsagokoaakoglnswnqzidemztbevezeytpmnnsesopyrtrfnnftbdstflwnwn",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmuinhlpeoyettkvwetrnuyoespptjtsatntijoenjscfsnbkaogolngthkswmdtphglerdghpmclpkenmhlyynnlkntknnspdmrpjtbzwmasetrnrnpsmhpemysarfmdgdcycnhlfdjybwolvoiowtaelgolztgwpkldjsenjlckqzmteyjkcabnzckebbvtkkynbajzldmwrtnbryweglgaluwssnmnfmiocfckgatdaabzjlwmwffymovtrpjyrnzcdarfskhhztmontbwzthngtbslpjekpdezsmhisayjzas",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdlategyylurwkcfaemyincabdwmvevdctinrstdmezckbjtqzuryajlkspydsbnvydwuohpbshkbenntdaeahuoidhehpuoieswwlgoeodihsbnetotnntktncandskadastlwegeehdalrlutnsnfemwmebsaosphslaclchgulfspaadmfnskcnheidgaecreldjktpmtsfhfrhvdvlfygabsehoslufncxstswlsrtkoylwlcnntpsotmkgsbbbylrloqzdk",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdntihbkjoaagdadcadlwdlendsadknyynsadkgunnehhyuyuoeepfutguhsmdiadesgvwtsaskgcsjolsfdzovdkpatvayapafwfzihsohyfnskkgzesfdwfretrhpfylvstawslugmneldaetsyljsaecwecwyfxltasjnuegyutweqdcxlpzcrdcwbztaplqzmsdtesjohspmsosgvorkvedmrtdylkoyrhmtwfbdhhchvtpmgahdhgfztkhshgsgmuneaegaeheyhndmdryleydtlbkifggdynmofrvdwswdbefwhnnemsfhcncfcmcxgo",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdldlnnsesbseepaylvttbcsrdjefhnlnybavymonsehvtyaspskvtrlgsrkqzzcrdecfgotvlrllewftltswnwemkcstokiatsatejpjpdlrdlneonnrfestsahwnzsosgmftpthhdwhndyierdrncpgasavlsownbsrddlrddmvlzebnnypeskpecksoecbbsgmdsfcsjnnewpbwrswlfmzewzennssrhnahlpfevtcyfeurdadlnnolhsbamtfrdisrplbyglnyytutgmlnpyrfghur",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmtntnlhkiacedpldmecmcylehpwpchweprsfgyntfswkwzfpuomkoelpmtenfgdtgthpkkwfsadrnyghdrzeztbwfzghcehdmudejphslswngllofezorhvlurcecnmwndhtcxhlfnntsasfswgrseoxgsjofhiyaoldpygefwctcmoyketthyttrnrtmogrsfrskndiamqdjlnyaygoaxpsctlntnuofwsprkhkvolsbgbsmuioiychihdibkmupkaocpdngoclsabzfzaswfgwfwvaotryqzcfwksoiskkaaueoxbwwp",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdmkctcawfaesgcwosvavymouruogtwmvetbfxaojzmwmnyagwskbstpckykhtfhwlhtspjtvdlstlbsgasabdvylfcxjzfhhthnltyaplidbnkecniyievewkreesnetsdigrbbgwmnghnbbzgujowfimchzmmdgwadmoglnsfdnbbdtdpycafylrfwdeckgejtiatoylgmjprhkgidrtptfnvwlscafwkihnolgrasgotogriytktbgenebnwyfxpthkaaeemodtfdimcapkidestttobnrskgtdettkgagovepeeshyimrlbs",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdlubetkmyprplltcfwdtinybzftoymuvthlknrsmsgdcwpsaacffwoyonaovdykwyrdpsuockcyrfgwsktbhevslkfxkkzeeegunbrocwatlarhaxspsrjlrlhphdgtbtjlmhdkesbgpktacezshhadfhtkprrofdjkuofzjkmovobgurhkaxgocpfyayfraevofwaxbwwthklgtamhcwfmcafwgheelutblpbgtolosesgpffxryynpyvenlameyoeylbscwseuriogyzegtvlbwmospfhwm",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdnlcsjnahmsurtlimjspywkvshnaaspcphnbagsjpynvltkntdrbsbnaxpewflutylgrhwfpkfepmkgjelyfpcadszsmksfjktyoniytnhykkfmotimlydloshpiobyfrdewsglkofpammszooyylgdfywlbslboypdgtiodaceqzlyayfgbalscxlsjngmisfxhdhgrpfpwpeowpkstadytadkndptrfdnaxtycmfdcnyadanlsouttkjyytksfeadrhnnmdrncscsghrtmnfwylurfebwsscfsgwmkihsdwjlutjsincytiqzay",
            "https://example.com/validate?provenance=tngdgmgwhflfaxhdlkvtkkvanegetaplhetptoaeesmkjycaynhkldcxlriedkuyihgrfpwffptlbsskjeveqzrpcmiewdgaldzootidfstkskwygoytswvtltkekejycndatlluoygoutrotdlyoxstielnolynjnbtmebyctntskcauegoyksessimaawtoegwjlwfmynlsafndrbtlnlpmojzswdktkbseovwkglyjlgrbylolpzspspttsbkhngontresbdwwdlptaoyfddsltmwgejtrowypydasghnldhtfz",
        ]
        runTest(resolution: .high, includeInfo: true, expectedDescriptions: expectedDescriptions, expectedBytewords: expectedBytewords, expectedURs: expectedURs, expectedURLs: expectedURLs)
    }
}
