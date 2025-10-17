//
//  main.swift
//  UnlinkedMusicFiles
//
//  Created by Ben Schultz on 2025-02-12.
//

import Foundation
import Files
import XMLParsing

let pathToMusicFiles = "/Users/ben/Music_/Music"
let xmlFilePath = "/Users/ben/Music_/Library.xml"
let reportFilePath = "/Users/ben/Code/UnlinkedMusicFiles"
let inXMLReplace = "/Users/ben/Music/Music/Media.localized/Music"


extension Folder {
    var filesRecursive: [File] {
        var fileList = [File]()
        for file in self.files {
            fileList.append(file)
        }
        for folder in self.subfolders {
            fileList = fileList + folder.filesRecursive
        }
        return fileList
    }
    
    var emptySubfolders: [Folder] {
        var folderList = [Folder]()
        for folder in self.subfolders {
            if folder.isEmpty() {
                folderList.append(folder)
            }
            folderList += folder.emptySubfolders
        }
        return folderList
    }
}

struct Plist: Codable {
    var dicts: [Dict]
    
    enum CodingKeys: String, CodingKey {
        case dicts = "dict"
    }
}

struct Dict: Codable {
    var keys: [String]?
    var strings: [String]?
    var dicts: [Dict]?
    
    enum CodingKeys: String, CodingKey {
        case keys = "key"
        case strings = "string"
        case dicts = "dict"
    }
}

class CaseInsensitiveComparableString: Equatable, Hashable, CustomStringConvertible {

    var value: String {
        didSet {
            self.lowercased = value.lowercased()
        }
    }
    
    private var lowercased: String
    
    var description: String {
        return value
    }
    
    init(_ value: String) {
        self.value = value
        self.lowercased = value.lowercased()
    }
    
    static func == (lhs: CaseInsensitiveComparableString, rhs: CaseInsensitiveComparableString) -> Bool {
        lhs.lowercased == rhs.lowercased
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(lowercased)
    }
}




/*  Paths from AppleMusic XML */

let xmlData = try File(path: xmlFilePath).read()
let decoded = try XMLDecoder().decode(Plist.self, from: xmlData)

let appleMusicFiles: Set<CaseInsensitiveComparableString> = {
    var tempFiles = [File]()
    if let tracks = decoded.dicts[0].dicts?[0].dicts {
        for track in tracks {
                
            if let strings = track.strings {
                for string in strings {
                    if string.prefix(5) == "file:" {
                        let path = String(string.suffix(string.lengthOfBytes(using: .utf8) - 7))
                            .removingPercentEncoding?
                            .replacingOccurrences(of: inXMLReplace, with: pathToMusicFiles)
                        //print(path)
                        if let path,
                            let file = try? File(path: path)
                        {
                            tempFiles.append(file)
                        }
                    }
                }
            }
        }
    }
    return Set(tempFiles.map{CaseInsensitiveComparableString($0.path)})
}()

let runDateTime = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: Date())
}()


/* Paths from File structure */
let folder = try Folder(path: pathToMusicFiles)
let actualFiles = Set(folder.filesRecursive.map{CaseInsensitiveComparableString($0.path)})

let inLibButNotInFileStruct = appleMusicFiles.filter{ !actualFiles.contains($0) }
let inFileStructButNotInLib = actualFiles.filter{ !appleMusicFiles.contains($0) }
let reportList = inFileStructButNotInLib.map{$0.value}.sorted().joined(separator: "\n")
let reportList2 = inLibButNotInFileStruct.map{$0.value}.sorted().joined(separator: "\n")

let reportFolder = try Folder(path: reportFilePath)
let reportFile = try reportFolder.createFile(at: "report.txt")

let emptyFolderList = folder.emptySubfolders
let reportEmptyFolders = emptyFolderList.map {$0.path}.sorted().joined(separator: "\n")

let report = """
\(runDateTime)


#\(inLibButNotInFileStruct.count) in library but not in file structure.

\(reportList2)


#\(inFileStructButNotInLib.count) in file structure but not in library.

\(reportList)

#\(folder.emptySubfolders.count) empty subfolders.

\(reportEmptyFolders)
"""


try reportFile.write(report)

print("done")


