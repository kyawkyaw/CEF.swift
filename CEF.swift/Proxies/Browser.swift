//
//  Browser.swift
//  CEF.swift
//
//  Created by Tamas Lustyik on 2015. 07. 25..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

extension cef_browser_t: CEFObject {
}

/// Class used to represent a browser window. When used in the browser process
/// the methods of this class may be called on any thread unless otherwise
/// indicated in the comments. When used in the render process the methods of
/// this class may only be called on the main thread.
public class Browser : Proxy<cef_browser_t> {
    public typealias Identifier = Int32
    
    /// Returns the browser host object. This method can only be called in the
    /// browser process.
    public var host: BrowserHost? {
        let cefHost = cefObject.get_host(cefObjectPtr)
        return BrowserHost.fromCEF(cefHost)
    }
    
    /// Returns true if the browser can navigate backwards.
    public var canGoBack: Bool {
        return cefObject.can_go_back(cefObjectPtr) != 0
    }

    /// Navigate backwards.
    public func goBack() {
        cefObject.go_back(cefObjectPtr)
    }
    
    /// Returns true if the browser can navigate forwards.
    public var canGoForward: Bool {
        return cefObject.can_go_forward(cefObjectPtr) != 0
    }

    /// Navigate forwards.
    public func goForward() {
        cefObject.go_forward(cefObjectPtr)
    }
    
    /// Returns true if the browser is currently loading.
    public var isLoading: Bool {
        return cefObject.is_loading(cefObjectPtr) != 0
    }

    /// Reload the current page.
    public func reload(ignoringCache ignore: Bool = false) {
        if ignore {
            cefObject.reload_ignore_cache(cefObjectPtr)
        }
        else {
            cefObject.reload(cefObjectPtr)
        }
    }

    /// Stop loading the page.
    public func stopLoad() {
        cefObject.stop_load(cefObjectPtr)
    }

    /// Returns the globally unique identifier for this browser.
    public var identifier: Identifier {
        return cefObject.get_identifier(cefObjectPtr)
    }

    /// Returns true if this object is pointing to the same handle as |that|
    /// object.
    public func isSameAs(other: Browser) -> Bool {
        return cefObject.is_same(cefObjectPtr, other.toCEF()) != 0
    }

    /// Returns true if the window is a popup window.
    public var isPopup: Bool {
        return cefObject.is_popup(cefObjectPtr) != 0
    }
    
    /// Returns true if a document has been loaded in the browser.
    public var hasDocument: Bool {
        return cefObject.has_document(cefObjectPtr) != 0
    }
    
    /// Returns the main (top-level) frame for the browser window.
    public var mainFrame: Frame? {
        // TODO: audit nonnull
        let cefFrame = cefObject.get_main_frame(cefObjectPtr)
        return Frame.fromCEF(cefFrame)
    }
    
    /// Returns the focused frame for the browser window.
    public var focusedFrame: Frame? {
        // TODO: audit nonnull
        let cefFrame = cefObject.get_focused_frame(cefObjectPtr)
        return Frame.fromCEF(cefFrame)
    }
    
    /// Returns the frame with the specified identifier, or NULL if not found.
    public func frameForID(id: Frame.Identifier) -> Frame? {
        let cefFrame = cefObject.get_frame_byident(cefObjectPtr, id)
        return Frame.fromCEF(cefFrame)
    }

    /// Returns the frame with the specified name, or NULL if not found.
    public func frameForName(name: String) -> Frame? {
        let cefNamePtr = CEFStringPtrCreateFromSwiftString(name)
        defer { CEFStringPtrRelease(cefNamePtr) }
        
        let cefFrame = cefObject.get_frame(cefObjectPtr, cefNamePtr)
        return Frame.fromCEF(cefFrame)
    }

    /// Returns the number of frames that currently exist.
    public var frameCount: Int {
        return Int(cefObject.get_frame_count(cefObjectPtr))
    }

    /// Returns the identifiers of all existing frames.
    public var frameIDs: [Frame.Identifier] {
        var idCount:size_t = 0
        let idsPtr:UnsafeMutablePointer<Frame.Identifier> = nil
        cefObject.get_frame_identifiers(cefObjectPtr, &idCount, idsPtr)
        
        var ids = Array<Frame.Identifier>()
        for i in 0..<idCount {
            ids.append(idsPtr.advancedBy(i).memory)
        }
        return ids
    }

    /// Returns the names of all existing frames.
    public var frameNames: [String] {
        let cefList = cef_string_list_alloc()
        defer { cef_string_list_free(cefList) }
        
        cefObject.get_frame_names(cefObjectPtr, cefList)
        return CEFStringListToSwiftArray(cefList)
    }

    /// Send a message to the specified |target_process|. Returns true if the
    /// message was sent successfully.
    public func sendProcessMessage(targetProcessID: ProcessID, message: ProcessMessage) -> Bool {
        return cefObject.send_process_message(cefObjectPtr, targetProcessID.toCEF(), message.toCEF()) != 0
    }

    // private
    
    override init?(ptr: ObjectPtrType) {
        super.init(ptr: ptr)
    }
    
    static func fromCEF(ptr: ObjectPtrType) -> Browser? {
        return Browser(ptr: ptr)
    }

}
