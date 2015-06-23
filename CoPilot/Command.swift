//
//  Command.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 01/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Foundation


enum Command {
    
    case Undefined
    case Doc(Document)
    case Update(Changeset)
    case Version(Hash) // unused
    case GetDoc
    case GetVersion    // unused
    case Name(String)
    case Cursor(Selection)
    
    init(document: Document) {
        self = .Doc(document)
    }

    init(update changes: Changeset) {
        self = .Update(changes)
    }
    
    init(version: Hash) {
        self = .Version(version)
    }
    
    init(name: String) {
        self = .Name(name)
    }

    init(selection: Selection) {
        self = .Cursor(selection)
    }
    
    var document: Document? {
        switch self {
        case .Doc(let doc):
            return doc
        default:
            return nil
        }
    }
    
    var changes: Changeset? {
        switch self {
        case .Update(let changes):
            return changes
        default:
            return nil
        }
    }
    
    var version: Hash? {
        switch self {
        case .Version(let hash):
            return hash
        default:
            return nil
        }
    }
    
    var name: String? {
        switch self {
        case .Name(let name):
            return name
        default:
            return nil
        }
    }

    var selection: Selection? {
        switch self {
        case .Cursor(let selection):
            return selection
        default:
            return nil
        }
    }

    private enum EncodingKeys: String {
        case TypeName = "typeName"
        case Data = "data"
    }
    
    private enum TypeNames: String {
        case Undefined = "Undefined"
        case Doc = "Doc"
        case Update = "Update"
        case Version = "Version"
        case GetDoc = "GetDoc"
        case GetVersion = "GetVersion"
        case Name = "Name"
        case Cursor = "Cursor"
    }
    
    var typeName: String {
        switch self {
        case .Undefined:
            return TypeNames.Undefined.rawValue
        case .Doc:
            return TypeNames.Doc.rawValue
        case .Update:
            return TypeNames.Update.rawValue
        case .Version:
            return TypeNames.Version.rawValue
        case .GetDoc:
            return TypeNames.GetDoc.rawValue
        case .GetVersion:
            return TypeNames.GetVersion.rawValue
        case .Name:
            return TypeNames.Name.rawValue
        case .Cursor:
            return TypeNames.Cursor.rawValue
        }
    }
    
}


extension Command: Serializable {

    init(data: NSData) {
        let decoder = NSKeyedUnarchiver(forReadingWithData: data)
        // try to decode the type key
        if let type = decoder.decodeObjectForKey(EncodingKeys.TypeName.rawValue) as? String {
            // try to decode the data kay
            if let obj: AnyObject = decoder.decodeObjectForKey(EncodingKeys.Data.rawValue) {
                switch type {
                case TypeNames.Doc.rawValue:
                    let doc = Document(data: obj as! NSData)
                    self = .Doc(doc)
                case TypeNames.Update.rawValue:
                    let changes = Changeset(data: obj as! NSData)
                    self = .Update(changes)
                case TypeNames.Version.rawValue:
                    let hash = Hash(obj as! NSString)
                    self = .Version(hash)
                case TypeNames.Name.rawValue:
                    let name = String(obj as! NSString)
                    self = .Name(name)
                case TypeNames.Cursor.rawValue:
                    let selection = Selection(data: obj as! NSData)
                    self = .Cursor(selection)
                default:
                    self = .Undefined
                }
            } else {
                // commands without associated data (could not decode the value for the data key)
                switch type {
                case TypeNames.GetDoc.rawValue:
                    self = .GetDoc
                case TypeNames.GetVersion.rawValue:
                    self = .GetVersion
                default:
                    self = .Undefined
                }
            }
        } else {
            // could not decode the value for the type key
            self = .Undefined
        }
    }

    func serialize() -> NSData {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
        archiver.encodeObject(self.typeName, forKey: EncodingKeys.TypeName.rawValue)
        switch self {
        case .Doc(let doc):
            archiver.encodeObject(doc.serialize(), forKey: EncodingKeys.Data.rawValue)
        case .Update(let changes):
            archiver.encodeObject(changes.serialize(), forKey: EncodingKeys.Data.rawValue)
        case .Version(let version):
            archiver.encodeObject(version, forKey: EncodingKeys.Data.rawValue)
        case .Name(let name):
            archiver.encodeObject(name, forKey: EncodingKeys.Data.rawValue)
        case .Cursor(let selection):
            archiver.encodeObject(selection.serialize(), forKey: EncodingKeys.Data.rawValue)
        default: break
        }
        archiver.finishEncoding()
        return data
    }

}


extension Command: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .Update(let changes):
            return ".\(self.typeName) \(changes)"
        case .Name(let name):
            return ".\(self.typeName) \(name)"
        case .Cursor(let selection):
            return ".\(self.typeName) \(selection.range.location) \(selection.range.length)"
        default:
            return ".\(self.typeName)"
        }
    }
    
}
