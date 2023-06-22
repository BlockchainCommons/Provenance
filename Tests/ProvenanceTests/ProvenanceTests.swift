import XCTest
@testable import Provenance
import BCCrypto
import WolfBase

final class ProvenanceTests: XCTestCase {
    func test1() throws {
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
            "ProvenanceMark(key: 7eb559bbbf6cce26, id: 7eb559bbbf6cce26, seqBytes: 00000000, dateBytes: 2a41cc40, hash: 24c2b216a722ea31, seq: 0, date: 2023-06-20T12:00:00Z, message: 7eb559bbbf6cce26752509749658f311035a479e4158e73c9a5080b8222bcbe2",
            "ProvenanceMark(key: 695dafa138cfe538, id: 7eb559bbbf6cce26, seqBytes: 00000001, dateBytes: 2a41cc7c, hash: b481465150f5db48, seq: 1, date: 2023-06-20T12:01:00Z, message: 695dafa138cfe538a8d9421cee1913ed0e949af2ab3fd2a8981c8cc0066b0fc3",
            "ProvenanceMark(key: bedba2c8a96ec2da, id: 7eb559bbbf6cce26, seqBytes: 00000002, dateBytes: 2a41ccb8, hash: 47323ada85f581f5, seq: 2, date: 2023-06-20T12:02:00Z, message: bedba2c8a96ec2da12403f2cffa74e001512d1c4be67b5ddb7c8e0dbae26c861",
            "ProvenanceMark(key: d070367119cd0a02, id: 7eb559bbbf6cce26, seqBytes: 00000003, dateBytes: 2a41ccf4, hash: 8102fd2da095c61c, seq: 3, date: 2023-06-20T12:03:00Z, message: d070367119cd0a02f8952c2f332f2cc7bacdc173986f39bf97b76567c7f6570c",
            "ProvenanceMark(key: 55864d59c695d857, id: 7eb559bbbf6cce26, seqBytes: 00000004, dateBytes: 2a41cd30, hash: 9b4a5823b47e2c44, seq: 4, date: 2023-06-20T12:04:00Z, message: 55864d59c695d8573207b64bfa1397f7b856afa46f2cff025a37c4f7023963f1",
            "ProvenanceMark(key: d351f7dff419008f, id: 7eb559bbbf6cce26, seqBytes: 00000005, dateBytes: 2a41cd6c, hash: 2b3a36e8d4695efa, seq: 5, date: 2023-06-20T12:05:00Z, message: d351f7dff419008fb19c4eefb6380cb19e8337b956cf42840c5bf9f97fb0750f",
            "ProvenanceMark(key: 691d0bebe4e71f69, id: 7eb559bbbf6cce26, seqBytes: 00000006, dateBytes: 2a41cda8, hash: 6cc37b1c9c2de016, seq: 6, date: 2023-06-20T12:06:00Z, message: 691d0bebe4e71f690a5be0931f94bd374144e46af19f2688eb739ebc7f9e44bc",
            "ProvenanceMark(key: bfd291fd7e6eb4df, id: 7eb559bbbf6cce26, seqBytes: 00000007, dateBytes: 2a41cde4, hash: d08ea59fcddcd64b, seq: 7, date: 2023-06-20T12:07:00Z, message: bfd291fd7e6eb4dfea757398cfd2597873ba5a890fe478fa3e2c7850c6913c65",
            "ProvenanceMark(key: f86f78ab260ce12c, id: 7eb559bbbf6cce26, seqBytes: 00000008, dateBytes: 2a41ce20, hash: 2d6acce2f345d873, seq: 8, date: 2023-06-20T12:08:00Z, message: f86f78ab260ce12c66759035f13b937508c474dd6abd292eb04b57815377f3f0",
            "ProvenanceMark(key: 650a700450011d2f, id: 7eb559bbbf6cce26, seqBytes: 00000009, dateBytes: 2a41ce5c, hash: e54f31ff821ea455, seq: 9, date: 2023-06-20T12:09:00Z, message: 650a700450011d2f0b94d4f967298a93135038f465b04b12d1717243ee38537e",
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
        let marks2 = bytewords.map {
            ProvenanceMark(bytewords: $0)!
        }
        XCTAssertEqual(marks, marks2)

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
        let marks3 = urs.map {
            try! ProvenanceMark(urString: $0)
        }
        XCTAssertEqual(marks, marks3)
        
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
        let marks4 = urls.map {
            ProvenanceMark(url: $0)!
        }
        XCTAssertEqual(marks, marks4)
    }
}
