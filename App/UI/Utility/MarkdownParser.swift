//
// --------------------------------------------------------------------------
// MarkdownParser.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// I want to create simple NSAttributed strings with bold and links defined by markup so they can be localized.
/// In macOS 13 there's a great standard lib method for this, but we also want this on older versions of macOS.
/// We found the library Down. but it's complicated to set up and doesn't end up looking like a native label string just with some bold and links added.
/// Sooo we're bulding our own parser. Wish me luck.

import Foundation
import Markdown

@objc class MarkdownParser: NSObject {
 
    @objc static func attributedString(markdown: String) -> NSAttributedString {
        
        let document = Document(parsing: markdown)
        
        var walker = ToAttributed()
        walker.visit(document)
        
        return walker.string
    }
    
}

struct ToAttributed: MarkupWalker {
    
    var string: NSMutableAttributedString = NSMutableAttributedString(string: "")
    
    mutating func visitLink(_ link: Link) -> () {
        string.append(NSAttributedString(string: link.plainText))
        if let destination = link.destination, let url = URL(string: destination) {
            string = string.addingLink(with: url, forSubstring: link.plainText) as! NSMutableAttributedString
        }
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        string.append(NSAttributedString(string: emphasis.plainText))
        string = string.addingItalic(forSubstring: emphasis.plainText) as! NSMutableAttributedString

    }
    
    mutating func visitStrong(_ strong: Strong) -> () {
        string.append(NSAttributedString(string: strong.plainText))
        string = string.addingBold(forSubstring: strong.plainText) as! NSMutableAttributedString
    }
    
    mutating func visitText(_ text: Text) -> () {
        string.append(NSAttributedString(string: text.string))
    }
}
