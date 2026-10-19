import CoreGraphics

// Reads only session availability; does not inspect screen contents or alter the login state.
if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
    for key in ["CGSSessionScreenIsLocked", "kCGSessionLoginDoneKey"] {
        print(key, session[key] ?? "unavailable")
    }
} else {
    print("session unavailable")
}
