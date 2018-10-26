/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

func initJAMFRegex() -> [Software.SoftwareStatus: NSRegularExpression?] {
    
    let re_options = NSRegularExpression.Options.anchorsMatchLines
    
    // Installing
    let re_installing: NSRegularExpression?
    
    do {
        try re_installing = NSRegularExpression(
            pattern: "(?<=Installing )([a-zA-Z0-9._ ]*)-([a-zA-Z0-9._]*).pkg...$",
            options: re_options
        )
    } catch {
        re_installing = nil
    }
    
    // Failure
    let re_failure: NSRegularExpression?
    
    do {
        try re_failure = NSRegularExpression(
            pattern: "(?<=Installation failed. The installer reported: installer: Package name is )([a-zA-Z0-9._ ]*)-([a-zA-Z0-9._]*)$",
            options: re_options
        )
    } catch {
        re_failure = nil
    }
    
    // Success
    let re_success: NSRegularExpression?
    
    do {
        try re_success = NSRegularExpression(
            pattern: "(?<=Successfully installed )([a-zA-Z0-9._ ]*)-([a-zA-Z0-9._]*).pkg",
            options: re_options
        )
    } catch {
        re_success = nil
    }
    
    return [
        .success: re_success,
        .failed: re_failure,
        .installing: re_installing
    ]
}

class JAMFInsider {
    internal let userDefaults: UserDefaults
    let logFileHandle: FileHandle?
    
    init(nsUserDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = nsUserDefaults
        
        // TSTJamfLog is meant for unit testing only.
        let jamfLogPath = self.userDefaults.string(forKey: Constants.Testing.JAMFLog) ?? Constants.Defaults.JAMFLogPath
        
        do {
            self.logFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: jamfLogPath, isDirectory: false))
        } catch {
            Log.write(string: "Cannot read \(jamfLogPath)",
                cat: "Preferences",
                level: .error)
            self.logFileHandle = nil
        }
    }
    
    func run() {
        guard let logFileHandle = self.logFileHandle else {
            Log.write(string: "Cannot check logFileHandle", cat: "Preferences", level: .error)
            return
        }
        
        logFileHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.readDataToEndOfFile()
            
            guard let string = String(data: data, encoding: .utf8) else {
                return
            }
            
            for line in string.split(separator: "\n") {
                if let software = Software(from: String(line), with: initJAMFRegex()) {
                    DispatchQueue.main.async {
                        SoftwareArray.sharedInstance.array.modify(with: software)
                    }
                }
            }
        }
    }
}