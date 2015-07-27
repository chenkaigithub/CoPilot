//
//  CPIceTests.swift
//  CoPilot
//
//  Created by Sven A. Schmidt on 24/07/2015.
//  Copyright © 2015 feinstruktur. All rights reserved.
//

import XCTest
import Nimble


func docUrl(docId: String) -> NSURL {
    return NSURL(string: "ws://localhost:12345/doc/\(docId)")!
}


class CPServerTests: XCTestCase {

    func test_cpserver() {
        let s = connectWebsocket(docUrl("1"))
        expect(s).toNot(beNil())
        let c = connectWebsocket(docUrl("1"))
        expect(c).toNot(beNil())
        var message: Message?
        c.onReceive = { msg in
            message = msg
        }
        c.onDisconnect = { error in
            fail("error: \(error)")
        }
        s.onDisconnect = { error in
            fail("error: \(error)")
        }
        s.send(Command(name: "server"))
        expect(message).toEventuallyNot(beNil())
        expect(Command(data: message!.data!).name) == "server"
    }



    func test_birectional() {
        let s = connectWebsocket(docUrl("1"))
        expect(s).toNot(beNil())
        let c = connectWebsocket(docUrl("1"))
        expect(c).toNot(beNil())
        var message: Message?
        c.onReceive = { msg in
            message = msg
        }
        var response: Message?
        s.onReceive = { msg in
            response = msg
        }
        c.onDisconnect = { error in
            fail("error: \(error)")
        }
        s.onDisconnect = { error in
            fail("error: \(error)")
        }

        s.send(Command(name: "ping"))
        expect(message).toEventuallyNot(beNil())
        expect(Command(data: message!.data!).name) == "ping"

        c.send(Command(name: "pong"))
        expect(response).toEventuallyNot(beNil())
        expect(Command(data: response!.data!).name) == "pong"
    }


    func test_two_subscribers() {
        let s = connectWebsocket(docUrl("2"))
        let c1 = connectWebsocket(docUrl("2"))
        let c2 = connectWebsocket(docUrl("2"))

        var sMsg = [Message]()
        s.onReceive = { msg in
            print("s: \(msg)")
            sMsg.append(msg)
        }

        var c1Msg = [Message]()
        c1.onReceive = { msg in
            print("c1: \(msg)")
            c1Msg.append(msg)
        }

        var c2Msg = [Message]()
        c2.onReceive = { msg in
            print("c2: \(msg)")
            c2Msg.append(msg)
        }

        s.send(Command(name: "server"))

        expect(c1Msg.count).toEventually(equal(1))
        expect(Command(data: c1Msg[0].data!).name) == "server"
        expect(c2Msg.count).toEventually(equal(1))
        expect(Command(data: c2Msg[0].data!).name) == "server"
        expect(sMsg.count) == 0

        c1.send(Command(name: "c1"))

        expect(c1Msg.count) == 1
        expect(c2Msg.count).toEventually(equal(2))
        expect(sMsg.count).toEventually(equal(1))
    }


    func test_no_echo() {
        let s = connectWebsocket(docUrl("3"))
        expect(s).toNot(beNil())
        var messages = [Message]()
        s.onReceive = { msg in
            messages.append(msg)
        }
        s.send(Command(name: "1"))

        let c = connectWebsocket(docUrl("3"))
        c.send(Command(name: "2"))

        // make sure the first command does not get echoed back to "s", only the second one should appear
        expect(messages.count).toEventually(beGreaterThan(0))
        expect(Command(data: messages[0].data!).name) == "2"
    }

}