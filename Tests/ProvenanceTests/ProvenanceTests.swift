import XCTest
@testable import Provenance
import BCCrypto
import WolfBase
import WolfLorem

final class ProvenanceTests: XCTestCase {
    func testBasic() throws {
        var rng: RandomNumberGenerator = makeFakeRandomNumberGenerator()
        let provenanceGen = ProvenanceMarkGenerator(passphrase: "Wolf", using: &rng)
        let count = 10
        let dates = (0..<count).map {
            try! Date(iso8601: "2023-06-20T12:00:00Z") + 60.0 * TimeInterval($0)
        }
        let marks = dates.map { provenanceGen.next(date: $0) }
        
        XCTAssert(ProvenanceMark.isSequenceValid(marks: marks))

        XCTAssert(!marks[1].precedes(next: marks[0]))

        //marks.forEach { print($0) }
        let expectedDescriptions = [
            "ProvenanceMark(key: 7eb559bbbf6cce26, id: 7eb559bbbf6cce26, hash: 24c2b216a722ea31, seq: 0, date: 2023-06-20T12:00:00Z)",
            "ProvenanceMark(key: 695dafa138cfe538, id: 7eb559bbbf6cce26, hash: b481465150f5db48, seq: 1, date: 2023-06-20T12:01:00Z)",
            "ProvenanceMark(key: bedba2c8a96ec2da, id: 7eb559bbbf6cce26, hash: 47323ada85f581f5, seq: 2, date: 2023-06-20T12:02:00Z)",
            "ProvenanceMark(key: d070367119cd0a02, id: 7eb559bbbf6cce26, hash: 8102fd2da095c61c, seq: 3, date: 2023-06-20T12:03:00Z)",
            "ProvenanceMark(key: 55864d59c695d857, id: 7eb559bbbf6cce26, hash: 9b4a5823b47e2c44, seq: 4, date: 2023-06-20T12:04:00Z)",
            "ProvenanceMark(key: d351f7dff419008f, id: 7eb559bbbf6cce26, hash: 2b3a36e8d4695efa, seq: 5, date: 2023-06-20T12:05:00Z)",
            "ProvenanceMark(key: 691d0bebe4e71f69, id: 7eb559bbbf6cce26, hash: 6cc37b1c9c2de016, seq: 6, date: 2023-06-20T12:06:00Z)",
            "ProvenanceMark(key: bfd291fd7e6eb4df, id: 7eb559bbbf6cce26, hash: d08ea59fcddcd64b, seq: 7, date: 2023-06-20T12:07:00Z)",
            "ProvenanceMark(key: f86f78ab260ce12c, id: 7eb559bbbf6cce26, hash: 2d6acce2f345d873, seq: 8, date: 2023-06-20T12:08:00Z)",
            "ProvenanceMark(key: 650a700450011d2f, id: 7eb559bbbf6cce26, hash: e54f31ff821ea455, seq: 9, date: 2023-06-20T12:09:00Z)",
        ]
        XCTAssertEqual(marks.map { $0.description }, expectedDescriptions)

        let bytewords = marks.map { $0.bytewords(style: .standard) }
        //bytewords.forEach { print($0) }
        let expectedBytewords = [
            "knob race hawk rock runs jazz taco days keep data axis jury mint hard wolf body apex heat fuel noon flap hard void fern navy good lava redo cusp down stub veto cost draw logo jury",
            "iron hill pose obey exit task view exit paid tuna flew code waxy chef brew wave beta meow navy whiz play fish tied paid monk code luck rust atom jade bias scar lamb waxy keys kiwi",
            "ruin ugly oboe soap part jolt saga twin brag fizz fish draw zoom owls girl able buzz brag tent sets ruin into race unit real soap vast ugly pool days soap huts idle cola claw purr",
            "taxi judo even jugs chef swan back also yoga mild draw dull echo dull draw slot road swan safe junk monk jowl eyes runs miss real inch into slot yawn hang barn kick main webs luau",
            "gyro lion gift hawk skew mild trip hang easy aunt ramp gear zaps brew miss yell redo half pose onyx jowl draw zoom also heat exam sets yell also eyes idea when cats paid aunt door",
            "time gray yell user work chef able many puma news girl webs ramp exit barn puma noon legs exam rich half task flew liar barn help yurt yurt lamb puff keep bias vibe fair trip heat",
            "iron cola bald warm vibe void cost iron back help vast menu cost meow ruby exam flap foxy vibe item when note days logo warm junk noon roof lamb noon foxy roof meow open gems quad",
            "runs tied maze zinc knob jolt quiz user wand keep junk monk task tied hawk keys junk road heat loud bias vibe keys zaps film draw keys good skew maze fern inch belt miss very math",
            "yoga jowl keys play days barn very draw inky keep math epic when fair menu keep away sets jury unit item ruby diet drum puff gear hang lazy guru kept wolf what quad roof barn zero",
            "inch back judo aqua good acid cola dull bald meow tiny yurt into diet love menu brew good exit work inch puff gear brag tent jugs jump flux waxy exit guru knob toil scar fuel view",
        ]
        XCTAssert(zip(bytewords, expectedBytewords).allSatisfy { $0.0 == $0.1 })
        let bytewordsMarks = bytewords.map {
            ProvenanceMark(bytewords: $0)!
        }
        XCTAssertEqual(marks, bytewordsMarks)

        let urs = marks.map { $0.urString }
        //urs.forEach { print($0) }
        let expectedURs = [
            "ur:provenance/hdcxkbrehkrkrsjztodskpdaasjymthdwfbyaxhtflnnfphdvdfnnygdlarocpdnsbvoiaryfzay",
            "ur:provenance/hdcxinhlpeoyettkvwetpdtafwcewycfbwwebamwnywzpyfhtdpdmkcelkrtamjebssraxlbpfad",
            "ur:provenance/hdcxrnuyoespptjtsatnbgfzfhdwzmosglaebzbgttssrnioreutrlspvtuypldssphscslkteto",
            "ur:provenance/hdcxtijoenjscfsnbkaoyamddwdleodldwstrdsnsejkmkjlesrsmsrlihiostynhgbnahctdiyl",
            "ur:provenance/hdcxgolngthkswmdtphgeyatrpgrzsbwmsylrohfpeoxjldwzmaohtemssylaoesiawnieestkhf",
            "ur:provenance/hdcxtegyylurwkcfaemypansglwsrpetbnpannlsemrhhftkfwlrbnhpytytlbpfkpbsmkpkbeds",
            "ur:provenance/hdcxincabdwmvevdctinbkhpvtmuctmwryemfpfyveimwnnedslowmjknnrflbnnfyrfvseelrtk",
            "ur:provenance/hdcxrstdmezckbjtqzurwdkpjkmktktdhkksjkrdhtldbsvekszsfmdwksgdswmefnihjsamdtwp",
            "ur:provenance/hdcxyajlkspydsbnvydwiykpmhecwnfrmukpayssjyutimrydtdmpfgrhglyguktwfwttkdpsslt",
            "ur:provenance/hdcxihbkjoaagdadcadlbdmwtyytiodtlemubwgdetwkihpfgrbgttjsjpfxwyetgukbptgmmynl",
        ]
        XCTAssert(zip(urs, expectedURs).allSatisfy { $0.0 == $0.1 })
        let urMarks = urs.map {
            try! ProvenanceMark(urString: $0)
        }
        XCTAssertEqual(marks, urMarks)
        
        let baseURL = URL(string: "https://github.com/wolfmcnally/testchain")!
        let urls = marks.map { $0.url(base: baseURL) }
        //urls.forEach { print($0) }
        let expectedURLs = [
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxkbrehkrkrsjztodskpdaasjymthdwfbyaxhtflnnfphdvdfnnygdlarocpdnsbvoaetnzmwl",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxinhlpeoyettkvwetpdtafwcewycfbwwebamwnywzpyfhtdpdmkcelkrtamjebssrhncsbsvt",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxrnuyoespptjtsatnbgfzfhdwzmosglaebzbgttssrnioreutrlspvtuypldssphskgwmjzdl",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxtijoenjscfsnbkaoyamddwdleodldwstrdsnsejkmkjlesrsmsrlihiostynhgbniyksmkcm",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxgolngthkswmdtphgeyatrpgrzsbwmsylrohfpeoxjldwzmaohtemssylaoesiawnathyjorl",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxtegyylurwkcfaemypansglwsrpetbnpannlsemrhhftkfwlrbnhpytytlbpfkpbszosnpest",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxincabdwmvevdctinbkhpvtmuctmwryemfpfyveimwnnedslowmjknnrflbnnfyrflugufrdm",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxrstdmezckbjtqzurwdkpjkmktktdhkksjkrdhtldbsvekszsfmdwksgdswmefnihbghsmtbt",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxyajlkspydsbnvydwiykpmhecwnfrmukpayssjyutimrydtdmpfgrhglyguktwfwtpsgekgiy",
            "https://github.com/wolfmcnally/testchain?provenance=tngdgmgwhfhdcxihbkjoaagdadcadlbdmwtyytiodtlemubwgdetwkihpfgrbgttjsjpfxwyetgukbsgecdyks",
        ]
        XCTAssert(zip(urls, expectedURLs).allSatisfy { $0.0.description == $0.1 })
        let urlMarks = urls.map {
            ProvenanceMark(url: $0)!
        }
        XCTAssertEqual(marks, urlMarks)
    }
    
    func testWithInfo() {
        var rng: RandomNumberGenerator = makeFakeRandomNumberGenerator()
        let provenanceGen = ProvenanceMarkGenerator(passphrase: "Wolf", using: &rng)
        let count = 10
        let dates = (0..<count).map {
            try! Date(iso8601: "2023-06-20T12:00:00Z") + 60.0 * TimeInterval($0)
        }
        let marks = dates.map {
            let title = Lorem.title(using: &rng)
            return provenanceGen.next(date: $0, info: title)
        }
        
        XCTAssert(ProvenanceMark.isSequenceValid(marks: marks))

        XCTAssert(!marks[1].precedes(next: marks[0]))

        //marks.forEach { print($0) }
        let expectedDescriptions = [
            #"ProvenanceMark(key: 7eb559bbbf6cce26, id: 7eb559bbbf6cce26, hash: a3ad446d20430a49, seq: 0, date: 2023-06-20T12:00:00Z, info: "Enim Aperiam Odio Eaque")"#,
            #"ProvenanceMark(key: 695dafa138cfe538, id: 7eb559bbbf6cce26, hash: 2a50584cc1515e8d, seq: 1, date: 2023-06-20T12:01:00Z, info: "Numquam Quis")"#,
            #"ProvenanceMark(key: bedba2c8a96ec2da, id: 7eb559bbbf6cce26, hash: 95d674c0a7683754, seq: 2, date: 2023-06-20T12:02:00Z, info: "Cum Et Modi Corporis Molestias")"#,
            #"ProvenanceMark(key: d070367119cd0a02, id: 7eb559bbbf6cce26, hash: 10a0ef027e3d5b18, seq: 3, date: 2023-06-20T12:03:00Z, info: "Nobis Blanditiis Voluptatum Ut Est Quos Explicabo")"#,
            #"ProvenanceMark(key: 55864d59c695d857, id: 7eb559bbbf6cce26, hash: a8765ca07e848c6d, seq: 4, date: 2023-06-20T12:04:00Z, info: "Repellendus Dolor Et")"#,
            #"ProvenanceMark(key: d351f7dff419008f, id: 7eb559bbbf6cce26, hash: 3f940efd9438a9c8, seq: 5, date: 2023-06-20T12:05:00Z, info: "Consequatur Dignissimos")"#,
            #"ProvenanceMark(key: 691d0bebe4e71f69, id: 7eb559bbbf6cce26, hash: 01c286c52762fb83, seq: 6, date: 2023-06-20T12:06:00Z, info: "Quia Ut Praesentium Sunt Eum Totam Commodi")"#,
            #"ProvenanceMark(key: bfd291fd7e6eb4df, id: 7eb559bbbf6cce26, hash: defb3de89ad3ecf3, seq: 7, date: 2023-06-20T12:07:00Z, info: "Doloremque Omnis Laudantium Optio Esse Et")"#,
            #"ProvenanceMark(key: f86f78ab260ce12c, id: 7eb559bbbf6cce26, hash: 4e0524c045ee4b88, seq: 8, date: 2023-06-20T12:08:00Z, info: "Dolores Dolores Nobis Quisquam Ullam")"#,
            #"ProvenanceMark(key: 650a700450011d2f, id: 7eb559bbbf6cce26, hash: 09b14ffa6b7cdbe5, seq: 9, date: 2023-06-20T12:09:00Z, info: "Qui Adipisci Veritatis Velit Suscipit")"#,
        ]
        XCTAssertEqual(marks.map { $0.description }, expectedDescriptions)

        let urs = marks.map { $0.urString }
        //urs.forEach { print($0) }
        let expectedURs = [
            "ur:provenance/hdetkbrehkrkrsjztodskpdaasjymthdwfbyaxhtflnnfphdvdfncafhkosrongednnybkuobgonnboebnjeeoatlocfpsvemtoscwsbfelpbbrorkeevtjkclpa",
            "ur:provenance/hddpinhlpeoyettkvwetpdtafwcewycfbwwebamwnywzpyfhtdpdamsnmoutmstkleamaxgomnfwdmwedmdraslymocltlltwdosse",
            "ur:provenance/hdfzrnuyoespptjtsatnbgfzfhdwzmosglaebzbgttssrnioreutihdwplselkrkkbrtlujljlfzfwcyloyatkcmmsnlgasolbmugondlklorodleccwrnlypkrddioxcmtagwbnrfge",
            "ur:provenance/hdgutijoenjscfsnbkaoyamddwdleodldwstrdsnsejkmkjlesrsambzktfdcfhysgayjytsgrgthkdeckbsuyaxntdlrncsuylapectjltphpgdbgfeprrpmurowpgoessnchprfyprprrnfwvoaektcpvozojoylkomhldyntndpbsmu",
            "ur:provenance/hdecgolngthkswmdtphgeyatrpgrzsbwmsylrohfpeoxjldwzmaoinbdrtjyspsrsrtpamkiwtgovaferdpdmelkjnbgrdclwzbkjlpyaoylhnsrwfolfy",
            "ur:provenance/hdettegyylurwkcfaemypansglwsrpetbnpannlsemrhhftkfwlrcsyksewpfhvylffspdktbafgcekkhkyabelgldbdhgfdwfrhgwqzghntdsesjzksropdnbhk",
            "ur:provenance/hdgsincabdwmvevdctinbkhpvtmuctmwryemfpfyveimwnnedslolnjpiaihsstthedtsnldtpuovsahihpenlutlgjtnbnbnecpbtadfpmhpeqdbnaxcppadpdarlcpkgwnmhstrnjzdadnpevwsatsindplbvwmuts",
            "ur:provenance/hdgrrstdmezckbjtqzurwdkpjkmktktdhkksjkrdhtldbsvekszsdyhkvtdimennamutvevslkntehhlstzefgdlmtwewfcejojngllgfxroynlasfvdbntpwmflsewffywychhhpyspcspersprbyndveghsfsplb",
            "ur:provenance/hdfgyajlkspydsbnvydwiykpmhecwnfrmukpayssjyutimrydtdmtedkrsotvwuohnbdptfzecndjyurdrlfctwpprvlhghntyyapmrkrkcwjlcprlhnaaadfsmsenbsfelblupfbycmahrkjtmwrdns",
            "ur:provenance/hdflihbkjoaagdadcadlbdmwtyytiodtlemubwgdetwkihpfgrbgfsmybnfgathtdwtopdbgzmytfwtliamdoskifwbasphtgyfmwyehmdkkidlrkgkiwnytsrdpfrnyfdyaykdlskihwmjosfamiahlkt",
        ]
        XCTAssert(zip(urs, expectedURs).allSatisfy { $0.0 == $0.1 })
        let urMarks = urs.map {
            try! ProvenanceMark(urString: $0)
        }
        XCTAssertEqual(marks, urMarks)
    }
}
