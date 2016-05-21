//
//  DiffTests.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 18/04/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa
import XCTest
import Nimble
import FeinstrukturUtils


func pathForResource(name name: String, type: String) -> String {
    let bundle = NSBundle(forClass: DiffTests.classForCoder())
    return bundle.pathForResource(name, ofType: type)!
}


func contentsOfFile(name name: String, type: String) -> String {
    var result: NSString?
    do {
        let path = pathForResource(name: name, type: type)
        try result = NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
    } catch (let error as NSError) {
        fail("failed to load test file: \(error.localizedDescription)")
    }
    return result! as String
}


class DiffTests: XCTestCase {


    func test_computeDiff() {
        let d = computeDiff("foo2bar", b: "foobar")
        expect(d.count) == 3
        expect(d[0].operation) == Operation.DiffEqual
        expect(d[0].text) == "foo"
        expect(d[1].operation) == Operation.DiffDelete
        expect(d[1].text) == "2"
        expect(d[2].operation) == Operation.DiffEqual
        expect(d[2].text) == "bar"
    }
    
    
    func test_computeDiff_nil_params() {
        let d1 = computeDiff("foo", b: nil)
        expect(d1.count) == 0
        let d2 = computeDiff(nil, b: "foo")
        expect(d2.count) == 0
        let d3 = computeDiff(nil, b: nil)
        expect(d3.count) == 0
    }

    
    func test_patches() {
        let res = computePatches("foo2bar", b: "foobar")
        expect(res.count) == 1
        let lines = res[0].description.componentsSeparatedByString("\n")
        expect(lines[0]) == "@@ -1,7 +1,6 @@"
        expect(lines[1]) == " foo"
        expect(lines[2]) == "-2"
        expect(lines[3]) == " bar"
        expect(res[0].start1) == 0
        expect(res[0].start2) == 0
        expect(res[0].length1) == 7
        expect(res[0].length2) == 6
        
        let p = res[0]
        expect(p.diffs.count) == 3
        expect(p[0].operation) == Operation.DiffEqual
        expect(p[0].text) == "foo"
        expect(p[1].operation) == Operation.DiffDelete
        expect(p[1].text) == "2"
        expect(p[2].operation) == Operation.DiffEqual
        expect(p[2].text) == "bar"
    }
    
    
    func test_patches_long() {
        let a = contentsOfFile(name: "test_a", type: "txt")
        expect(a.characters.count) == 400
        let b = contentsOfFile(name: "test_b", type: "txt")
        expect(b.characters.count) == 394
        let patches = computePatches(a, b: b)
        expect(patches.count) == 4
        
        var p = patches[0]
        expect(p.start1) == 0
        expect(p.start2) == 0
        expect(p.length1) == 108
        expect(p.length2) == 4
        
        expect(p.diffs.count) == 2
        expect(p[0].operation) == Operation.DiffDelete
        expect(p[0].text) == "The Way that can be told of is not the eternal Way;\nThe name that can be named is not the eternal name.\n"
        expect((p[0].text).characters.count) == 104
        expect(p[1].operation) == Operation.DiffEqual
        expect(p[1].text) == "The "
        expect((p[1].text).characters.count) == 4
        
        p = patches[1]
        expect(p.start1) == 44
        expect(p.start2) == 44
        expect(p.length1) == 17
        expect(p.length2) == 17

        expect(p.diffs.count) == 4
        expect(p[0].operation) == Operation.DiffEqual
        expect(p[0].text) == "th;\nThe "
        expect(p[0].text.characters.count) == 8
        expect(p[1].operation) == Operation.DiffDelete
        expect(p[1].text) == "N"
        expect(p[1].text.characters.count) == 1
        expect(p[2].operation) == Operation.DiffInsert
        expect(p[2].text) == "n"
        expect(p[2].text.characters.count) == 1
        expect(p[3].operation) == Operation.DiffEqual
        expect(p[3].text) == "amed is "
        expect(p[3].text.characters.count) == 8
        
        p = patches[2]
        expect(p.start1) == 83
        expect(p.start2) == 83
        expect(p.length1) == 8
        expect(p.length2) == 9
        
        expect(p.diffs.count) == 3
        expect(p[0].operation) == Operation.DiffEqual
        expect(p[0].text) == "gs.\n"
        expect(p[0].text.characters.count) == 4
        expect(p[1].operation) == Operation.DiffInsert
        expect(p[1].text) == "\n"
        expect(p[1].text.characters.count) == 1
        expect(p[2].operation) == Operation.DiffEqual
        expect(p[2].text) == "Ther"
        expect(p[2].text.characters.count) == 4
        
        p = patches[3]
        expect(p.start1) == 293
        expect(p.start2) == 293
        expect(p.length1) == 4
        expect(p.length2) == 101
        
        expect(p.diffs.count) == 2
        expect(p[0].operation) == Operation.DiffEqual
        expect(p[0].text) == "es.\n"
        expect(p[0].text.characters.count) == 4
        expect(p[1].operation) == Operation.DiffInsert
        expect(p[1].text) == "They both may be called deep and profound.\nDeeper and more profound,\nThe door of all subtleties!\n"
        expect(p[1].text.characters.count) == 97
    }
    
    
    func test_adjustPos() {
        let a = contentsOfFile(name: "test_a", type: "txt")
        let b = contentsOfFile(name: "test_b", type: "txt")
        let patches = computePatches(a, b: b)
        expect(patches.count) == 4
        let c = apply(a, patches: patches).value!
        expect(c) == b

        // patches = b - a
        // c + patches = b

        // assume we start with string a and a cursor position in a
        // this test ensures cursor pos is maintained reasonably when patches are applied to a,
        // transforming it into b

        // line starts and ends
        let s1 = a[50..<52] // 2015-08-31 placing this inline causes weird analyser errors in beta 6 (7A192o)
        expect(s1) == ";\n"
        let s2 = b[104..<108] // "variable used with its own initial value", "let declarations cannot be computed properties"
        expect(s2) == "ere "

        let lines = a.split("\n").map { $0 + "\n" }
        let counts = lines.map { UInt($0.characters.count) }

        let startOfLine3 = counts[0] + counts[1]
        expect(startOfLine3) == 104

        for pos: Position in 0..<startOfLine3 {
            expect(newPosition(pos, patches: patches)) == 0
        }

        let startOfLine4 = startOfLine3 + counts[2]
        expect(startOfLine4) == 152

        // The following line is unchanged and the cursor should stay positioned on that line
        // (of course the global index is offset by the removed lines above, totalling 104 characters)
        // line: "The Nameless is the origin of Heaven and Earth;\n"

        for pos: Position in startOfLine3..<startOfLine4 {
            expect(newPosition(pos, patches: patches)) == pos - startOfLine3
        }

        let startOfLine5 = startOfLine4 + counts[3]
        expect(startOfLine5) == 191

        // In the next line only the 'N' is changed to 'n'. Therefore all positions should remain intact.
        // before: "The Named is the mother of all things.\n"
        // after:  "The named is the mother of all things.\n"

        for pos: Position in startOfLine4..<startOfLine5 {
            expect(newPosition(pos, patches: patches)) == pos - startOfLine3
        }

        // After line 4 there's an additional newline being inserted
        // We expect a position at length of lines 3 and 4 (1-based count) + 1 for the CR
        expect(newPosition(startOfLine5, patches: patches)) == counts[2] + counts[3] + 1

        // From here on everything is unchanged until line 11, with the insertion of "The both may..."
        let countInUnchangedBlock = lines[4..<11].reduce(0) { $0 + UInt($1.characters.count) }
        expect(countInUnchangedBlock) == 209

        for pos: Position in 0..<countInUnchangedBlock {
            expect(newPosition(pos + startOfLine5, patches: patches)) == pos + (counts[2] + counts[3] + 1)
        }

        // Check that size all agree

        let end = startOfLine5 + countInUnchangedBlock
        let fileSize = UInt(a.characters.count)
        let lineCounts = lines.reduce(0) { $0 + UInt($1.characters.count) }
        expect(end) == fileSize
        expect(lineCounts) == end

        // Finally, when we're at the end of file 'a', the insertion will push the cursor to the position of end of file 'b'

        expect(newPosition(end, patches: patches)) == UInt(b.characters.count)
    }
    
    
    func test_apply_String() {
        let p = computePatches("foo2bar", b: "foobar")
        let res = apply("foo2bar", patches: p)
        expect(res.succeeded) == true
        expect(res.value!) == "foobar"
    }
    
    
    func test_apply_Document() {
        let source = Document("The quick brown fox jumps over the lazy dog")
        let newText = "The quick brown cat jumps over the lazy dog"
        let changeSet = Changeset(source: source, target: Document(newText))
        let res = apply(source, changeSet: changeSet!)
        expect(res.succeeded) == true
        expect(res.value!.text) == newText
    }
    
    
    func test_apply_Document_diverged() {
        // regression test: we cannot reliable apply the fox -> cat patch to the target
        let fox = Document("The quick brown fox jumps over the lazy dog")
        let cat = Document("The quick brown leopard jumps over the lazy dog")
        let change = Changeset(source: fox, target: cat)
        let target = Document("The quick brown horse jumps over the lazy dog")
        let res = apply(target, changeSet: change!)
        expect(res.succeeded) == false
    }
    
    
    func test_apply_Document_diverged2() {
        // regression test: we cannot reliable apply the patch to the target
        let change = Changeset(source: Document("initial"), target: Document("server"))
        let res = apply(Document("client"), changeSet: change!)
        expect(res.succeeded) == false
    }
    
    
    func test_apply_Document_diverged3() {
        // regression test: we cannot reliable apply the patch to the target
        let change = Changeset(source: Document("foo"), target: Document("server"))
        let c = Document("client")
        let res = apply(c, changeSet: change!)
        expect(res.succeeded) == false
    }
    
    
    func test_apply_Document_conflict() {
        let fox = Document("The quick brown fox jumps over the lazy dog")
        let cat = Document("The quick brown leopard jumps over the lazy dog")
        let change = Changeset(source: fox, target: cat)
        let source = Document("The quick thing likes the lazy dog")
        let res = apply(source, changeSet: change!)
        expect(res.succeeded) == false
        expect(res.value).to(beNil())
    }
    
    
    func test_apply_error() {
        let clientDoc = Document(contentsOfFile(name: "new_playground", type: "txt"))
        let serverDoc = Document("foo")
        let changes = Changeset(source: serverDoc, target: Document("foobar"))
        let res = apply(clientDoc, changeSet: changes!)
        expect(res.succeeded) == false
        expect(res.error).toNot(beNil())
        expect(res.error?.localizedDescription) == "The operation couldn’t be completed. (Diff error 200.)"
    }
    
    
    func test_hash() {
        let doc = Document("The quick brown fox jumps over the lazy dog")
        expect(doc.hash) == "9e107d9d372bb6826bd81d3542a419d6"
        expect(Document("foo\n").hash) == "d3b07384d113edec49eaa6238ad5ff00"
        expect(Document("foo\nbar").hash) == "a76999788386641a3ec798554f1fe7e6"
    }
    
    
    func test_preserve_position() {
        let cr = "\n"
        let line = "012345678"
        let a = line + cr + line
        let b = line + cr + "01234 5678"
        expect(a.characters.count) == 19
        expect(b.characters.count) == 20
        let patches = computePatches(a, b: b)
        expect(newPosition(0, patches: patches)) == 0
        expect(newPosition(5, patches: patches)) == 5
        expect(newPosition(10, patches: patches)) == 10
        expect(newPosition(11, patches: patches)) == 11
        expect(newPosition(12, patches: patches)) == 12
        expect(newPosition(13, patches: patches)) == 13
        expect(newPosition(14, patches: patches)) == 14
        expect(newPosition(15, patches: patches)) == 16
        expect(newPosition(16, patches: patches)) == 17
        expect(newPosition(17, patches: patches)) == 18
        expect(newPosition(18, patches: patches)) == 19
        expect(newPosition(19, patches: patches)) == 20
        expect(newPosition(20, patches: patches)) == 21
    }


    func test_merge() {
        let ancestor = "foo\nbar\nbaz\n"
        let yours = "foo1\nbar\nbaz\n"
        let mine = "foo\nbar\nbaz2\n"
        expect(merge(mine, ancestor: ancestor, yours: yours)) == "foo1\nbar\nbaz2\n"
    }


    func test_merge_failure() {
        let ancestor = "foo"
        let yours = "bar"
        let mine = "baz"
        expect(merge(mine, ancestor: ancestor, yours: yours)).to(beNil())
    }

}
